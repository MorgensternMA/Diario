import 'package:diario/data/cycles.dart';
import 'package:diario/data/insights.dart';
import 'package:diario/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Three 28-day cycles starting 2026-07-01: low energy on cycle days 1-2,
/// more hunger on days 25-27, ibuprofen on day 1.
({List<PeriodDay> period, List<JournalEntry> journal, List<({String date, String name})> meds}) history() {
  final period = <PeriodDay>[];
  final journal = <JournalEntry>[];
  final meds = <({String date, String name})>[];
  for (var c = 0; c < 3; c++) {
    final start = addDays(dayOf('2026-07-01'), c * 28);
    for (var i = 0; i < 4; i++) {
      period.add(PeriodDay(date: fmtDay(addDays(start, i)), flow: 3));
    }
    meds.add((date: fmtDay(start), name: c == 0 ? 'Ibuprofeno' : 'ibuprofeno '));
    for (var cd = 1; cd <= 28; cd++) {
      journal.add(
        JournalEntry(
          date: fmtDay(addDays(start, cd - 1)),
          energy: cd <= 2 ? 1 : 4,
          hunger: cd >= 25 && cd <= 27 ? 5 : 2,
          mood: 4,
        ),
      );
    }
  }
  // Fourth period starts 2026-09-23.
  period.add(const PeriodDay(date: '2026-09-23', flow: 3));
  return (period: period, journal: journal, meds: meds);
}

void main() {
  test('learns recurring patterns', () {
    final h = history();
    final ins = computeInsights(period: h.period, journal: h.journal, meds: h.meds, now: DateTime(2026, 9, 24));

    expect(ins.cyclesWithData, 3);
    final energy = ins.patterns.where((p) => p.signal == const Signal(Metric.energy, false)).toList();
    expect(energy, hasLength(1));
    // The ±1 smoothing window spreads days 1-2 to 1-3.
    expect([energy.single.fromDay, energy.single.toDay], [1, 3]);
    expect(energy.single.label, 'menos energía');

    final hunger = ins.patterns.where((p) => p.signal == const Signal(Metric.hunger, true)).single;
    expect([hunger.fromDay, hunger.toDay], [24, 28]);
    expect(hunger.label, 'más hambre');

    // Expected levels feed the chart: energy dips on day 2, recovers later.
    expect(ins.today!.expected[Metric.energy], 2); // days 1-3: 1, 1, 4
    expect(ins.upcoming.firstWhere((d) => d.cycleDay == 10).expected[Metric.energy], 4);
    expect(ins.baseline[Metric.energy], closeTo(3.79, 0.01));

    // Mood was always 4: nothing to report.
    expect(ins.patterns.where((p) => p.signal?.metric == Metric.mood), isEmpty);

    // Same medicine despite different spelling; day 1 ±1.
    final med = ins.patterns.where((p) => p.medicine != null).single;
    expect([med.label, med.fromDay, med.toDay, med.cycles], ['Ibuprofeno', 1, 2, 3]);
  });

  test('projects onto upcoming days', () {
    final h = history();
    final ins = computeInsights(period: h.period, journal: h.journal, meds: h.meds, now: DateTime(2026, 9, 24));

    // Today is day 2 of the cycle that began 2026-09-23.
    expect(ins.today!.cycleDay, 2);
    expect(ins.today!.signals, [const Signal(Metric.energy, false)]);
    expect(ins.today!.medicines, ['Ibuprofeno']);

    // Day 26 of this cycle (2026-10-18) brings hunger.
    final d26 = ins.upcoming.firstWhere((d) => d.date == '2026-10-18');
    expect(d26.cycleDay, 26);
    expect(d26.signals, [const Signal(Metric.hunger, true)]);

    // The next cycle repeats: 2026-10-21 is day 1 again.
    expect(ins.upcoming.firstWhere((d) => d.date == '2026-10-21').signals, [const Signal(Metric.energy, false)]);
  });

  test('detects highs as well as lows', () {
    final h = history();
    final boosted = [
      for (final j in h.journal)
        JournalEntry(
          date: j.date,
          energy: j.energy,
          hunger: j.hunger,
          mood: j.mood,
          // Lots of motivation mid-cycle (days 12-14), average otherwise.
          motivation: () {
            final cd = daysBetween(dayOf('2026-07-01'), dayOf(j.date)) % 28 + 1;
            return cd >= 12 && cd <= 14 ? 5 : 3;
          }(),
        ),
    ];
    final ins = computeInsights(period: h.period, journal: boosted, meds: const [], now: DateTime(2026, 9, 24));
    final more = ins.patterns.where((p) => p.signal == const Signal(Metric.motivation, true)).single;
    expect([more.fromDay, more.toDay, more.label], [12, 14, "más ganas"]);
  });

  test('a single cycle is not enough', () {
    final h = history();
    final firstCycle = h.journal.where((j) => j.date.compareTo('2026-07-29') < 0).toList();
    final ins = computeInsights(period: h.period, journal: firstCycle, meds: const [], now: DateTime(2026, 9, 24));
    expect(ins.patterns, isEmpty);
  });

  test('no period data means no forecast', () {
    final ins = computeInsights(period: const [], journal: const [], meds: const [], now: DateTime(2026, 9, 24));
    expect(ins.upcoming, isEmpty);
  });
}
