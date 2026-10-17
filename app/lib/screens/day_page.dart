import 'dart:async';

import 'package:flutter/material.dart';

import '../data/store.dart';
import '../common.dart';
import '../models.dart';
import 'event_form.dart';
import 'backup_page.dart';
import 'trackers_page.dart';

typedef _DayData = (Day, List<Category>, List<TodoList>);

/// Everything for a single day: mood & diary, agenda, due items, habits and
/// period. Used as the "Hoy" tab and when opening a day from the calendar.
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
  Future<_DayData> fetch() => (store.day(ymd(_date)), store.categories(), store.lists()).wait;

  void _go(int days) {
    setState(() {
      _date = DateTime(_date.year, _date.month, _date.day + days);
      data = null;
    });
    reload();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) _go(d.difference(_date).inDays);
  }

  @override
  Widget build(BuildContext context) {
    final isToday = ymd(_date) == ymd(today());
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(onTap: _pickDate, child: Text(relativeDate(_date))),
        actions: [
          if (!isToday)
            IconButton(
              tooltip: 'Ir a hoy',
              onPressed: () => _go(today().difference(_date).inDays),
              icon: const Icon(Icons.today),
            ),
          IconButton(tooltip: 'Día anterior', onPressed: () => _go(-1), icon: const Icon(Icons.chevron_left)),
          IconButton(tooltip: 'Día siguiente', onPressed: () => _go(1), icon: const Icon(Icons.chevron_right)),
          if (_isTab)
            PopupMenuButton<String>(
              onSelected: (v) => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => v == 'trackers' ? const TrackersPage() : const BackupPage())),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'trackers', child: Text('Mis hábitos y trackers')),
                PopupMenuItem(value: 'backup', child: Text('Copia de seguridad')),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo evento',
        onPressed: () => showEventForm(context, date: _date),
        child: const Icon(Icons.add),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() > 300) _go(v < 0 ? 1 : -1);
        },
        child: body((d) {
          final (day, categories, lists) = d;
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              if (!isToday)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(longDate(_date), style: Theme.of(context).textTheme.titleSmall),
                ),
              JournalCard(key: ValueKey('j${day.date}'), date: day.date, entry: day.journal),
              _EventsCard(day: day, categories: categories, date: _date),
              if (day.dueItems.isNotEmpty) _DueItemsCard(items: day.dueItems, lists: lists),
              _TrackersCard(day: day),
              PeriodCard(key: ValueKey('p${day.date}'), date: day.date, period: day.period),
            ],
          );
        }),
      ),
    );
  }
}

// ---------- Mood & diary ----------

class JournalCard extends StatefulWidget {
  final String date;
  final JournalEntry? entry;
  const JournalCard({super.key, required this.date, this.entry});

  @override
  State<JournalCard> createState() => _JournalCardState();
}

class _JournalCardState extends State<JournalCard> {
  late int _mood = widget.entry?.mood ?? 0;
  late List<String> _feelings = [...?widget.entry?.feelings];
  late final _note = TextEditingController(text: widget.entry?.note);
  Timer? _debounce;
  bool _expanded = false;

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
      await store.saveJournal(JournalEntry(date: widget.date, mood: _mood, feelings: _feelings, note: _note.text));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _saveSoon() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 900), _save);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SectionCard(
      title: '¿Cómo te sentís?',
      icon: Icons.favorite_border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var m = 1; m <= 5; m++)
                Tooltip(
                  message: moodLabel[m],
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      setState(() => _mood = _mood == m ? 0 : m);
                      _save();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _mood == m ? scheme.primaryContainer : Colors.transparent,
                      ),
                      child: Opacity(
                        opacity: _mood == 0 || _mood == m ? 1 : 0.4,
                        child: Text(moodEmoji[m], style: const TextStyle(fontSize: 30)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (_mood > 0 || _feelings.isNotEmpty || _expanded) ...[
            const SizedBox(height: 8),
            TagPicker(
              options: feelingOptions,
              selected: _feelings,
              onChanged: (v) {
                setState(() => _feelings = v);
                _save();
              },
            ),
          ] else
            TextButton(onPressed: () => setState(() => _expanded = true), child: const Text('Agregar emociones')),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _saveSoon(),
            decoration: const InputDecoration(
              hintText: 'Querido diario...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
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
      icon: Icons.event_note,
      trailing: IconButton(
        tooltip: 'Agregar',
        onPressed: () => showEventForm(context, date: date),
        icon: const Icon(Icons.add),
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
    final color = category == null ? Theme.of(context).colorScheme.outline : hexColor(category!.color);
    final parts = [
      if (showDate) shortDate(event.date),
      if (event.time.isNotEmpty) event.time,
      if (category != null) category!.name,
    ];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.18),
        child: Icon(iconFor(category?.icon ?? 'event'), size: 18, color: color),
      ),
      title: Text(event.title, style: event.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
      subtitle: parts.isEmpty ? null : Text(parts.join(' · ')),
      trailing: Checkbox(
        value: event.done,
        onChanged: (v) => attempt(context, () => store.saveEvent(event.copyWith(done: v))),
      ),
      onTap: () => showEventForm(context, event: event),
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
      icon: Icons.checklist,
      child: Column(
        children: [
          for (final i in items)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
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
    return SectionCard(
      title: 'Hábitos',
      icon: Icons.track_changes,
      trailing: IconButton(
        tooltip: 'Gestionar',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrackersPage())),
        icon: const Icon(Icons.tune),
      ),
      child: day.trackers.isEmpty
          ? const EmptyHint('Agregá hábitos o cosas para trackear desde el botón de ajustes.')
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
    final goal = t.goal > 0 ? ' / ${fmtNum(t.goal)}' : '';
    final unit = t.unit.isEmpty ? '' : ' ${t.unit}';

    final Widget trailing = switch (t.kind) {
      'check' => Checkbox(
        value: (v ?? 0) > 0,
        activeColor: color,
        onChanged: (on) => _set(context, on == true ? 1 : null),
      ),
      'count' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: (v ?? 0) <= 0 ? null : () => _set(context, v! - 1 <= 0 ? null : v - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text('${fmtNum(v ?? 0)}$goal'),
          IconButton(
            visualDensity: VisualDensity.compact,
            color: color,
            onPressed: () => _set(context, (v ?? 0) + 1),
            icon: const Icon(Icons.add_circle),
          ),
        ],
      ),
      'scale' => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            InkWell(
              onTap: () => _set(context, v == i ? null : i.toDouble()),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(i <= (v ?? 0) ? Icons.circle : Icons.circle_outlined, size: 18, color: color),
              ),
            ),
        ],
      ),
      _ => TextButton(onPressed: () => _askNumber(context), child: Text(v == null ? 'Anotar' : '${fmtNum(v)}$unit')),
    };

    final progress = t.goal > 0 && (t.kind == 'count' || t.kind == 'number')
        ? ((v ?? 0) / t.goal).clamp(0.0, 1.0)
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(iconFor(t.icon), color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name),
                if (progress != null) ...[
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progress,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.15),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

// ---------- Period ----------

class PeriodCard extends StatefulWidget {
  final String date;
  final PeriodDay? period;
  const PeriodCard({super.key, required this.date, this.period});

  @override
  State<PeriodCard> createState() => _PeriodCardState();
}

class _PeriodCardState extends State<PeriodCard> {
  late int _flow = widget.period?.flow ?? 0;
  late List<String> _symptoms = [...?widget.period?.symptoms];

  Future<void> _save() => attempt(context, () async {
    if (_flow == 0) {
      await store.deletePeriod(widget.date);
    } else {
      await store.savePeriod(
        PeriodDay(date: widget.date, flow: _flow, symptoms: _symptoms, note: widget.period?.note ?? ''),
      );
    }
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Menstruación',
      icon: Icons.water_drop_outlined,
      color: periodColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            children: [
              for (var f = 0; f < flowLabel.length; f++)
                ChoiceChip(
                  showCheckmark: false,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // One outlined drop for spotting, then 1-3 filled drops.
                      for (var i = 0; i < (f <= 1 ? f : f - 1); i++)
                        Icon(f == 1 ? Icons.water_drop_outlined : Icons.water_drop, size: 13, color: periodColor),
                      if (f > 0) const SizedBox(width: 4),
                      Text(flowLabel[f]),
                    ],
                  ),
                  selected: _flow == f,
                  selectedColor: periodColor.withValues(alpha: 0.25),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) {
                    setState(() => _flow = f);
                    _save();
                  },
                ),
            ],
          ),
          if (_flow > 0) ...[
            const SizedBox(height: 8),
            Text('Síntomas', style: Theme.of(context).textTheme.labelLarge),
            TagPicker(
              options: symptomOptions,
              selected: _symptoms,
              color: periodColor,
              onChanged: (v) {
                setState(() => _symptoms = v);
                _save();
              },
            ),
          ],
        ],
      ),
    );
  }
}
