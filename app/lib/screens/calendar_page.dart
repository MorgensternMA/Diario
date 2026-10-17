import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/store.dart';
import '../common.dart';
import '../models.dart';
import 'day_page.dart';
import 'event_form.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> with Loader<CalendarPage, Map<String, CalendarDay>> {
  DateTime _month = DateTime(today().year, today().month);
  DateTime _selected = today();

  /// The grid always starts on the Monday on or before the 1st, 6 weeks long.
  DateTime get _gridStart => DateTime(_month.year, _month.month, 1 - (_month.weekday - 1));
  DateTime get _gridEnd => DateTime(_gridStart.year, _gridStart.month, _gridStart.day + 41);

  @override
  Future<Map<String, CalendarDay>> fetch() async {
    final days = await store.calendar(ymd(_gridStart), ymd(_gridEnd));
    return {for (final d in days) d.date: d};
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
    final title = DateFormat('MMMM yyyy', 'es').format(_month);
    return Scaffold(
      appBar: AppBar(
        title: Text(title[0].toUpperCase() + title.substring(1)),
        actions: [
          IconButton(
            tooltip: 'Hoy',
            onPressed: () {
              setState(() {
                _month = DateTime(today().year, today().month);
                _selected = today();
              });
              reload();
            },
            icon: const Icon(Icons.today),
          ),
          IconButton(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_right)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo evento',
        onPressed: () => showEventForm(context, date: _selected),
        child: const Icon(Icons.add),
      ),
      body: body(
        (days) => GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() > 300) _shiftMonth(v < 0 ? 1 : -1);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 88),
            children: [
              _weekdayHeader(context),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.78,
                children: [
                  for (var i = 0; i < 42; i++)
                    _cell(context, DateTime(_gridStart.year, _gridStart.month, _gridStart.day + i), days),
                ],
              ),
              const SizedBox(height: 8),
              const _Legend(),
              const Divider(height: 24),
              _selectedSummary(context, days[ymd(_selected)]),
            ],
          ),
        ),
      ),
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
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(n, style: Theme.of(context).textTheme.labelMedium),
              ),
            ),
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, DateTime date, Map<String, CalendarDay> days) {
    final scheme = Theme.of(context).colorScheme;
    final d = days[ymd(date)];
    final inMonth = date.month == _month.month;
    final isToday = ymd(date) == ymd(today());
    final isSelected = ymd(date) == ymd(_selected);

    Color? bg;
    if ((d?.flow ?? 0) > 0) {
      bg = flowColor(d!.flow);
    } else if (d?.fertile ?? false) {
      bg = fertileColor.withValues(alpha: 0.12);
    }

    final dots = <Color>[
      for (final e in (d?.events ?? const <CalendarEvent>[]).take(3)) hexColor(e.color),
      if ((d?.dueItems ?? 0) > 0) scheme.outline,
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _selected = date),
      onDoubleTap: () => _openDay(date),
      onLongPress: () => _openDay(date),
      child: Opacity(
        opacity: inMonth ? 1 : 0.4,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: scheme.primary, width: 2)
                : (d?.predictedPeriod ?? false)
                ? Border.all(color: periodColor.withValues(alpha: 0.7), width: 1.5)
                : null,
          ),
          child: Stack(
            children: [
              if ((d?.mood ?? 0) > 0)
                Positioned(top: 2, right: 3, child: Text(moodEmoji[d!.mood], style: const TextStyle(fontSize: 10))),
              if (d?.ovulation ?? false)
                const Positioned(top: 3, left: 3, child: Icon(Icons.egg_alt, size: 10, color: fertileColor)),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: isToday ? BoxDecoration(color: scheme.primary, shape: BoxShape.circle) : null,
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontWeight: isToday ? FontWeight.bold : null,
                        color: isToday ? scheme.onPrimary : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 6,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final c in dots)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
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

  Widget _selectedSummary(BuildContext context, CalendarDay? d) {
    final theme = Theme.of(context);
    final lines = <Widget>[
      if ((d?.mood ?? 0) > 0) Text('${moodEmoji[d!.mood]}  ${moodLabel[d.mood]}'),
      if ((d?.flow ?? 0) > 0) Text('🩸 Menstruación: ${flowLabel[d!.flow].toLowerCase()}'),
      if (d?.predictedPeriod ?? false) const Text('Período estimado'),
      if (d?.ovulation ?? false) const Text('Ovulación estimada'),
      if ((d?.fertile ?? false) && !(d?.ovulation ?? false)) const Text('Ventana fértil estimada'),
      if ((d?.dueItems ?? 0) > 0) Text('${d!.dueItems} pendiente(s) de listas'),
      for (final e in d?.events ?? const <CalendarEvent>[])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(Icons.circle, size: 10, color: hexColor(e.color)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(e.title, style: e.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
              ),
            ],
          ),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(relativeDate(_selected), style: theme.textTheme.titleMedium)),
              FilledButton.tonalIcon(
                onPressed: () => _openDay(_selected),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Abrir día'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (lines.isEmpty) const EmptyHint('Sin registros') else ...lines,
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
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
    Widget box({Color? fill, Color? border}) => Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(3),
        border: border == null ? null : Border.all(color: border, width: 1.5),
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        item(box(fill: flowColor(3)), 'Período'),
        item(box(border: periodColor), 'Estimado'),
        item(box(fill: fertileColor.withValues(alpha: 0.25)), 'Fértil'),
        item(const Icon(Icons.egg_alt, size: 12, color: fertileColor), 'Ovulación'),
      ],
    );
  }
}
