import 'package:flutter/material.dart';

import '../data/store.dart';
import '../common.dart';
import '../models.dart';

const _kindLabel = {
  'check': 'Sí / no (ej: hice ejercicio)',
  'count': 'Contador (ej: vasos de agua)',
  'number': 'Número (ej: horas de sueño, peso)',
  'scale': 'Escala 1 a 5 (ej: energía, dolor)',
};

/// Create, edit, archive and review habits and other trackers.
class TrackersPage extends StatefulWidget {
  const TrackersPage({super.key});

  @override
  State<TrackersPage> createState() => _TrackersPageState();
}

class _TrackersPageState extends State<TrackersPage> with Loader<TrackersPage, List<Tracker>> {
  @override
  Future<List<Tracker>> fetch() => store.trackers(archived: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hábitos y trackers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editTracker(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: body((trackers) {
        final active = trackers.where((t) => !t.archived).toList();
        final archived = trackers.where((t) => t.archived).toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            if (trackers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: EmptyHint('Todavía no hay trackers')),
              ),
            for (final t in active) _tile(context, t),
            if (archived.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('Archivados')),
              for (final t in archived) _tile(context, t),
            ],
          ],
        );
      }),
    );
  }

  Widget _tile(BuildContext context, Tracker t) {
    final color = hexColor(t.color);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.2),
        child: Icon(iconFor(t.icon), color: color),
      ),
      title: Text(t.name),
      subtitle: Text(_kindLabel[t.kind]!.split(' (').first + (t.goal > 0 ? ' · meta ${fmtNum(t.goal)} ${t.unit}' : '')),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrackerHistoryPage(tracker: t))),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          switch (v) {
            case 'edit':
              await editTracker(context, t);
            case 'archive':
              await attempt(context, () => store.saveTracker(_copy(t, archived: !t.archived)));
            case 'delete':
              if (await confirm(context, '¿Eliminar "${t.name}" y todo su historial?') && context.mounted) {
                await attempt(context, () => store.deleteTracker(t.id));
              }
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Editar')),
          PopupMenuItem(value: 'archive', child: Text(t.archived ? 'Reactivar' : 'Archivar')),
          const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
        ],
      ),
    );
  }
}

Tracker _copy(Tracker t, {bool? archived}) => Tracker(
  id: t.id,
  name: t.name,
  kind: t.kind,
  unit: t.unit,
  goal: t.goal,
  color: t.color,
  icon: t.icon,
  archived: archived ?? t.archived,
  position: t.position,
);

Future<void> editTracker(BuildContext context, [Tracker? t]) async {
  final name = TextEditingController(text: t?.name);
  final unit = TextEditingController(text: t?.unit);
  final goal = TextEditingController(text: (t?.goal ?? 0) > 0 ? fmtNum(t!.goal) : '');
  var kind = t?.kind ?? 'check';
  var color = t?.color ?? palette[5];
  var icon = t?.icon ?? 'check';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(t == null ? 'Nuevo tracker' : 'Editar tracker'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                autofocus: t == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre (ej: Meditar, Vitaminas)'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: kind,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [for (final e in _kindLabel.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => kind = v ?? kind),
              ),
              if (kind == 'count' || kind == 'number')
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: goal,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Meta diaria (opcional)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: unit,
                        decoration: const InputDecoration(labelText: 'Unidad'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              ColorPicker(value: color, onChanged: (v) => setState(() => color = v)),
              const SizedBox(height: 12),
              IconPicker(value: icon, color: color, onChanged: (v) => setState(() => icon = v)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final hasGoal = kind == 'count' || kind == 'number';
  await attempt(
    context,
    () => store.saveTracker(
      Tracker(
        id: t?.id ?? 0,
        name: name.text,
        kind: kind,
        unit: hasGoal ? unit.text.trim() : '',
        goal: hasGoal ? double.tryParse(goal.text.replaceAll(',', '.')) ?? 0 : 0,
        color: color,
        icon: icon,
        archived: t?.archived ?? false,
        position: t?.position ?? 0,
      ),
    ),
  );
}

/// Last 12 weeks of a tracker as a grid, plus streak and average.
class TrackerHistoryPage extends StatefulWidget {
  final Tracker tracker;
  const TrackerHistoryPage({super.key, required this.tracker});

  @override
  State<TrackerHistoryPage> createState() => _TrackerHistoryPageState();
}

class _TrackerHistoryPageState extends State<TrackerHistoryPage> with Loader<TrackerHistoryPage, Map<String, double>> {
  static const _weeks = 12;
  Tracker get t => widget.tracker;

  DateTime get _start {
    final now = today();
    // Monday of the week, (_weeks - 1) weeks back.
    return DateTime(now.year, now.month, now.day - (now.weekday - 1) - 7 * (_weeks - 1));
  }

  @override
  Future<Map<String, double>> fetch() async {
    final entries = await store.entries(t.id, from: ymd(_start), to: ymd(today()));
    return {for (final e in entries) e.date: e.value};
  }

  @override
  Widget build(BuildContext context) {
    final color = hexColor(t.color);
    return Scaffold(
      appBar: AppBar(title: Text(t.name)),
      body: body((values) {
        // Current streak, counting back from today (or yesterday if today is not logged yet).
        var streak = 0;
        var d = today();
        if (!t.isDone(values[ymd(d)])) d = d.subtract(const Duration(days: 1));
        while (t.isDone(values[ymd(d)])) {
          streak++;
          d = DateTime(d.year, d.month, d.day - 1);
        }
        final done = values.values.where((v) => t.isDone(v)).length;
        final avg = values.isEmpty ? 0.0 : values.values.reduce((a, b) => a + b) / values.length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                _stat(context, '$streak', 'racha actual'),
                _stat(context, '$done', 'días cumplidos'),
                if (t.kind != 'check') _stat(context, fmtNum(avg), 'promedio ${t.unit}'.trim()),
              ],
            ),
            const SizedBox(height: 24),
            Text('Últimas $_weeks semanas', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    for (final n in ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                      SizedBox(
                        height: 22,
                        child: Center(child: Text(n, style: Theme.of(context).textTheme.labelSmall)),
                      ),
                  ],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Row(
                    children: [
                      for (var w = 0; w < _weeks; w++)
                        Expanded(
                          child: Column(
                            children: [
                              for (var wd = 0; wd < 7; wd++)
                                _cell(
                                  context,
                                  DateTime(_start.year, _start.month, _start.day + w * 7 + wd),
                                  values,
                                  color,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    );
  }

  Widget _cell(BuildContext context, DateTime date, Map<String, double> values, Color color) {
    final v = values[ymd(date)];
    final future = date.isAfter(today());
    double alpha;
    if (v == null) {
      alpha = 0;
    } else if (t.kind == 'scale') {
      alpha = v / 5;
    } else if (t.goal > 0) {
      alpha = (v / t.goal).clamp(0.15, 1.0);
    } else {
      alpha = 1;
    }
    return Tooltip(
      message: '${shortDate(ymd(date))}${v == null ? '' : ': ${fmtNum(v)} ${t.unit}'}',
      child: Container(
        height: 18,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: future
              ? Colors.transparent
              : v == null
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : color.withValues(alpha: alpha),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) => Expanded(
    child: Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}
