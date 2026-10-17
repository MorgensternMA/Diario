import '../models.dart';
import 'cycles.dart';

/// Daily levels the forecast learns from.
enum Metric {
  energy('energía', 'Energía'),
  motivation('ganas', 'Ganas'),
  mood('ánimo', 'Ánimo'),
  hunger('hambre', 'Hambre');

  final String label;
  final String title;
  const Metric(this.label, this.title);

  int of(JournalEntry j) => switch (this) {
    Metric.energy => j.energy,
    Metric.motivation => j.motivation,
    Metric.mood => j.mood,
    Metric.hunger => j.hunger,
  };
}

/// A metric standing out on a day, above or below the personal average.
class Signal {
  final Metric metric;
  final bool high;
  const Signal(this.metric, this.high);

  /// "más energía", "menos hambre".
  String get label => '${high ? 'más' : 'menos'} ${metric.label}';

  @override
  bool operator ==(Object other) => other is Signal && other.metric == metric && other.high == high;

  @override
  int get hashCode => Object.hash(metric, high);
}

/// How far a cycle-day average must sit from the personal average to count.
const _threshold = 0.6;

/// Days on either side pooled with each cycle day, to smooth sparse logs.
const _window = 1;

/// A pattern must show up in at least this many different cycles.
const _minCycles = 2;

/// Cycle days longer than this are logging gaps, not cycles.
const _maxCycleDay = 60;

/// A run of cycle days where a metric (or a medicine) tends to stand out.
class Pattern {
  final Signal? signal; // null for medicines
  final String? medicine;
  final int fromDay, toDay;
  final int cycles; // how many cycles back it up

  const Pattern({this.signal, this.medicine, required this.fromDay, required this.toDay, required this.cycles});

  String get days => fromDay == toDay ? 'día $fromDay' : 'días $fromDay–$toDay';

  /// "menos energía", "más ganas", "Ibuprofeno".
  String get label => medicine ?? signal!.label;
}

/// What to expect on a given upcoming date.
class DayForecast {
  final String date;
  final int cycleDay;
  final List<Signal> signals;
  final List<String> medicines;

  /// Expected 1-5 level per metric, when there's enough history.
  final Map<Metric, double> expected;

  const DayForecast(this.date, this.cycleDay, this.signals, this.medicines, [this.expected = const {}]);

  bool get isEmpty => signals.isEmpty && medicines.isEmpty;
}

class CycleInsights {
  /// Cycles that have at least one logged level.
  final int cyclesWithData;
  final int daysLogged;
  final List<Pattern> patterns;
  final List<DayForecast> upcoming; // next days, starting today

  /// Personal average per metric, the line the chart compares against.
  final Map<Metric, double> baseline;

  const CycleInsights({
    this.cyclesWithData = 0,
    this.daysLogged = 0,
    this.patterns = const [],
    this.upcoming = const [],
    this.baseline = const {},
  });

  DayForecast? get today => upcoming.isEmpty ? null : upcoming.first;

  bool get hasCurves => upcoming.any((d) => d.expected.isNotEmpty);
}

/// Learns which cycle days tend to bring more or less energy, motivation,
/// mood or hunger, or a given medicine, and projects them onto the next
/// [days] days. Gets sharper with every cycle logged.
CycleInsights computeInsights({
  required List<PeriodDay> period,
  required List<JournalEntry> journal,
  required List<({String date, String name})> meds,
  required DateTime now,
  int days = 35,
}) {
  final starts = periodStarts(period);
  if (starts.isEmpty) return const CycleInsights();
  final avgCycle = computeCycles(period, now).avgCycle;

  /// (cycle index, cycle day) of a date, or null outside any cycle.
  (int, int)? position(String date) {
    final t = dayOf(date);
    for (var i = starts.length - 1; i >= 0; i--) {
      if (!t.isBefore(starts[i])) {
        final cd = daysBetween(starts[i], t) + 1;
        return cd <= _maxCycleDay ? (i, cd) : null;
      }
    }
    return null;
  }

  // Samples per metric: cycle day -> list of (cycle, value).
  final samples = {for (final m in Metric.values) m: <int, List<(int, int)>>{}};
  final cyclesSeen = <int>{};
  var logged = 0;
  for (final j in journal) {
    final pos = position(j.date);
    if (pos == null) continue;
    var any = false;
    for (final m in Metric.values) {
      final v = m.of(j);
      if (v <= 0) continue;
      samples[m]!.putIfAbsent(pos.$2, () => []).add((pos.$1, v));
      any = true;
    }
    if (any) {
      logged++;
      cyclesSeen.add(pos.$1);
    }
  }

  // Medicine intakes: name -> cycle day -> cycles.
  final medDays = <String, Map<int, Set<int>>>{};
  final medNames = <String, String>{}; // lowercase -> display name
  for (final m in meds) {
    final pos = position(m.date);
    if (pos == null) continue;
    final key = m.name.trim().toLowerCase();
    medNames.putIfAbsent(key, () => m.name.trim());
    medDays.putIfAbsent(key, () => {}).putIfAbsent(pos.$2, () => {}).add(pos.$1);
  }

  // Smoothed average per cycle day, and which days stand out.
  final curves = <Metric, Map<int, double>>{};
  final baseline = <Metric, double>{};
  final signalDays = <Signal, Map<int, int>>{}; // signal -> cycle day -> supporting cycles
  for (final m in Metric.values) {
    final all = samples[m]!.values.expand((l) => l).toList();
    if (all.length < 6) continue;
    final base = all.fold(0, (s, x) => s + x.$2) / all.length;
    baseline[m] = base;
    for (var cd = 1; cd <= avgCycle; cd++) {
      final pool = [for (var d = cd - _window; d <= cd + _window; d++) ...?samples[m]![d]];
      final cycles = {for (final x in pool) x.$1};
      if (pool.length < 3 || cycles.length < _minCycles) continue;
      final avg = pool.fold(0, (s, x) => s + x.$2) / pool.length;
      curves.putIfAbsent(m, () => {})[cd] = avg;
      if (avg <= base - _threshold && avg <= 3) {
        signalDays.putIfAbsent(Signal(m, false), () => {})[cd] = cycles.length;
      } else if (avg >= base + _threshold && avg >= 3) {
        signalDays.putIfAbsent(Signal(m, true), () => {})[cd] = cycles.length;
      }
    }
  }
  final medicineDays = <String, Map<int, int>>{};
  medDays.forEach((key, byDay) {
    for (var cd = 1; cd <= avgCycle; cd++) {
      final cycles = {for (var d = cd - _window; d <= cd + _window; d++) ...?byDay[d]};
      if (cycles.length >= _minCycles) medicineDays.putIfAbsent(medNames[key]!, () => {})[cd] = cycles.length;
    }
  });

  // Runs of consecutive days become patterns.
  List<Pattern> runs(Map<int, int> byDay, {Signal? signal, String? medicine}) {
    final out = <Pattern>[];
    final sorted = byDay.keys.toList()..sort();
    var i = 0;
    while (i < sorted.length) {
      var j = i;
      while (j + 1 < sorted.length && sorted[j + 1] == sorted[j] + 1) {
        j++;
      }
      final support = [for (var k = i; k <= j; k++) byDay[sorted[k]]!].reduce((a, b) => a < b ? a : b);
      out.add(Pattern(signal: signal, medicine: medicine, fromDay: sorted[i], toDay: sorted[j], cycles: support));
      i = j + 1;
    }
    return out;
  }

  final patterns = [
    for (final e in signalDays.entries) ...runs(e.value, signal: e.key),
    for (final e in medicineDays.entries) ...runs(e.value, medicine: e.key),
  ]..sort((a, b) => a.fromDay != b.fromDay ? a.fromDay - b.fromDay : a.label.compareTo(b.label));

  // Project onto the coming days, repeating the average cycle.
  final today = DateTime.utc(now.year, now.month, now.day);
  final last = starts.last;
  final upcoming = <DayForecast>[];
  for (var k = 0; k < days; k++) {
    final t = addDays(today, k);
    final since = daysBetween(last, t);
    if (since < 0) continue;
    final cd = since % avgCycle + 1;
    upcoming.add(
      DayForecast(
        fmtDay(t),
        cd,
        [
          for (final e in signalDays.entries)
            if (e.value.containsKey(cd)) e.key,
        ],
        [
          for (final e in medicineDays.entries)
            if (e.value.containsKey(cd)) e.key,
        ],
        {
          for (final e in curves.entries)
            if (e.value[cd] != null) e.key: e.value[cd]!,
        },
      ),
    );
  }

  return CycleInsights(
    cyclesWithData: cyclesSeen.length,
    daysLogged: logged,
    patterns: patterns,
    upcoming: upcoming,
    baseline: baseline,
  );
}
