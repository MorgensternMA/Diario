import '../models.dart';

// Flow levels for a period day.
const flowSpotting = 1; // manchado
const flowLight = 2; // leve

// Defaults used until there is enough history to compute averages.
const _defaultCycle = 28;
const _defaultPeriod = 5;
// Days without bleeding allowed inside a single period.
const _maxGap = 2;
// Cycles outside this range are treated as logging mistakes.
const _minCycle = 15, _maxCycle = 60;
// How many recent cycles feed the averages.
const _avgWindow = 6;

/// Dates are handled as UTC midnights so day arithmetic ignores DST.
DateTime dayOf(String ymd) =>
    DateTime.utc(int.parse(ymd.substring(0, 4)), int.parse(ymd.substring(5, 7)), int.parse(ymd.substring(8, 10)));

String fmtDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime addDays(DateTime d, int n) => DateTime.utc(d.year, d.month, d.day + n);

int daysBetween(DateTime a, DateTime b) => b.difference(a).inDays;

class _Period {
  final DateTime start, end;
  _Period(this.start, this.end);
}

/// Merges logged days into periods. Days separated by at most [_maxGap]
/// missing days belong to the same period; leading and trailing spotting is
/// trimmed, and spotting-only groups are dropped.
List<_Period> _groupPeriods(List<PeriodDay> days) {
  final parsed = [for (final d in days) (t: dayOf(d.date), flow: d.flow)]..sort((a, b) => a.t.compareTo(b.t));

  final out = <_Period>[];
  var group = <({DateTime t, int flow})>[];
  void flush() {
    final bleeding = group.where((d) => d.flow >= flowLight).toList();
    if (bleeding.isNotEmpty) out.add(_Period(bleeding.first.t, bleeding.last.t));
    group = [];
  }

  for (final d in parsed) {
    if (group.isNotEmpty && daysBetween(group.last.t, d.t) > _maxGap + 1) flush();
    group.add(d);
  }
  flush();
  return out;
}

int _average(List<int> xs, int fallback) {
  if (xs.isEmpty) return fallback;
  final recent = xs.length > _avgWindow ? xs.sublist(xs.length - _avgWindow) : xs;
  return (recent.reduce((a, b) => a + b) / recent.length).round();
}

/// Derives cycle history, averages and the next predictions from the logged
/// period days, as of [now].
CycleSummary computeCycles(List<PeriodDay> days, DateTime now) {
  final today = DateTime.utc(now.year, now.month, now.day);
  final periods = _groupPeriods(days);
  if (periods.isEmpty) {
    return const CycleSummary(
      hasData: false,
      avgCycle: _defaultCycle,
      avgPeriod: _defaultPeriod,
      lastStart: '',
      cycleDay: 0,
      nextStart: '',
      daysUntilNext: 0,
      inPeriod: false,
      cycles: [],
      predictions: [],
    );
  }

  final cycleLens = <int>[];
  final periodLens = <int>[];
  final cycles = <Cycle>[];
  for (var i = 0; i < periods.length; i++) {
    final p = periods[i];
    final len = daysBetween(p.start, p.end) + 1;
    periodLens.add(len);
    var cycleLen = 0;
    if (i + 1 < periods.length) {
      cycleLen = daysBetween(p.start, periods[i + 1].start);
      if (cycleLen >= _minCycle && cycleLen <= _maxCycle) cycleLens.add(cycleLen);
    }
    cycles.add(Cycle(fmtDay(p.start), fmtDay(p.end), len, cycleLen));
  }

  final last = periods.last;
  final ongoing = !today.isBefore(last.start) && daysBetween(last.end, today) <= 1;
  // A period still in progress would drag the average length down.
  if (ongoing && periodLens.length > 1) periodLens.removeLast();

  final avgCycle = _average(cycleLens, _defaultCycle);
  final avgPeriod = _average(periodLens, _defaultPeriod);
  final cycleDay = daysBetween(last.start, today) + 1;
  final next = addDays(last.start, avgCycle);

  // Upcoming predictions, skipping ones entirely in the past (e.g. when
  // logging was paused for a few months).
  final predictions = <Prediction>[];
  for (var k = 1; predictions.length < 3 && k < 100; k++) {
    final start = addDays(last.start, k * avgCycle);
    final end = addDays(start, avgPeriod - 1);
    if (end.isBefore(today)) continue;
    final ov = addDays(start, -14);
    predictions.add(
      Prediction(fmtDay(start), fmtDay(end), fmtDay(ov), fmtDay(addDays(ov, -5)), fmtDay(addDays(ov, 1))),
    );
  }

  return CycleSummary(
    hasData: true,
    avgCycle: avgCycle,
    avgPeriod: avgPeriod,
    lastStart: fmtDay(last.start),
    cycleDay: cycleDay < 1 ? 0 : cycleDay,
    nextStart: fmtDay(next),
    daysUntilNext: daysBetween(today, next),
    inPeriod: ongoing,
    cycles: cycles.reversed.toList(),
    predictions: predictions,
  );
}
