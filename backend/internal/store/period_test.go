package store

import (
	"testing"
	"time"
)

func days(flow int, dates ...string) []PeriodDay {
	out := make([]PeriodDay, len(dates))
	for i, d := range dates {
		out[i] = PeriodDay{Date: d, Flow: flow}
	}
	return out
}

func mustDate(t *testing.T, s string) time.Time {
	t.Helper()
	d, err := ParseDate(s)
	if err != nil {
		t.Fatal(err)
	}
	return d
}

func TestComputeCyclesNoData(t *testing.T) {
	sum := ComputeCycles(nil, mustDate(t, "2026-10-16"))
	if sum.HasData || sum.AvgCycle != 28 || sum.AvgPeriod != 5 || len(sum.Predictions) != 0 {
		t.Fatalf("unexpected summary: %+v", sum)
	}
}

func TestComputeCyclesAverages(t *testing.T) {
	var log []PeriodDay
	log = append(log, days(FlowMedium, "2026-07-01", "2026-07-02", "2026-07-03", "2026-07-04")...)
	// 30 days later, with a gap day inside the period and spotting around it.
	log = append(log, days(FlowSpotting, "2026-07-30")...)
	log = append(log, days(FlowHeavy, "2026-07-31", "2026-08-01", "2026-08-03")...)
	log = append(log, days(FlowSpotting, "2026-08-04")...)
	// 28 days later.
	log = append(log, days(FlowLight, "2026-08-28", "2026-08-29", "2026-08-30", "2026-08-31", "2026-09-01", "2026-09-02")...)
	// A lone spotting day must not count as a period.
	log = append(log, days(FlowSpotting, "2026-09-15")...)

	sum := ComputeCycles(log, mustDate(t, "2026-09-10"))

	if len(sum.Cycles) != 3 {
		t.Fatalf("want 3 cycles, got %+v", sum.Cycles)
	}
	if got := sum.Cycles[1]; got.Start != "2026-07-31" || got.End != "2026-08-03" || got.PeriodLength != 4 || got.CycleLength != 28 {
		t.Errorf("middle cycle = %+v", got)
	}
	if sum.AvgCycle != 29 { // (30 + 28) / 2
		t.Errorf("AvgCycle = %d, want 29", sum.AvgCycle)
	}
	if sum.AvgPeriod != 5 { // (4 + 4 + 6) / 3 = 4.67
		t.Errorf("AvgPeriod = %d, want 5", sum.AvgPeriod)
	}
	if sum.LastStart != "2026-08-28" || sum.CycleDay != 14 {
		t.Errorf("LastStart/CycleDay = %s/%d", sum.LastStart, sum.CycleDay)
	}
	if sum.NextStart != "2026-09-26" || sum.DaysUntilNext != 16 {
		t.Errorf("NextStart/DaysUntilNext = %s/%d", sum.NextStart, sum.DaysUntilNext)
	}
	if sum.InPeriod {
		t.Error("should not be in period")
	}
	p := sum.Predictions[0]
	if p.Start != "2026-09-26" || p.End != "2026-09-30" || p.Ovulation != "2026-09-12" ||
		p.FertileStart != "2026-09-07" || p.FertileEnd != "2026-09-13" {
		t.Errorf("prediction = %+v", p)
	}
	if len(sum.Predictions) != 3 {
		t.Errorf("want 3 predictions, got %d", len(sum.Predictions))
	}
}

func TestComputeCyclesLateAndPaused(t *testing.T) {
	log := days(FlowMedium, "2026-01-01", "2026-01-02", "2026-01-03")
	sum := ComputeCycles(log, mustDate(t, "2026-02-03"))
	if sum.DaysUntilNext != -5 { // expected 2026-01-29
		t.Errorf("DaysUntilNext = %d, want -5 (late)", sum.DaysUntilNext)
	}
	// Months later, predictions must still lie ahead.
	sum = ComputeCycles(log, mustDate(t, "2026-10-16"))
	if sum.Predictions[0].End < "2026-10-16" {
		t.Errorf("stale prediction: %+v", sum.Predictions[0])
	}
}

func TestComputeCyclesInPeriod(t *testing.T) {
	log := days(FlowMedium, "2026-09-20", "2026-09-21", "2026-09-22", "2026-09-23", "2026-09-24")
	log = append(log, days(FlowHeavy, "2026-10-14", "2026-10-15")...)
	sum := ComputeCycles(log, mustDate(t, "2026-10-16"))
	if !sum.InPeriod {
		t.Error("expected InPeriod the day after the last logged day")
	}
	if sum.AvgPeriod != 5 {
		t.Errorf("AvgPeriod = %d, want 5 (ongoing period excluded)", sum.AvgPeriod)
	}
}
