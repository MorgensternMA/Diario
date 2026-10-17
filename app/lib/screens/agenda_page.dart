import 'package:flutter/material.dart';

import '../data/store.dart';
import '../common.dart';
import '../models.dart';
import 'day_page.dart';
import 'event_form.dart';

typedef _AgendaData = (List<Event>, List<Category>);

/// Upcoming events, filterable by section (exams, medical, social...).
class AgendaPage extends StatefulWidget {
  const AgendaPage({super.key});

  @override
  State<AgendaPage> createState() => _AgendaPageState();
}

class _AgendaPageState extends State<AgendaPage> with Loader<AgendaPage, _AgendaData> {
  int? _categoryId;
  bool _history = false;

  @override
  Future<_AgendaData> fetch() => (
    _history
        ? store.events(categoryId: _categoryId)
        : store.events(from: ymd(today()), categoryId: _categoryId, pending: true),
    store.categories(),
  ).wait;

  void _setFilter(VoidCallback f) {
    setState(f);
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(
            tooltip: _history ? 'Ver próximos' : 'Ver todo (incluye pasados y hechos)',
            isSelected: _history,
            onPressed: () => _setFilter(() => _history = !_history),
            icon: const Icon(Icons.history_rounded),
          ),
          IconButton(
            tooltip: 'Secciones',
            onPressed: () => showCategoryManager(context),
            icon: const Icon(Icons.folder_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nuevo evento',
        onPressed: () => showEventForm(context, categoryId: _categoryId),
        child: const Icon(Icons.add_rounded),
      ),
      body: body((d) {
        final (events, categories) = d;
        final byId = {for (final c in categories) c.id: c};
        // History is shown newest first; upcoming soonest first.
        final list = _history ? events.reversed.toList() : events;
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: const Text('Todas'),
                      selected: _categoryId == null,
                      onSelected: (_) => _setFilter(() => _categoryId = null),
                    ),
                  ),
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: Icon(iconFor(c.icon), size: 16, color: hexColor(c.color)),
                        label: Text(c.name),
                        selected: _categoryId == c.id,
                        selectedColor: hexColor(c.color).withValues(alpha: 0.25),
                        onSelected: (_) => _setFilter(() => _categoryId = c.id),
                      ),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Sección'),
                    onPressed: () => editCategory(context),
                  ),
                ],
              ),
            ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: EmptyHint(_history ? 'No hay eventos' : 'No tenés nada pendiente 🎉')),
              ),
            for (var i = 0; i < list.length; i++) ...[
              if (i == 0 || list[i].date != list[i - 1].date) _dateHeader(context, list[i].date),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: EventTile(event: list[i], category: byId[list[i].categoryId]),
              ),
            ],
          ],
        );
      }),
    );
  }

  Widget _dateHeader(BuildContext context, String date) {
    final d = parseYmd(date);
    final days = d.difference(today()).inDays;
    final hint = days > 1 ? 'en $days días' : '';
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DayPage(date: d))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
        child: Row(
          children: [
            Text(
              relativeDate(d),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
            const Spacer(),
            Text(hint, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
