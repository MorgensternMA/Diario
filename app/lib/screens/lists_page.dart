import 'package:flutter/material.dart';

import '../data/store.dart';
import '../common.dart';
import '../models.dart';

const _kindLabel = {
  'todo': 'To-do',
  'groceries': 'Compras de comida',
  'purchases': 'Compras importantes',
  'custom': 'Otra',
};

/// Overview of every list: to-dos, groceries, important purchases, custom.
class ListsPage extends StatefulWidget {
  const ListsPage({super.key});

  @override
  State<ListsPage> createState() => _ListsPageState();
}

class _ListsPageState extends State<ListsPage> with Loader<ListsPage, List<TodoList>> {
  @override
  Future<List<TodoList>> fetch() => store.lists();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final l = await editList(context);
          if (l != null && context.mounted) _open(context, l);
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva lista'),
      ),
      body: body(
        (lists) => ListView(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 88),
          children: [
            if (lists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: EmptyHint('Creá tu primera lista')),
              ),
            for (final l in lists)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: hexColor(l.color).withValues(alpha: 0.2),
                    child: Icon(iconFor(l.icon), color: hexColor(l.color)),
                  ),
                  title: Text(l.name),
                  subtitle: Text(
                    l.total == 0
                        ? 'Vacía'
                        : l.pending == 0
                        ? 'Todo listo ✓'
                        : '${l.pending} pendiente${l.pending == 1 ? '' : 's'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _open(context, l),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, TodoList l) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListDetailPage(list: l)));
}

Future<TodoList?> editList(BuildContext context, [TodoList? l]) async {
  final name = TextEditingController(text: l?.name);
  var kind = l?.kind ?? 'todo';
  var color = l?.color ?? palette[7];
  var icon = l?.icon ?? 'list';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l == null ? 'Nueva lista' : 'Editar lista'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                autofocus: l == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [for (final e in _kindLabel.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => kind = v ?? kind),
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
  if (ok != true || !context.mounted) return null;
  try {
    return await store.saveList(
      TodoList(id: l?.id ?? 0, name: name.text, kind: kind, icon: icon, color: color, position: l?.position ?? 0),
    );
  } catch (e) {
    if (context.mounted) showError(context, e);
    return null;
  }
}

class ListDetailPage extends StatefulWidget {
  final TodoList list;
  const ListDetailPage({super.key, required this.list});

  @override
  State<ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<ListDetailPage> with Loader<ListDetailPage, List<Item>> {
  late TodoList _list = widget.list;
  final _text = TextEditingController();
  final _qty = TextEditingController();
  final _focus = FocusNode();

  @override
  Future<List<Item>> fetch() => store.items(_list.id);

  @override
  void dispose() {
    _text.dispose();
    _qty.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    final ok = await attempt(context, () => store.saveItem(_list.id, Item(text: text, quantity: _qty.text.trim())));
    if (ok) {
      _text.clear();
      _qty.clear();
      _focus.requestFocus();
    }
  }

  Future<void> _menu(String action) async {
    switch (action) {
      case 'edit':
        final l = await editList(context, _list);
        if (l != null) setState(() => _list = l);
      case 'clear':
        await attempt(context, () => store.clearDone(_list.id));
      case 'delete':
        if (await confirm(context, '¿Eliminar la lista "${_list.name}" y todos sus ítems?') && mounted) {
          if (await attempt(context, () => store.deleteList(_list.id)) && mounted) Navigator.pop(context);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = hexColor(_list.color);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(iconFor(_list.icon), color: color),
            const SizedBox(width: 8),
            Flexible(child: Text(_list.name)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear', child: Text('Borrar los tachados')),
              PopupMenuItem(value: 'edit', child: Text('Editar lista')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar lista')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _text,
                    focusNode: _focus,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(
                      hintText: _list.kind == 'groceries' ? 'Agregar (ej: leche)' : 'Agregar...',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                if (_list.hasQuantity) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _qty,
                      onSubmitted: (_) => _add(),
                      decoration: const InputDecoration(hintText: 'Cant.', border: OutlineInputBorder(), isDense: true),
                    ),
                  ),
                ],
                IconButton(onPressed: _add, color: color, icon: const Icon(Icons.add_circle, size: 32)),
              ],
            ),
          ),
          Expanded(
            child: body(
              (items) => ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: EmptyHint('Lista vacía')),
                    ),
                  for (final i in items) _itemTile(context, i, color),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemTile(BuildContext context, Item i, Color color) {
    final sub = [
      if (i.quantity.isNotEmpty) i.quantity,
      if (i.dueDate.isNotEmpty) 'para ${relativeDate(parseYmd(i.dueDate)).toLowerCase()}',
      if (i.note.isNotEmpty) i.note,
    ];
    return Dismissible(
      key: ValueKey(i.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) {
        setState(() => data = data!.where((x) => x.id != i.id).toList());
        attempt(context, () => store.deleteItem(i.id));
      },
      child: CheckboxListTile(
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: color,
        value: i.done,
        title: Text(
          i.text,
          style: i.done
              ? TextStyle(decoration: TextDecoration.lineThrough, color: Theme.of(context).colorScheme.outline)
              : null,
        ),
        subtitle: sub.isEmpty ? null : Text(sub.join(' · ')),
        secondary: IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _editItem(i)),
        onChanged: (v) => attempt(context, () => store.saveItem(_list.id, i.copyWith(done: v))),
      ),
    );
  }

  Future<void> _editItem(Item i) async {
    final text = TextEditingController(text: i.text);
    final qty = TextEditingController(text: i.quantity);
    final note = TextEditingController(text: i.note);
    var due = i.dueDate;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Editar'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: text,
                  decoration: const InputDecoration(labelText: 'Texto'),
                ),
                TextField(
                  controller: qty,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Nota'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(due.isEmpty ? 'Sin fecha límite' : 'Para el ${shortDate(due)}'),
                  subtitle: due.isEmpty ? const Text('Aparece en el día elegido') : null,
                  trailing: due.isEmpty
                      ? null
                      : IconButton(onPressed: () => setState(() => due = ''), icon: const Icon(Icons.close)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: due.isEmpty ? today() : parseYmd(due),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setState(() => due = ymd(d));
                  },
                ),
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
    if (ok != true || !mounted) return;
    await attempt(
      context,
      () => store.saveItem(
        _list.id,
        Item(
          id: i.id,
          listId: i.listId,
          text: text.text,
          done: i.done,
          quantity: qty.text.trim(),
          note: note.text.trim(),
          dueDate: due,
          position: i.position,
        ),
      ),
    );
  }
}
