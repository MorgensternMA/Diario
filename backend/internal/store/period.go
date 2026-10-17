package store

import (
	"database/sql"
	"errors"
	"fmt"
	"math"
	"sort"
	"time"
)

// Flow levels for a period day.
const (
	FlowSpotting = 1 // manchado
	FlowLight    = 2 // leve
	FlowMedium   = 3 // medio
	FlowHeavy    = 4 // abundante
)

// Defaults used until there is enough history to compute averages.
const (
	defaultCycle  = 28
	defaultPeriod = 5
	// Days without bleeding allowed inside a single period.
	maxGap = 2
	// Cycles outside this range are treated as logging mistakes.
	minCycle, maxCycle = 15, 60
	// How many recent cycles feed the averages.
	avgWindow = 6
)

type PeriodDay struct {
	Date     string   `json:"date"`
	Flow     int      `json:"flow"`
	Symptoms []string `json:"symptoms"`
	Note     string   `json:"note"`
}

func (p *PeriodDay) validate() error {
	if err := validDate(p.Date); err != nil {
		return err
	}
	if p.Flow < FlowSpotting || p.Flow > FlowHeavy {
		return fmt.Errorf("%w: flow must be between 1 and 4", ErrInvalid)
	}
	if p.Symptoms == nil {
		p.Symptoms = []string{}
	}
	return nil
}

func (s *Store) ListPeriod(from, to string) ([]PeriodDay, error) {
	if err := validRange(from, to); err != nil {
		return nil, err
	}
	if to == "" {
		to = "9999-12-31"
	}
	rows, err := s.db.Query(`SELECT date, flow, symptoms, note FROM period_days WHERE date >= ? AND date <= ? ORDER BY date`, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []PeriodDay{}
	for rows.Next() {
		var p PeriodDay
		var symptoms string
		if err := rows.Scan(&p.Date, &p.Flow, &symptoms, &p.Note); err != nil {
			return nil, err
		}
		p.Symptoms = decodeTags(symptoms)
		out = append(out, p)
	}
	return out, rows.Err()
}

func (s *Store) GetPeriod(date string) (PeriodDay, error) {
	p := PeriodDay{Date: date}
	var symptoms string
	err := s.db.QueryRow(`SELECT flow, symptoms, note FROM period_days WHERE date = ?`, date).Scan(&p.Flow, &symptoms, &p.Note)
	if errors.Is(err, sql.ErrNoRows) {
		return p, ErrNotFound
	}
	p.Symptoms = decodeTags(symptoms)
	return p, err
}

func (s *Store) PutPeriod(p PeriodDay) (PeriodDay, error) {
	if err := p.validate(); err != nil {
		return p, err
	}
	_, err := s.db.Exec(`INSERT INTO period_days(date, flow, symptoms, note) VALUES (?, ?, ?, ?)
		ON CONFLICT(date) DO UPDATE SET flow = excluded.flow, symptoms = excluded.symptoms, note = excluded.note`,
		p.Date, p.Flow, encodeTags(p.Symptoms), p.Note)
	return p, err
}

func (s *Store) DeletePeriod(date string) error {
	return affected(s.db.Exec(`DELETE FROM period_days WHERE date = ?`, date))
}

// CycleSummary returns the cycle statistics and predictions as of today.
func (s *Store) CycleSummary(today time.Time) (CycleSummary, error) {
	days, err := s.ListPeriod("", "")
	if err != nil {
		return CycleSummary{}, err
	}
	return ComputeCycles(days, today), nil
}

// Cycle is one recorded period and the cycle it started.
type Cycle struct {
	Start        string `json:"start"`
	End          string `json:"end"`
	PeriodLength int    `json:"period_length"`
	// Days from this start to the next one; 0 for the ongoing cycle.
	CycleLength int `json:"cycle_length"`
}

// Prediction is an estimated upcoming period with its fertile window.
type Prediction struct {
	Start        string `json:"start"`
	End          string `json:"end"`
	Ovulation    string `json:"ovulation"`
	FertileStart string `json:"fertile_start"`
	FertileEnd   string `json:"fertile_end"`
}

type CycleSummary struct {
	HasData   bool   `json:"has_data"`
	AvgCycle  int    `json:"avg_cycle"`
	AvgPeriod int    `json:"avg_period"`
	LastStart string `json:"last_start"`
	// 1-based day of the current cycle, 0 without data.
	CycleDay  int    `json:"cycle_day"`
	NextStart string `json:"next_start"`
	// Negative when the period is late.
	DaysUntilNext int          `json:"days_until_next"`
	InPeriod      bool         `json:"in_period"`
	Cycles        []Cycle      `json:"cycles"`
	Predictions   []Prediction `json:"predictions"`
}

type period struct{ start, end time.Time }

func daysBetween(a, b time.Time) int {
	return int(math.Round(b.Sub(a).Hours() / 24))
}

func addDays(t time.Time, n int) time.Time { return t.AddDate(0, 0, n) }

func fmtDate(t time.Time) string { return t.Format(DateLayout) }

// groupPeriods merges logged days into periods. Days separated by at most
// maxGap missing days belong to the same period; leading and trailing
// spotting is trimmed, and spotting-only groups are dropped.
func groupPeriods(days []PeriodDay) []period {
	type day struct {
		t    time.Time
		flow int
	}
	parsed := make([]day, 0, len(days))
	for _, d := range days {
		t, err := ParseDate(d.Date)
		if err != nil {
			continue
		}
		parsed = append(parsed, day{t, d.Flow})
	}
	sort.Slice(parsed, func(i, j int) bool { return parsed[i].t.Before(parsed[j].t) })

	var out []period
	var group []day
	flush := func() {
		var first, last *day
		for i := range group {
			if group[i].flow >= FlowLight {
				if first == nil {
					first = &group[i]
				}
				last = &group[i]
			}
		}
		if first != nil {
			out = append(out, period{first.t, last.t})
		}
		group = group[:0]
	}
	for _, d := range parsed {
		if len(group) > 0 && daysBetween(group[len(group)-1].t, d.t) > maxGap+1 {
			flush()
		}
		group = append(group, d)
	}
	flush()
	return out
}

func average(xs []int, fallback int) int {
	if len(xs) == 0 {
		return fallback
	}
	if len(xs) > avgWindow {
		xs = xs[len(xs)-avgWindow:]
	}
	sum := 0
	for _, x := range xs {
		sum += x
	}
	return int(math.Round(float64(sum) / float64(len(xs))))
}

// ComputeCycles derives cycle history, averages and the next predictions
// from the logged period days.
func ComputeCycles(days []PeriodDay, today time.Time) CycleSummary {
	today = time.Date(today.Year(), today.Month(), today.Day(), 0, 0, 0, 0, time.UTC)
	sum := CycleSummary{AvgCycle: defaultCycle, AvgPeriod: defaultPeriod, Cycles: []Cycle{}, Predictions: []Prediction{}}

	periods := groupPeriods(days)
	if len(periods) == 0 {
		return sum
	}
	sum.HasData = true

	var cycleLens, periodLens []int
	for i, p := range periods {
		periodLens = append(periodLens, daysBetween(p.start, p.end)+1)
		c := Cycle{Start: fmtDate(p.start), End: fmtDate(p.end), PeriodLength: periodLens[i]}
		if i+1 < len(periods) {
			c.CycleLength = daysBetween(p.start, periods[i+1].start)
			if c.CycleLength >= minCycle && c.CycleLength <= maxCycle {
				cycleLens = append(cycleLens, c.CycleLength)
			}
		}
		sum.Cycles = append(sum.Cycles, c)
	}
	// Most recent first.
	for i, j := 0, len(sum.Cycles)-1; i < j; i, j = i+1, j-1 {
		sum.Cycles[i], sum.Cycles[j] = sum.Cycles[j], sum.Cycles[i]
	}

	last := periods[len(periods)-1]
	ongoing := !today.Before(last.start) && daysBetween(last.end, today) <= 1
	// A period still in progress would drag the average length down.
	if ongoing && len(periodLens) > 1 {
		periodLens = periodLens[:len(periodLens)-1]
	}

	sum.AvgCycle = average(cycleLens, defaultCycle)
	sum.AvgPeriod = average(periodLens, defaultPeriod)

	sum.LastStart = fmtDate(last.start)
	sum.CycleDay = daysBetween(last.start, today) + 1
	if sum.CycleDay < 1 {
		sum.CycleDay = 0
	}
	next := addDays(last.start, sum.AvgCycle)
	sum.NextStart = fmtDate(next)
	sum.DaysUntilNext = daysBetween(today, next)
	sum.InPeriod = ongoing

	// Upcoming predictions, skipping ones that are entirely in the past
	// (e.g. when logging was paused for a few months).
	for k := 1; len(sum.Predictions) < 3 && k < 100; k++ {
		start := addDays(last.start, k*sum.AvgCycle)
		end := addDays(start, sum.AvgPeriod-1)
		if end.Before(today) {
			continue
		}
		ov := addDays(start, -14)
		sum.Predictions = append(sum.Predictions, Prediction{
			Start:        fmtDate(start),
			End:          fmtDate(end),
			Ovulation:    fmtDate(ov),
			FertileStart: fmtDate(addDays(ov, -5)),
			FertileEnd:   fmtDate(addDays(ov, 1)),
		})
	}
	return sum
}
