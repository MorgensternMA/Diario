import 'package:flutter/material.dart';

import '../common.dart';
import '../data/store.dart';
import '../models.dart';
import '../theme.dart';
import 'agenda_page.dart';
import 'backup_page.dart';
import 'cycle_page.dart';
import 'day_page.dart';
import 'food_page.dart';
import 'lists_page.dart';
import 'period_editor.dart';
import 'trackers_page.dart';

typedef _BagData = (List<Event>, List<TodoList>, Day, CycleSummary, List<JournalEntry>);

/// "Mi bolso": every compartment of the app, each with a live summary.
class BagPage extends StatefulWidget {
  const BagPage({super.key});

  @override
  State<BagPage> createState() => _BagPageState();
}

class _BagPageState extends State<BagPage> with Loader<BagPage, _BagData> {
  @override
  Future<_BagData> fetch() => (
    store.events(from: ymd(today()), pending: true),
    store.lists(),
    store.day(ymd(today())),
    store.cycleSummary(),
    store.journalEntries(),
  ).wait;

  void _open(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: body((d) {
          final (events, lists, day, cycle, journal) = d;
          final pending = lists.fold(0, (s, l) => s + l.pending);
          final habitsDone = day.trackers.where((t) => t.tracker.isDone(t.value)).length;
          final pockets = [
            _Pocket(
              'Agenda',
              Icons.event_note_rounded,
              Palette.agenda,
              events.isEmpty ? 'Nada pendiente' : '${events.length} próximo${events.length == 1 ? '' : 's'}',
              () => _open(const AgendaPage()),
            ),
            _Pocket(
              'Listas',
              Icons.checklist_rounded,
              Palette.lists,
              pending == 0 ? 'Todo listo' : '$pending pendiente${pending == 1 ? '' : 's'}',
              () => _open(const ListsPage()),
            ),
            _Pocket(
              'Comidas',
              Icons.restaurant_rounded,
              Palette.food,
              day.food.isEmpty ? 'Nada anotado hoy' : '${kcal(day.calories)} · ${grams(day.protein)} prot.',
              () => _open(FoodPage(date: today())),
            ),
            _Pocket(
              'Hábitos',
              Icons.track_changes_rounded,
              Palette.habits,
              day.trackers.isEmpty ? 'Creá el primero' : '$habitsDone de ${day.trackers.length} hoy',
              () => _open(const TrackersPage()),
            ),
            _Pocket(
              'Mi diario',
              Icons.auto_stories_rounded,
              Palette.journal,
              journal.isEmpty ? 'Empezá hoy' : '${journal.length} día${journal.length == 1 ? '' : 's'} escritos',
              () => _open(const JournalPage()),
            ),
            _Pocket(
              'Ciclo',
              Icons.water_drop_rounded,
              Palette.cycle,
              cycleStatus(cycle),
              () => _open(const CyclePage()),
            ),
          ];
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const PageHeader(subtitle: 'Todo lo tuyo, en un solo lugar', title: 'Mi bolso'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.08,
                  children: pockets,
                ),
              ),
              const SizedBox(height: 12),
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const IconBubble(Icons.tune_rounded, Palette.backup, size: 34),
                      title: const Text('Personalizar Hoy'),
                      subtitle: const Text('Elegí qué ver en tu día'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _open(const CustomizePage()),
                    ),
                    const Divider(height: 1, indent: 66),
                    ListTile(
                      leading: const IconBubble(Icons.cloud_upload_rounded, Palette.backup, size: 34),
                      title: const Text('Copia de seguridad'),
                      subtitle: const Text('Guardá o restaurá tus datos'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _open(const BackupPage()),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _Pocket extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final String summary;
  final VoidCallback onTap;
  const _Pocket(this.name, this.icon, this.color, this.summary, this.onTap);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: Tokens.of(context).card, borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Tokens.of(context).muted, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every day with a mood, levels or a note, newest first.
class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> with Loader<JournalPage, List<JournalEntry>> {
  @override
  Future<List<JournalEntry>> fetch() => store.journalEntries();

  @override
  Widget build(BuildContext context) {
    final muted = Tokens.of(context).muted;
    return Scaffold(
      appBar: AppBar(title: const Text('Mi diario')),
      body: body(
        (entries) => ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: EmptyHint('Lo que escribas en "Hoy" va a aparecer acá.')),
              ),
            for (final j in entries)
              SoftCard(
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DayPage(date: parseYmd(j.date)))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(relativeDate(parseYmd(j.date)), style: Theme.of(context).textTheme.titleLarge),
                        ),
                        if (j.mood > 0) Text(moodEmoji[j.mood], style: const TextStyle(fontSize: 24)),
                      ],
                    ),
                    if (j.energy + j.motivation + j.hunger > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          [
                            if (j.energy > 0) 'Energía ${j.energy}/5',
                            if (j.motivation > 0) 'Ganas ${j.motivation}/5',
                            if (j.hunger > 0) 'Hambre ${j.hunger}/5',
                          ].join(' · '),
                          style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    if (j.feelings.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final f in j.feelings)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Palette.journal.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(f, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      ),
                    if (j.note.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          j.note.trim(),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(height: 1.4),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Toggles for the sections shown in "Hoy".
class CustomizePage extends StatefulWidget {
  const CustomizePage({super.key});

  @override
  State<CustomizePage> createState() => _CustomizePageState();
}

class _CustomizePageState extends State<CustomizePage> with Loader<CustomizePage, Set<String>> {
  static const _sections = [
    ('mood', '¿Cómo estás?', 'Ánimo, energía, ganas, hambre y diario', Icons.favorite_rounded, Palette.journal),
    ('agenda', 'Agenda', 'Eventos del día', Icons.event_note_rounded, Palette.agenda),
    ('food', 'Comidas', 'Calorías del día', Icons.restaurant_rounded, Palette.food),
    ('meds', 'Remedios', 'Lo que tomaste', Icons.medication_rounded, Palette.cycle),
    ('habits', 'Hábitos', 'Tus trackers', Icons.track_changes_rounded, Palette.habits),
    ('cycle', 'Ciclo', 'Registro rápido y avisos del ciclo', Icons.water_drop_rounded, periodColor),
  ];

  @override
  Future<Set<String>> fetch() => store.hiddenSections();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personalizar Hoy')),
      body: body(
        (hidden) => ListView(
          children: [
            SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  for (final s in _sections)
                    SwitchListTile(
                      secondary: IconBubble(s.$4, s.$5, size: 34),
                      title: Text(s.$2),
                      subtitle: Text(s.$3),
                      value: !hidden.contains(s.$1),
                      onChanged: (on) => attempt(
                        context,
                        () => store.setHiddenSections(on ? ({...hidden}..remove(s.$1)) : {...hidden, s.$1}),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
