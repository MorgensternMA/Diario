import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common.dart';
import '../data/insights.dart';
import '../data/store.dart';
import '../models.dart';
import '../theme.dart';
import 'event_form.dart';
import 'food_page.dart';
import 'forecast_chart.dart';
import 'lists_page.dart';
import 'meds.dart';
import 'period_editor.dart';
import 'trackers_page.dart';

typedef _DayData = (Day, List<Category>, List<TodoList>, CycleSummary, CycleInsights, Set<String>);

/// Everything for a single day. Used as the "Hoy" tab and when opening a
/// day from the calendar or the agenda.
class DayPage extends StatefulWidget {
  final DateTime? date;
  const DayPage({super.key, this.date});

  @override
  State<DayPage> createState() => _DayPageState();
}

class _DayPageState extends State<DayPage> with Loader<DayPage, _DayData> {
  late DateTime _date = widget.date ?? today();

  bool get _isTab => widget.date == null;

  @override
  Future<_DayData> fetch() => (
    store.day(ymd(_date)),
    store.categories(),
    store.lists(),
    store.cycleSummary(),
    store.cycleInsights(),
    store.hiddenSections(),
  ).wait;

  void _goTo(DateTime d) {
    if (ymd(d) == ymd(_date)) return;
    setState(() => _date = DateTime(d.year, d.month, d.day));
    reload();
  }

  void _shift(int days) => _goTo(DateTime(_date.year, _date.month, _date.day + days));

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) _goTo(d);
  }

  String get _greeting {
    if (ymd(_date) != ymd(today())) return relativeDate(_date) == longDate(_date) ? 'Tu día' : relativeDate(_date);
    final h = DateTime.now().hour;
    return h < 6 || h >= 20 ? 'Buenas noches' : (h < 13 ? 'Buen día' : 'Buenas tardes');
  }

  @override
  Widget build(BuildContext context) {
    final title = DateFormat("EEEE d", 'es').format(_date);
    return Scaffold(
      appBar: _isTab ? null : AppBar(),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Agregar',
        onPressed: () => _quickAdd(context),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: SafeArea(
        bottom: false,
        child: GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() > 300) _shift(v < 0 ? 1 : -1);
          },
          child: Column(
            children: [
              PageHeader(
                subtitle: '$_greeting · ${DateFormat('MMMM', 'es').format(_date)}',
                title: title[0].toUpperCase() + title.substring(1),
                actions: [
                  IconButton(
                    tooltip: 'Elegir fecha',
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_rounded),
                  ),
                ],
              ),
              WeekStrip(selected: _date, onSelect: _goTo),
              const SizedBox(height: 6),
              Expanded(child: body(_content)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(_DayData d) {
    final (day, categories, lists, cycle, insights, hidden) = d;
    bool show(String key) => !hidden.contains(key);
    final forecast = insights.upcoming.where((f) => f.date == day.date).firstOrNull;
    return ListView(
      padding: const EdgeInsets.only(bottom: 100, top: 4),
      children: [
        if (show('cycle') && forecast != null && !forecast.isEmpty) _ForecastBanner(forecast: forecast),
        if (show('mood')) CheckInCard(key: ValueKey('j${day.date}'), date: day.date, entry: day.journal),
        if (show('agenda')) _EventsCard(day: day, categories: categories, date: _date),
        if (day.dueItems.isNotEmpty) _DueItemsCard(items: day.dueItems, lists: lists),
        if (show('food')) FoodSummaryCard(day: day),
        if (show('meds')) MedsCard(date: day.date, meds: day.meds),
        if (show('habits')) _TrackersCard(day: day),
        if (show('cycle'))
          SectionCard(
            title: 'Ciclo',
            subtitle: cycleStatus(cycle, short: true),
            icon: Icons.water_drop_rounded,
            color: periodColor,
            child: PeriodEditor(key: ValueKey('p${day.date}'), date: day.date, period: day.period, compact: true),
          ),
      ],
    );
  }

  Future<void> _quickAdd(BuildContext context) async {
    final date = ymd(_date);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.3,
            children: const [
              _QuickTile('event', 'Evento', Icons.event_rounded, Palette.agenda),
              _QuickTile('food', 'Comida', Icons.restaurant_rounded, Palette.food),
              _QuickTile('med', 'Remedio', Icons.medication_rounded, Palette.cycle),
              _QuickTile('item', 'A una lista', Icons.checklist_rounded, Palette.lists),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'event':
        await showEventForm(context, date: _date);
      case 'food':
        await showFoodSheet(context, date: date);
      case 'med':
        await showMedSheet(context, date: date);
      case 'item':
        await quickAddItem(context, dueDate: date);
    }
  }
}

class _QuickTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _QuickTile(this.value, this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: 0.13),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.pop(context, value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(label, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
      ),
    ),
  );
}

// ---------- Week strip ----------

class WeekStrip extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  const WeekStrip({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = Tokens.of(context);
    final monday = DateTime(selected.year, selected.month, selected.day - (selected.weekday - 1));
    const letters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onSelect(DateTime(selected.year, selected.month, selected.day - 7)),
            icon: Icon(Icons.chevron_left_rounded, color: t.muted),
          ),
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final d = DateTime(monday.year, monday.month, monday.day + i);
                  final isSel = ymd(d) == ymd(selected);
                  final isToday = ymd(d) == ymd(today());
                  return GestureDetector(
                    onTap: () => onSelect(d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? theme.colorScheme.primary : t.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isToday && !isSel ? theme.colorScheme.primary : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            letters[i],
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isSel ? Colors.white70 : t.muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isSel ? Colors.white : theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onSelect(DateTime(selected.year, selected.month, selected.day + 7)),
            icon: Icon(Icons.chevron_right_rounded, color: t.muted),
          ),
        ],
      ),
    );
  }
}

// ---------- Forecast ----------

class _ForecastBanner extends StatelessWidget {
  final DayForecast forecast;
  const _ForecastBanner({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final things = [for (final sig in forecast.signals) sig.label];
    final meds = forecast.medicines.join(' o ');
    final text = [
      if (things.isNotEmpty) 'podrías sentir ${joinEs(things)}',
      if (meds.isNotEmpty) 'quizás necesites $meds',
    ].join(', y ');
    return SoftCard(
      color: Palette.cycle.withValues(alpha: 0.13),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💛', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Día ${forecast.cycleDay} de tu ciclo: según tus ciclos anteriores, $text. Tomalo con calma.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// "a", "a y b", "a, b y c".
String joinEs(List<String> xs) =>
    xs.length <= 1 ? xs.join() : '${xs.sublist(0, xs.length - 1).join(', ')} y ${xs.last}';

// ---------- Check-in: mood, levels, feelings and diary ----------

class CheckInCard extends StatefulWidget {
  final String date;
  final JournalEntry? entry;
  const CheckInCard({super.key, required this.date, this.entry});

  @override
  State<CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends State<CheckInCard> {
  late int _mood = widget.entry?.mood ?? 0;
  late final _levels = {
    'energy': widget.entry?.energy ?? 0,
    'motivation': widget.entry?.motivation ?? 0,
    'hunger': widget.entry?.hunger ?? 0,
  };
  late List<String> _feelings = [...?widget.entry?.feelings];
  late final _note = TextEditingController(text: widget.entry?.note);
  Timer? _debounce;

  @override
  void dispose() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _save();
    }
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await store.saveJournal(
        JournalEntry(
          date: widget.date,
          mood: _mood,
          energy: _levels['energy']!,
          motivation: _levels['motivation']!,
          hunger: _levels['hunger']!,
          feelings: _feelings,
          note: _note.text,
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _saveSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), _save);
  }

  Future<void> _pickFeelings() async {
    var picked = _feelings;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Qué sentís?', style: Theme.of(ctx).textTheme.headlineSmall),
                const SizedBox(height: 14),
                TagPicker(
                  options: feelingOptions,
                  selected: picked,
                  color: Palette.journal,
                  onChanged: (v) => setSheet(() => picked = v),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || picked == _feelings) return;
    setState(() => _feelings = picked);
    _save();
  }

  String _levelText(String key, (String, String, String) labels) {
    final v = _levels[key]!;
    if (v == 0) return '';
    return v <= 2 ? labels.$2 : (v >= 4 ? labels.$3 : 'Normal');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = Tokens.of(context);
    final levelColors = {
      'energy': metricColor(context, Metric.energy),
      'motivation': metricColor(context, Metric.motivation),
      'hunger': metricColor(context, Metric.hunger),
    };
    return SectionCard(
      title: '¿Cómo estás?',
      icon: Icons.favorite_rounded,
      color: Palette.journal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var m = 1; m <= 5; m++)
                GestureDetector(
                  onTap: () {
                    setState(() => _mood = _mood == m ? 0 : m);
                    _save();
                  },
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 50,
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _mood == m
                              ? Palette.journal.withValues(alpha: 0.22)
                              : theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: _mood == 0 || _mood == m ? 1 : 0.45,
                          child: Text(moodEmoji[m], style: const TextStyle(fontSize: 25)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        moodLabel[m],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _mood == m ? FontWeight.w800 : FontWeight.w600,
                          color: _mood == m ? theme.colorScheme.onSurface : t.muted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final e in levelLabels.entries)
            Row(
              children: [
                SizedBox(width: 72, child: Text(e.value.$1, style: theme.textTheme.titleSmall)),
                Expanded(
                  child: Text(
                    _levelText(e.key, e.value),
                    style: theme.textTheme.bodySmall?.copyWith(color: t.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                LevelPicker(
                  value: _levels[e.key]!,
                  color: levelColors[e.key]!,
                  onChanged: (v) {
                    setState(() => _levels[e.key] = v);
                    _save();
                  },
                ),
              ],
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final f in _feelings)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Palette.journal.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(f, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ActionChip(
                avatar: Icon(_feelings.isEmpty ? Icons.add_rounded : Icons.edit_rounded, size: 16),
                label: Text(_feelings.isEmpty ? 'Emociones' : 'Editar'),
                onPressed: _pickFeelings,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _saveSoon(),
            decoration: const InputDecoration(hintText: 'Querido diario…'),
          ),
        ],
      ),
    );
  }
}

// ---------- Events ----------

class _EventsCard extends StatelessWidget {
  final Day day;
  final List<Category> categories;
  final DateTime date;
  const _EventsCard({required this.day, required this.categories, required this.date});

  @override
  Widget build(BuildContext context) {
    final byId = {for (final c in categories) c.id: c};
    return SectionCard(
      title: 'Agenda',
      icon: Icons.event_note_rounded,
      color: Palette.agenda,
      trailing: IconButton(
        tooltip: 'Agregar evento',
        onPressed: () => showEventForm(context, date: date),
        icon: const Icon(Icons.add_rounded),
      ),
      child: day.events.isEmpty
          ? const EmptyHint('Nada agendado')
          : Column(
              children: [for (final e in day.events) EventTile(event: e, category: byId[e.categoryId])],
            ),
    );
  }
}

class EventTile extends StatelessWidget {
  final Event event;
  final Category? category;
  final bool showDate;
  const EventTile({super.key, required this.event, this.category, this.showDate = false});

  @override
  Widget build(BuildContext context) {
    final muted = Tokens.of(context).muted;
    final color = category == null ? muted : hexColor(category!.color);
    final parts = [
      if (showDate) shortDate(event.date),
      if (event.time.isNotEmpty) event.time,
      if (category != null) category!.name,
    ];
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => showEventForm(context, event: event),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      decoration: event.done ? TextDecoration.lineThrough : null,
                      color: event.done ? muted : null,
                    ),
                  ),
                  if (parts.isNotEmpty) Text(parts.join(' · '), style: TextStyle(fontSize: 13, color: muted)),
                ],
              ),
            ),
            Checkbox(
              value: event.done,
              activeColor: color,
              onChanged: (v) => attempt(context, () => store.saveEvent(event.copyWith(done: v))),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Due list items ----------

class _DueItemsCard extends StatelessWidget {
  final List<Item> items;
  final List<TodoList> lists;
  const _DueItemsCard({required this.items, required this.lists});

  @override
  Widget build(BuildContext context) {
    final byId = {for (final l in lists) l.id: l};
    return SectionCard(
      title: 'Pendientes para este día',
      icon: Icons.checklist_rounded,
      color: Palette.lists,
      child: Column(
        children: [
          for (final i in items)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: Palette.lists,
              value: i.done,
              title: Text(i.quantity.isEmpty ? i.text : '${i.text} (${i.quantity})'),
              subtitle: Text(byId[i.listId]?.name ?? ''),
              onChanged: (v) => attempt(context, () => store.saveItem(i.listId, i.copyWith(done: v))),
            ),
        ],
      ),
    );
  }
}

// ---------- Trackers ----------

class _TrackersCard extends StatelessWidget {
  final Day day;
  const _TrackersCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final done = day.trackers.where((t) => t.tracker.isDone(t.value)).length;
    return SectionCard(
      title: 'Hábitos',
      subtitle: day.trackers.isEmpty ? null : '$done de ${day.trackers.length}',
      icon: Icons.track_changes_rounded,
      color: Palette.habits,
      trailing: IconButton(
        tooltip: 'Gestionar',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrackersPage())),
        icon: const Icon(Icons.tune_rounded),
      ),
      child: day.trackers.isEmpty
          ? const EmptyHint('Agregá hábitos o cualquier cosa que quieras seguir.')
          : Column(
              children: [for (final t in day.trackers) TrackerInput(date: day.date, td: t)],
            ),
    );
  }
}

class TrackerInput extends StatelessWidget {
  final String date;
  final TrackerDay td;
  const TrackerInput({super.key, required this.date, required this.td});

  Tracker get t => td.tracker;

  void _set(BuildContext context, double? v) {
    if (v == null && td.value == null) return;
    attempt(context, () => store.setEntry(t.id, date, v));
  }

  Future<void> _askNumber(BuildContext context) async {
    final ctrl = TextEditingController(text: td.value == null ? '' : fmtNum(td.value!));
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.name),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: t.unit),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          if (td.value != null) TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Borrar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Guardar')),
        ],
      ),
    );
    if (res == null || !context.mounted) return;
    final txt = res.replaceAll(',', '.').trim();
    _set(context, txt.isEmpty ? null : double.tryParse(txt));
  }

  @override
  Widget build(BuildContext context) {
    final color = hexColor(t.color);
    final v = td.value;
    final unit = t.unit.isEmpty ? '' : ' ${t.unit}';

    final Widget trailing = switch (t.kind) {
      'check' => Checkbox(
        value: (v ?? 0) > 0,
        activeColor: color,
        onChanged: (on) => _set(context, on == true ? 1 : null),
      ),
      'count' => _Stepper(
        value: v ?? 0,
        color: color,
        onMinus: (v ?? 0) <= 0 ? null : () => _set(context, v! - 1 <= 0 ? null : v - 1),
        onPlus: () => _set(context, (v ?? 0) + 1),
      ),
      'scale' => LevelPicker(
        value: (v ?? 0).round(),
        color: color,
        onChanged: (i) => _set(context, i == 0 ? null : i.toDouble()),
      ),
      _ => TextButton(onPressed: () => _askNumber(context), child: Text(v == null ? 'Anotar' : '${fmtNum(v)}$unit')),
    };

    // Small goals (like 8 glasses) read better as a row of tappable icons.
    final iconRow = t.kind == 'count' && t.goal >= 1 && t.goal <= 12 && t.goal == t.goal.roundToDouble();
    final progress = !iconRow && v != null && t.goal > 0 && (t.kind == 'count' || t.kind == 'number')
        ? (v / t.goal).clamp(0.0, 1.0)
        : null;
    final muted = Tokens.of(context).muted;
    final status = switch (t.kind) {
      'count' when t.goal > 0 => '${fmtNum(v ?? 0)} de ${fmtNum(t.goal)}$unit',
      'count' => '${fmtNum(v ?? 0)}$unit',
      'number' when t.goal > 0 && v != null => 'meta ${fmtNum(t.goal)}$unit',
      _ => null,
    };

    final drops = !iconRow
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 44, top: 6),
            child: Wrap(
              spacing: 4,
              children: [
                for (var i = 0; i < t.goal; i++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Tapping the last filled icon empties it; any other sets the count.
                    onTap: () => _set(context, (v ?? 0).round() == i + 1 ? (i == 0 ? null : i.toDouble()) : i + 1.0),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(iconFor(t.icon), size: 22, color: i < (v ?? 0) ? color : Tokens.of(context).line),
                    ),
                  ),
              ],
            ),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(iconFor(t.icon), color, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    if (status != null) Text(status, style: TextStyle(fontSize: 12.5, color: muted)),
                    if (progress != null) ...[
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: progress,
                          color: color,
                          backgroundColor: Tokens.of(context).line,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
          ?drops,
        ],
      ),
    );
  }
}

/// Pill-shaped − value + control.
class _Stepper extends StatelessWidget {
  final double value;
  final Color color;
  final VoidCallback? onMinus;
  final VoidCallback onPlus;
  const _Stepper({required this.value, required this.color, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, VoidCallback? onTap, {bool filled = false}) => Material(
      color: filled ? color : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: filled ? Colors.white : (onTap == null ? Tokens.of(context).line : color)),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove_rounded, onMinus),
          SizedBox(
            width: 30,
            child: Text(
              fmtNum(value),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          button(Icons.add_rounded, onPlus, filled: true),
        ],
      ),
    );
  }
}
