import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common.dart';
import '../data/insights.dart';
import '../data/store.dart';
import '../models.dart';
import '../theme.dart';
import 'day_page.dart';
import 'event_form.dart';
import 'forecast_chart.dart';

typedef _CalData = (Map<String, CalendarDay>, bool, CycleInsights, Map<String, JournalEntry>);

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with Loader<CalendarPage, _CalData> {
  DateTime _month = DateTime(today().year, today().month);
  DateTime _selected = today();

  /// The grid always starts on the Monday on or before the 1st, 6 weeks long.
  DateTime get _gridStart => DateTime(_month.year, _month.month, 1 - (_month.weekday - 1));
  DateTime get _gridEnd => DateTime(_gridStart.year, _gridStart.month, _gridStart.day + 41);

  @override
  Future<_CalData> fetch() async {
    final ahead = _gridEnd.difference(today()).inDays + 1;
    final lastDay = DateTime(_month.year, _month.month + 1, 0);
    final (days, hidden, insights, journal) = await (
      store.calendar(ymd(_gridStart), ymd(_gridEnd)),
      store.hiddenSections(),
      store.cycleInsights(days: ahead < 1 ? 1 : ahead),
      store.journalBetween(ymd(_month), ymd(lastDay)),
    ).wait;
    return (
      {for (final d in days) d.date: d},
      !hidden.contains('cycle'),
      insights,
      {for (final j in journal) j.date: j},
    );
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    reload();
  }

  void _openDay(DateTime d) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DayPage(date: d)));
  }

  @override
  Widget build(BuildContext context) {
    final month = DateFormat('MMMM', 'es').format(_month);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo evento',
        onPressed: () => showEventForm(context, date: _selected),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(
              subtitle: '${_month.year}',
              title: month[0].toUpperCase() + month.substring(1),
              actions: [
                if (_month.year != today().year || _month.month != today().month)
                  IconButton(
                    tooltip: 'Hoy',
                    onPressed: () {
                      setState(() {
                        _month = DateTime(today().year, today().month);
                        _selected = today();
                      });
                      reload();
                    },
                    icon: const Icon(Icons.today_rounded),
                  ),
                IconButton(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
                IconButton(onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
              ],
            ),
            Expanded(
              child: body((d) {
                final (days, showCycle, insights, journal) = d;
                final forecast = {for (final f in insights.upcoming) f.date: f};
                return GestureDetector(
                  onHorizontalDragEnd: (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (v.abs() > 300) _shiftMonth(v < 0 ? 1 : -1);
                  },
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 100),
                    children: [
                      SoftCard(
                        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                        child: Column(
                          children: [
                            _weekdayHeader(context),
                            GridView.count(
                              crossAxisCount: 7,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: 0.82,
                              children: [
                                for (var i = 0; i < 42; i++)
                                  _cell(
                                    context,
                                    DateTime(_gridStart.year, _gridStart.month, _gridStart.day + i),
                                    days,
                                    showCycle,
                                  ),
                              ],
                            ),
                            if (showCycle) ...[const SizedBox(height: 8), const _Legend()],
                          ],
                        ),
                      ),
                      _selectedSummary(
                        context,
                        days[ymd(_selected)],
                        showCycle,
                        showCycle ? forecast[ymd(_selected)]?.signals : null,
                      ),
                      _monthChart(context, days, journal, showCycle ? forecast : const {}, insights.baseline),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  /// Line chart of the month: logged levels, then the projection.
  Widget _monthChart(
    BuildContext context,
    Map<String, CalendarDay> calendar,
    Map<String, JournalEntry> journal,
    Map<String, DayForecast> forecast,
    Map<Metric, double> baseline,
  ) {
    final count = DateTime(_month.year, _month.month + 1, 0).day;
    final todayStr = ymd(today());
    final days = <ChartDay>[];
    for (var d = 1; d <= count; d++) {
      final date = ymd(DateTime(_month.year, _month.month, d));
      final cal = calendar[date];
      final period = (cal?.flow ?? 0) > 0 || (cal?.predictedPeriod ?? false);
      final j = journal[date];
      final logged = {
        if (j != null)
          for (final m in Metric.values)
            if (m.of(j) > 0) m: m.of(j).toDouble(),
      };
      final f = forecast[date];
      if (logged.isNotEmpty || date.compareTo(todayStr) < 0 || f == null) {
        days.add(ChartDay(date, logged, period: period));
      } else {
        days.add(ChartDay(date, f.expected, projected: true, period: period));
      }
    }

    final Widget child;
    if (days.every((d) => d.values.isEmpty)) {
      child = Text(
        'Anotá en "Hoy" tu energía, ganas, ánimo y hambre y acá vas a ver cómo te fue en el mes. '
        'Con 2 ciclos registrados también vas a ver la proyección de los días que vienen.',
        style: TextStyle(color: Tokens.of(context).muted, height: 1.4),
      );
    } else {
      final inMonth = _selected.year == _month.year && _selected.month == _month.month;
      child = LevelChart(
        days: days,
        baseline: baseline,
        ticks: {for (var d = 1; d <= count; d += 7) d - 1: '$d'},
        selected: inMonth ? _selected.day - 1 : 0,
        onSelect: (i) => setState(() => _selected = DateTime(_month.year, _month.month, i + 1)),
        title: (d) {
          final label = relativeDate(parseYmd(d.date));
          final what = d.values.isEmpty ? 'sin registro' : (d.projected ? 'proyección' : 'anotado');
          return '${label == longDate(parseYmd(d.date)) ? shortDate(d.date) : label} · $what';
        },
      );
    }
    return SectionCard(
      title: 'Tu mes',
      subtitle: 'Energía, ganas, ánimo y hambre',
      icon: Icons.show_chart_rounded,
      color: Palette.agenda,
      child: child,
    );
  }

  Widget _weekdayHeader(BuildContext context) {
    const names = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Row(
      children: [
        for (final n in names)
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  n,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Tokens.of(context).muted),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, DateTime date, Map<String, CalendarDay> days, bool showCycle) {
    final scheme = Theme.of(context).colorScheme;
    final d = days[ymd(date)];
    final inMonth = date.month == _month.month;
    final isToday = ymd(date) == ymd(today());
    final isSelected = ymd(date) == ymd(_selected);
    final flow = showCycle ? (d?.flow ?? 0) : 0;

    Color? bg;
    if (isSelected) {
      bg = scheme.primary;
    } else if (flow > 0) {
      bg = flowColor(flow);
    } else if (showCycle && (d?.fertile ?? false)) {
      bg = fertileColor.withValues(alpha: 0.13);
    }

    final dots = <Color>[
      for (final e in (d?.events ?? const <CalendarEvent>[]).take(3)) hexColor(e.color),
      if ((d?.dueItems ?? 0) > 0) Palette.lists,
    ];

    final Border? border;
    if (isToday && !isSelected) {
      border = Border.all(color: scheme.primary, width: 1.8);
    } else if (showCycle && (d?.predictedPeriod ?? false) && !isSelected) {
      border = Border.all(color: periodColor.withValues(alpha: 0.6), width: 1.5);
    } else {
      border = null;
    }

    return GestureDetector(
      onTap: () => setState(() => _selected = date),
      onDoubleTap: () => _openDay(date),
      onLongPress: () => _openDay(date),
      child: Opacity(
        opacity: inMonth ? 1 : 0.35,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: border),
          child: Stack(
            children: [
              if ((d?.mood ?? 0) > 0)
                Positioned(top: 2, right: 3, child: Text(moodEmoji[d!.mood], style: const TextStyle(fontSize: 9))),
              Positioned(
                top: 2,
                left: 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showCycle && (d?.ovulation ?? false))
                      Icon(Icons.egg_alt_rounded, size: 10, color: isSelected ? Colors.white : fertileColor),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final c in dots)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(color: isSelected ? Colors.white : c, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectedSummary(BuildContext context, CalendarDay? d, bool showCycle, List<Signal>? signals) {
    final theme = Theme.of(context);
    Widget line(String text, {Color? dot}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (dot != null) ...[Icon(Icons.circle, size: 9, color: dot), const SizedBox(width: 10)],
          Expanded(child: Text(text)),
        ],
      ),
    );
    final lines = <Widget>[
      for (final e in d?.events ?? const <CalendarEvent>[]) line(e.title, dot: hexColor(e.color)),
      if ((d?.dueItems ?? 0) > 0) line('${d!.dueItems} pendiente(s) de listas', dot: Palette.lists),
      if ((d?.mood ?? 0) > 0) line('${moodEmoji[d!.mood]}  ${moodLabel[d.mood]}'),
      if (showCycle) ...[
        if ((d?.flow ?? 0) > 0) line('Menstruación: ${flowLabel[d!.flow].toLowerCase()}', dot: periodColor),
        if (d?.predictedPeriod ?? false) line('Período estimado', dot: periodColor.withValues(alpha: 0.5)),
        if (d?.ovulation ?? false) line('Ovulación estimada', dot: fertileColor),
        if ((d?.fertile ?? false) && !(d?.ovulation ?? false))
          line('Ventana fértil estimada', dot: fertileColor.withValues(alpha: 0.5)),
        for (final s in signals ?? const <Signal>[])
          line('Pronóstico: ${s.label}', dot: metricColor(context, s.metric)),
      ],
    ];
    return SoftCard(
      onTap: () => _openDay(_selected),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(relativeDate(_selected), style: theme.textTheme.titleLarge)),
              Icon(Icons.arrow_forward_rounded, color: Tokens.of(context).muted),
            ],
          ),
          const SizedBox(height: 8),
          if (lines.isEmpty) const EmptyHint('Nada registrado. Tocá para abrir el día.') else ...lines,
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Widget swatch, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Tokens.of(context).muted),
        ),
      ],
    );
    Widget box({Color? fill, Color? border}) => Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(4),
        border: border == null ? null : Border.all(color: border, width: 1.5),
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 4,
      children: [
        item(box(fill: flowColor(3)), 'Período'),
        item(box(border: periodColor), 'Estimado'),
        item(box(fill: fertileColor.withValues(alpha: 0.3)), 'Fértil'),
        item(const Icon(Icons.egg_alt_rounded, size: 12, color: fertileColor), 'Ovulación'),
      ],
    );
  }
}
