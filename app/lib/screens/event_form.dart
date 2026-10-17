import 'package:flutter/material.dart';

import '../data/store.dart';
import '../common.dart';
import '../models.dart';

/// Opens the create/edit form for an event. [date] pre-fills new events.
Future<void> showEventForm(BuildContext context, {Event? event, DateTime? date, int? categoryId}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => EventForm(event: event, date: date, categoryId: categoryId),
    ),
  );
}

class EventForm extends StatefulWidget {
  final Event? event;
  final DateTime? date;
  final int? categoryId;
  const EventForm({super.key, this.event, this.date, this.categoryId});

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  late final _title = TextEditingController(text: widget.event?.title);
  late final _notes = TextEditingController(text: widget.event?.notes);
  late DateTime _date = widget.event != null ? parseYmd(widget.event!.date) : (widget.date ?? today());
  late String _time = widget.event?.time ?? '';
  late int? _categoryId = widget.event?.categoryId ?? widget.categoryId;
  late bool _done = widget.event?.done ?? false;
  List<Category> _categories = [];
  bool _saving = false;

  bool get _editing => widget.event != null;

  @override
  void initState() {
    super.initState();
    store
        .categories()
        .then((c) {
          if (mounted) setState(() => _categories = c);
        })
        .catchError((e) {
          if (mounted) showError(context, e);
        });
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final parts = _time.split(':');
    final initial = _time.isEmpty
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final t = await showTimePicker(context: context, initialTime: initial);
    if (t != null) {
      setState(() => _time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showError(context, 'Poné un título');
      return;
    }
    setState(() => _saving = true);
    final ok = await attempt(
      context,
      () => store.saveEvent(
        Event(
          id: widget.event?.id ?? 0,
          categoryId: _categoryId,
          title: _title.text.trim(),
          date: ymd(_date),
          time: _time,
          notes: _notes.text.trim(),
          done: _done,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirm(context, '¿Eliminar "${widget.event!.title}"?')) return;
    if (!mounted) return;
    if (await attempt(context, () => store.deleteEvent(widget.event!.id)) && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar evento' : 'Nuevo evento'),
        actions: [
          if (_editing) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline)),
          TextButton(onPressed: _saving ? null : _save, child: const Text('Guardar')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Text('Sección', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('Ninguna'),
                selected: _categoryId == null,
                onSelected: (_) => setState(() => _categoryId = null),
              ),
              for (final c in _categories)
                ChoiceChip(
                  avatar: Icon(iconFor(c.icon), size: 16, color: hexColor(c.color)),
                  label: Text(c.name),
                  selected: _categoryId == c.id,
                  selectedColor: hexColor(c.color).withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _categoryId = c.id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: Text(longDate(_date)),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(_time.isEmpty ? 'Sin hora' : _time),
            trailing: _time.isEmpty
                ? null
                : IconButton(onPressed: () => setState(() => _time = ''), icon: const Icon(Icons.close)),
            onTap: _pickTime,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notas',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          if (_editing)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hecho'),
              value: _done,
              onChanged: (v) => setState(() => _done = v),
            ),
        ],
      ),
    );
  }
}

/// Sheet to create, edit and delete agenda sections (categories).
Future<void> showCategoryManager(BuildContext context) {
  return Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoryManager()));
}

class CategoryManager extends StatefulWidget {
  const CategoryManager({super.key});

  @override
  State<CategoryManager> createState() => _CategoryManagerState();
}

class _CategoryManagerState extends State<CategoryManager> with Loader<CategoryManager, List<Category>> {
  @override
  Future<List<Category>> fetch() => store.categories();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secciones de la agenda')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editCategory(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva sección'),
      ),
      body: body(
        (cats) => ListView(
          children: [
            for (final c in cats)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: hexColor(c.color).withValues(alpha: 0.2),
                  child: Icon(iconFor(c.icon), color: hexColor(c.color)),
                ),
                title: Text(c.name),
                onTap: () => editCategory(context, c),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirm(context, '¿Eliminar la sección "${c.name}"? Sus eventos quedan sin sección.') &&
                        context.mounted) {
                      await attempt(context, () => store.deleteCategory(c.id));
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> editCategory(BuildContext context, [Category? c]) async {
  final name = TextEditingController(text: c?.name);
  var color = c?.color ?? palette[3];
  var icon = c?.icon ?? 'event';
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(c == null ? 'Nueva sección' : 'Editar sección'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                autofocus: c == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre (ej: Exámenes, Cumpleaños)'),
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
  if (saved != true || !context.mounted) return;
  await attempt(context, () => store.saveCategory(Category(id: c?.id ?? 0, name: name.text, color: color, icon: icon)));
}
