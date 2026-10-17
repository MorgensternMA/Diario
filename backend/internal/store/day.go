package store

import (
	"errors"
	"fmt"
	"time"
)

// TrackerDay is a tracker together with its value for a given day.
type TrackerDay struct {
	Tracker
	Value *float64 `json:"value"`
}

// Day aggregates everything recorded for a single date.
type Day struct {
	Date     string        `json:"date"`
	Journal  *JournalEntry `json:"journal"`
	Period   *PeriodDay    `json:"period"`
	Events   []Event       `json:"events"`
	Trackers []TrackerDay  `json:"trackers"`
	DueItems []Item        `json:"due_items"`
}

func (s *Store) Day(date string) (Day, error) {
	if err := validDate(date); err != nil {
		return Day{}, err
	}
	d := Day{Date: date}

	if j, err := s.GetJournal(date); err == nil {
		d.Journal = &j
	} else if !errors.Is(err, ErrNotFound) {
		return d, err
	}
	if p, err := s.GetPeriod(date); err == nil {
		d.Period = &p
	} else if !errors.Is(err, ErrNotFound) {
		return d, err
	}

	var err error
	if d.Events, err = s.ListEvents(EventFilter{From: date, To: date}); err != nil {
		return d, err
	}
	if d.DueItems, err = s.ItemsDue(date, date); err != nil {
		return d, err
	}

	trackers, err := s.ListTrackers(false)
	if err != nil {
		return d, err
	}
	entries, err := s.ListEntries(0, date, date)
	if err != nil {
		return d, err
	}
	values := make(map[int64]float64, len(entries))
	for _, e := range entries {
		values[e.TrackerID] = e.Value
	}
	d.Trackers = make([]TrackerDay, 0, len(trackers))
	for _, t := range trackers {
		td := TrackerDay{Tracker: t}
		if v, ok := values[t.ID]; ok {
			td.Value = &v
		}
		d.Trackers = append(d.Trackers, td)
	}
	return d, nil
}

type CalendarEvent struct {
	ID    int64  `json:"id"`
	Title string `json:"title"`
	Color string `json:"color"`
	Done  bool   `json:"done"`
}

// CalendarDay holds the markers the month view needs for one date.
type CalendarDay struct {
	Date            string          `json:"date"`
	Events          []CalendarEvent `json:"events"`
	Mood            int             `json:"mood"`
	Flow            int             `json:"flow"`
	PredictedPeriod bool            `json:"predicted_period"`
	Fertile         bool            `json:"fertile"`
	Ovulation       bool            `json:"ovulation"`
	DueItems        int             `json:"due_items"`
}

// Calendar returns markers for every date in [from, to] that has something.
func (s *Store) Calendar(from, to string, today time.Time) ([]CalendarDay, error) {
	start, err := ParseDate(from)
	if err != nil {
		return nil, err
	}
	end, err := ParseDate(to)
	if err != nil {
		return nil, err
	}
	if end.Before(start) || daysBetween(start, end) > 400 {
		return nil, fmt.Errorf("%w: range must be ordered and at most 400 days", ErrInvalid)
	}

	days := map[string]*CalendarDay{}
	get := func(date string) *CalendarDay {
		d, ok := days[date]
		if !ok {
			d = &CalendarDay{Date: date, Events: []CalendarEvent{}}
			days[date] = d
		}
		return d
	}

	rows, err := s.db.Query(`SELECT e.id, e.title, e.date, e.done, COALESCE(c.color, '#9E9E9E')
		FROM events e LEFT JOIN categories c ON c.id = e.category_id
		WHERE e.date >= ? AND e.date <= ? ORDER BY e.date, e.time = '', e.time, e.id`, from, to)
	if err != nil {
		return nil, err
	}
	for rows.Next() {
		var ev CalendarEvent
		var date string
		if err := rows.Scan(&ev.ID, &ev.Title, &date, &ev.Done, &ev.Color); err != nil {
			rows.Close()
			return nil, err
		}
		d := get(date)
		d.Events = append(d.Events, ev)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}

	journal, err := s.ListJournal(from, to)
	if err != nil {
		return nil, err
	}
	for _, j := range journal {
		if j.Mood > 0 {
			get(j.Date).Mood = j.Mood
		}
	}

	due, err := s.ItemsDue(from, to)
	if err != nil {
		return nil, err
	}
	for _, it := range due {
		get(it.DueDate).DueItems++
	}

	allPeriod, err := s.ListPeriod("", "")
	if err != nil {
		return nil, err
	}
	for _, p := range allPeriod {
		if p.Date >= from && p.Date <= to {
			get(p.Date).Flow = p.Flow
		}
	}

	mark := func(a, b string, f func(*CalendarDay)) {
		ta, _ := ParseDate(a)
		tb, _ := ParseDate(b)
		for t := ta; !t.After(tb); t = addDays(t, 1) {
			if t.Before(start) || t.After(end) {
				continue
			}
			f(get(fmtDate(t)))
		}
	}
	for _, p := range ComputeCycles(allPeriod, today).Predictions {
		mark(p.FertileStart, p.FertileEnd, func(d *CalendarDay) { d.Fertile = true })
		mark(p.Ovulation, p.Ovulation, func(d *CalendarDay) { d.Ovulation = true })
		mark(p.Start, p.End, func(d *CalendarDay) {
			if d.Flow == 0 {
				d.PredictedPeriod = true
			}
		})
	}

	out := make([]CalendarDay, 0, len(days))
	for t := start; !t.After(end); t = addDays(t, 1) {
		if d, ok := days[fmtDate(t)]; ok {
			out = append(out, *d)
		}
	}
	return out, nil
}
