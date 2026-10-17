import 'package:diario/data/cycles.dart';
import 'package:diario/models.dart';
import 'package:flutter_test/flutter_test.dart';

List<PeriodDay> days(int flow, List<String> dates) => [for (final d in dates) PeriodDay(date: d, flow: flow)];

DateTime d(String s) => DateTime.parse(s);

void main() {
  test('no data uses defaults', () {
    final s = computeCycles([], d('2026-10-16'));
    expect(s.hasData, isFalse);
    expect(s.avgCycle, 28);
    expect(s.avgPeriod, 5);
    expect(s.predictions, isEmpty);
  });

  test('averages, gaps and spotting', () {
    final log = [
      ...days(3, ['2026-07-01', '2026-07-02', '2026-07-03', '2026-07-04']),
      // 30 days later, with a gap day inside the period and spotting around it.
      ...days(1, ['2026-07-30']),
      ...days(4, ['2026-07-31', '2026-08-01', '2026-08-03']),
      ...days(1, ['2026-08-04']),
      // 28 days later.
      ...days(2, ['2026-08-28', '2026-08-29', '2026-08-30', '2026-08-31', '2026-09-01', '2026-09-02']),
      // A lone spotting day is not a period.
      ...days(1, ['2026-09-15']),
    ];
    final s = computeCycles(log, d('2026-09-10'));

    expect(s.cycles, hasLength(3));
    final mid = s.cycles[1];
    expect([mid.start, mid.end, mid.periodLength, mid.cycleLength], ['2026-07-31', '2026-08-03', 4, 28]);
    expect(s.avgCycle, 29);
    expect(s.avgPeriod, 5);
    expect(s.lastStart, '2026-08-28');
    expect(s.cycleDay, 14);
    expect(s.nextStart, '2026-09-26');
    expect(s.daysUntilNext, 16);
    expect(s.inPeriod, isFalse);
    final p = s.predictions.first;
    expect(
      [p.start, p.end, p.ovulation, p.fertileStart, p.fertileEnd],
      ['2026-09-26', '2026-09-30', '2026-09-12', '2026-09-07', '2026-09-13'],
    );
    expect(s.predictions, hasLength(3));
  });

  test('late period and paused logging', () {
    final log = days(3, ['2026-01-01', '2026-01-02', '2026-01-03']);
    expect(computeCycles(log, d('2026-02-03')).daysUntilNext, -5); // expected 2026-01-29
    final later = computeCycles(log, d('2026-10-16'));
    expect(later.predictions.first.end.compareTo('2026-10-16'), greaterThanOrEqualTo(0));
  });

  test('ongoing period is excluded from the average length', () {
    final log = [
      ...days(3, ['2026-09-20', '2026-09-21', '2026-09-22', '2026-09-23', '2026-09-24']),
      ...days(4, ['2026-10-14', '2026-10-15']),
    ];
    final s = computeCycles(log, d('2026-10-16'));
    expect(s.inPeriod, isTrue);
    expect(s.avgPeriod, 5);
  });

  test('day arithmetic ignores DST changes', () {
    expect(daysBetween(dayOf('2026-03-28'), dayOf('2026-11-02')), 219);
    expect(fmtDay(addDays(dayOf('2026-12-31'), 1)), '2027-01-01');
  });
}
