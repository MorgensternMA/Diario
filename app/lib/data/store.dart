import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models.dart';
import 'cycles.dart';

class StoreException implements Exception {
  final String message;
  StoreException(this.message);

  @override
  String toString() => message;
}

/// Notifies screens that data changed somewhere so they can reload.
class DataBus extends ChangeNotifier {
  void bump() => notifyListeners();
}

final bus = DataBus();

late Store store;

const _schema = [
  '''CREATE TABLE categories (
    id    INTEGER PRIMARY KEY,
    name  TEXT NOT NULL,
    color TEXT NOT NULL,
    icon  TEXT NOT NULL
  )''',
  '''CREATE TABLE events (
    id          INTEGER PRIMARY KEY,
    category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    title       TEXT NOT NULL,
    date        TEXT NOT NULL,
    time        TEXT NOT NULL DEFAULT '',
    notes       TEXT NOT NULL DEFAULT '',
    done        INTEGER NOT NULL DEFAULT 0
  )''',
  'CREATE INDEX events_date ON events(date)',
  '''CREATE TABLE lists (
    id       INTEGER PRIMARY KEY,
    name     TEXT NOT NULL,
    kind     TEXT NOT NULL,
    icon     TEXT NOT NULL,
    color    TEXT NOT NULL,
    position INTEGER NOT NULL DEFAULT 0
  )''',
  '''CREATE TABLE list_items (
    id       INTEGER PRIMARY KEY,
    list_id  INTEGER NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
    text     TEXT NOT NULL,
    done     INTEGER NOT NULL DEFAULT 0,
    quantity TEXT NOT NULL DEFAULT '',
    note     TEXT NOT NULL DEFAULT '',
    due_date TEXT NOT NULL DEFAULT '',
    position INTEGER NOT NULL DEFAULT 0
  )''',
  'CREATE INDEX list_items_list ON list_items(list_id)',
  'CREATE INDEX list_items_due ON list_items(due_date)',
  '''CREATE TABLE journal (
    date     TEXT PRIMARY KEY,
    mood     INTEGER NOT NULL DEFAULT 0,
    feelings TEXT NOT NULL DEFAULT '[]',
    note     TEXT NOT NULL DEFAULT ''
  )''',
  '''CREATE TABLE period_days (
    date     TEXT PRIMARY KEY,
    flow     INTEGER NOT NULL,
    symptoms TEXT NOT NULL DEFAULT '[]',
    note     TEXT NOT NULL DEFAULT ''
  )''',
  '''CREATE TABLE trackers (
    id       INTEGER PRIMARY KEY,
    name     TEXT NOT NULL,
    kind     TEXT NOT NULL,
    unit     TEXT NOT NULL DEFAULT '',
    goal     REAL NOT NULL DEFAULT 0,
    color    TEXT NOT NULL,
    icon     TEXT NOT NULL,
    archived INTEGER NOT NULL DEFAULT 0,
    position INTEGER NOT NULL DEFAULT 0
  )''',
  '''CREATE TABLE tracker_entries (
    tracker_id INTEGER NOT NULL REFERENCES trackers(id) ON DELETE CASCADE,
    date       TEXT NOT NULL,
    value      REAL NOT NULL,
    PRIMARY KEY (tracker_id, date)
  )''',
];

/// Tables in an order that satisfies foreign keys on insert.
const _tables = [
  'categories',
  'events',
  'lists',
  'list_items',
  'journal',
  'period_days',
  'trackers',
  'tracker_entries',
];

Future<void> _seed(DatabaseExecutor db) async {
  for (final c in [
    ['Exámenes', '#EF5350', 'school'],
    ['Turnos médicos', '#26A69A', 'medical'],
    ['Social', '#FFA726', 'people'],
    ['Trabajo', '#5C6BC0', 'work'],
  ]) {
    await db.insert('categories', {'name': c[0], 'color': c[1], 'icon': c[2]});
  }
  var pos = 0;
  for (final l in [
    ['Pendientes', 'todo', 'check', '#7E57C2'],
    ['Supermercado', 'groceries', 'cart', '#66BB6A'],
    ['Compras importantes', 'purchases', 'bag', '#FFA726'],
  ]) {
    await db.insert('lists', {'name': l[0], 'kind': l[1], 'icon': l[2], 'color': l[3], 'position': ++pos});
  }
  pos = 0;
  for (final t in [
    Tracker(name: 'Agua', kind: 'count', unit: 'vasos', goal: 8, color: '#42A5F5', icon: 'water'),
    Tracker(name: 'Ejercicio', kind: 'check', color: '#66BB6A', icon: 'fitness'),
    Tracker(name: 'Sueño', kind: 'number', unit: 'horas', goal: 8, color: '#7E57C2', icon: 'sleep'),
  ]) {
    await db.insert('trackers', {..._trackerRow(t), 'position': ++pos});
  }
}

String _tags(List<String> t) => jsonEncode(t);
List<String> _untags(Object? s) => (jsonDecode(s as String? ?? '[]') as List).cast<String>();

String _required(String s, String what) {
  final t = s.trim();
  if (t.isEmpty) throw StoreException('Falta $what');
  return t;
}

Map<String, Object?> _trackerRow(Tracker t) => {
  'name': _required(t.name, 'el nombre'),
  'kind': t.kind,
  'unit': t.unit,
  'goal': t.goal,
  'color': t.color,
  'icon': t.icon,
  'archived': t.archived ? 1 : 0,
  'position': t.position,
};

Category _category(Map<String, Object?> r) =>
    Category(id: r['id'] as int, name: r['name'] as String, color: r['color'] as String, icon: r['icon'] as String);

Event _event(Map<String, Object?> r) => Event(
  id: r['id'] as int,
  categoryId: r['category_id'] as int?,
  title: r['title'] as String,
  date: r['date'] as String,
  time: r['time'] as String,
  notes: r['notes'] as String,
  done: r['done'] == 1,
);

Item _item(Map<String, Object?> r) => Item(
  id: r['id'] as int,
  listId: r['list_id'] as int,
  text: r['text'] as String,
  done: r['done'] == 1,
  quantity: r['quantity'] as String,
  note: r['note'] as String,
  dueDate: r['due_date'] as String,
  position: r['position'] as int,
);

Tracker _tracker(Map<String, Object?> r) => Tracker(
  id: r['id'] as int,
  name: r['name'] as String,
  kind: r['kind'] as String,
  unit: r['unit'] as String,
  goal: (r['goal'] as num).toDouble(),
  color: r['color'] as String,
  icon: r['icon'] as String,
  archived: r['archived'] == 1,
  position: r['position'] as int,
);

JournalEntry _journal(Map<String, Object?> r) => JournalEntry(
  date: r['date'] as String,
  mood: r['mood'] as int,
  feelings: _untags(r['feelings']),
  note: r['note'] as String,
);

PeriodDay _period(Map<String, Object?> r) => PeriodDay(
  date: r['date'] as String,
  flow: r['flow'] as int,
  symptoms: _untags(r['symptoms']),
  note: r['note'] as String,
);

/// All app data, stored in a SQLite file on the device.
class Store {
  final Database db;
  Store._(this.db);

  static Future<Store> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path ?? p.join(await f.getDatabasesPath(), 'diario.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          final batch = db.batch();
          for (final s in _schema) {
            batch.execute(s);
          }
          await batch.commit(noResult: true);
          await _seed(db);
        },
      ),
    );
    return Store._(db);
  }

  Future<void> close() => db.close();

  /// Runs a write and notifies listeners.
  Future<T> _mutate<T>(Future<T> f) async {
    final r = await f;
    bus.bump();
    return r;
  }

  // ---------- Day & calendar ----------

  Future<Day> day(String date) async {
    final journal = await db.query('journal', where: 'date = ?', whereArgs: [date]);
    final period = await db.query('period_days', where: 'date = ?', whereArgs: [date]);
    final entries = await db.query('tracker_entries', where: 'date = ?', whereArgs: [date]);
    final values = {for (final e in entries) e['tracker_id'] as int: (e['value'] as num).toDouble()};
    return Day(
      date: date,
      journal: journal.isEmpty ? null : _journal(journal.first),
      period: period.isEmpty ? null : _period(period.first),
      events: await events(from: date, to: date),
      trackers: [for (final t in await trackers()) TrackerDay(t, values[t.id])],
      dueItems: await _itemsDue(date, date),
    );
  }

  /// Markers for every date in [from, to] that has something.
  Future<List<CalendarDay>> calendar(String from, String to) async {
    final days = <String, _CalDay>{};
    _CalDay get(String date) => days.putIfAbsent(date, () => _CalDay(date));

    final evs = await db.rawQuery(
      '''SELECT e.id, e.title, e.date, e.done, COALESCE(c.color, '#9E9E9E') AS color
         FROM events e LEFT JOIN categories c ON c.id = e.category_id
         WHERE e.date >= ? AND e.date <= ? ORDER BY e.date, e.time = '', e.time, e.id''',
      [from, to],
    );
    for (final r in evs) {
      get(
        r['date'] as String,
      ).events.add(CalendarEvent(r['id'] as int, r['title'] as String, r['color'] as String, r['done'] == 1));
    }
    for (final r in await db.query(
      'journal',
      columns: ['date', 'mood'],
      where: 'date >= ? AND date <= ? AND mood > 0',
      whereArgs: [from, to],
    )) {
      get(r['date'] as String).mood = r['mood'] as int;
    }
    for (final it in await _itemsDue(from, to)) {
      get(it.dueDate).dueItems++;
    }

    final allPeriod = await _periodDays();
    for (final pd in allPeriod) {
      if (pd.date.compareTo(from) >= 0 && pd.date.compareTo(to) <= 0) get(pd.date).flow = pd.flow;
    }
    void mark(String a, String b, void Function(_CalDay) f) {
      for (var t = dayOf(a); !t.isAfter(dayOf(b)); t = addDays(t, 1)) {
        final s = fmtDay(t);
        if (s.compareTo(from) >= 0 && s.compareTo(to) <= 0) f(get(s));
      }
    }

    for (final pr in computeCycles(allPeriod, DateTime.now()).predictions) {
      mark(pr.fertileStart, pr.fertileEnd, (d) => d.fertile = true);
      mark(pr.ovulation, pr.ovulation, (d) => d.ovulation = true);
      mark(pr.start, pr.end, (d) => d.predicted = d.flow == 0);
    }

    final keys = days.keys.toList()..sort();
    return [for (final k in keys) days[k]!.build()];
  }

  // ---------- Categories & events ----------

  Future<List<Category>> categories() async => [
    for (final r in await db.query('categories', orderBy: 'name COLLATE NOCASE')) _category(r),
  ];

  Future<void> saveCategory(Category c) => _mutate(() async {
    final row = {'name': _required(c.name, 'el nombre'), 'color': c.color, 'icon': c.icon};
    c.id == 0
        ? await db.insert('categories', row)
        : await db.update('categories', row, where: 'id = ?', whereArgs: [c.id]);
  }());

  Future<void> deleteCategory(int id) => _mutate(db.delete('categories', where: 'id = ?', whereArgs: [id]));

  Future<List<Event>> events({String? from, String? to, int? categoryId, bool pending = false}) async {
    final where = <String>[];
    final args = <Object>[];
    if (from != null) {
      where.add('date >= ?');
      args.add(from);
    }
    if (to != null) {
      where.add('date <= ?');
      args.add(to);
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (pending) where.add('done = 0');
    final rows = await db.query(
      'events',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args,
      orderBy: "date, time = '', time, id",
    );
    return [for (final r in rows) _event(r)];
  }

  Future<void> saveEvent(Event e) => _mutate(() async {
    final row = {
      'category_id': e.categoryId,
      'title': _required(e.title, 'el título'),
      'date': e.date,
      'time': e.time,
      'notes': e.notes,
      'done': e.done ? 1 : 0,
    };
    e.id == 0 ? await db.insert('events', row) : await db.update('events', row, where: 'id = ?', whereArgs: [e.id]);
  }());

  Future<void> deleteEvent(int id) => _mutate(db.delete('events', where: 'id = ?', whereArgs: [id]));

  // ---------- Lists ----------

  Future<List<TodoList>> lists() async {
    final rows = await db.rawQuery('''
      SELECT l.*, COALESCE(SUM(i.done = 0), 0) AS pending, COUNT(i.id) AS total
      FROM lists l LEFT JOIN list_items i ON i.list_id = l.id
      GROUP BY l.id ORDER BY l.position, l.id''');
    return [
      for (final r in rows)
        TodoList(
          id: r['id'] as int,
          name: r['name'] as String,
          kind: r['kind'] as String,
          icon: r['icon'] as String,
          color: r['color'] as String,
          position: r['position'] as int,
          pending: r['pending'] as int,
          total: r['total'] as int,
        ),
    ];
  }

  Future<TodoList> saveList(TodoList l) => _mutate(() async {
    var position = l.position;
    if (l.id == 0 && position == 0) {
      final r = await db.rawQuery('SELECT COALESCE(MAX(position), 0) + 1 AS p FROM lists');
      position = r.first['p'] as int;
    }
    final row = {
      'name': _required(l.name, 'el nombre'),
      'kind': l.kind,
      'icon': l.icon,
      'color': l.color,
      'position': position,
    };
    final id = l.id == 0 ? await db.insert('lists', row) : l.id;
    if (l.id != 0) await db.update('lists', row, where: 'id = ?', whereArgs: [id]);
    return TodoList(
      id: id,
      name: row['name'] as String,
      kind: l.kind,
      icon: l.icon,
      color: l.color,
      position: position,
    );
  }());

  Future<void> deleteList(int id) => _mutate(db.delete('lists', where: 'id = ?', whereArgs: [id]));

  Future<List<Item>> items(int listId) async => [
    for (final r in await db.query(
      'list_items',
      where: 'list_id = ?',
      whereArgs: [listId],
      orderBy: 'done, position, id',
    ))
      _item(r),
  ];

  Future<List<Item>> _itemsDue(String from, String to) async => [
    for (final r in await db.query(
      'list_items',
      where: "due_date != '' AND due_date >= ? AND due_date <= ? AND done = 0",
      whereArgs: [from, to],
      orderBy: 'due_date, id',
    ))
      _item(r),
  ];

  Future<void> saveItem(int listId, Item i) => _mutate(() async {
    final row = {
      'text': _required(i.text, 'el texto'),
      'done': i.done ? 1 : 0,
      'quantity': i.quantity,
      'note': i.note,
      'due_date': i.dueDate,
    };
    if (i.id == 0) {
      final r = await db.rawQuery('SELECT COALESCE(MAX(position), 0) + 1 AS p FROM list_items WHERE list_id = ?', [
        listId,
      ]);
      await db.insert('list_items', {...row, 'list_id': listId, 'position': r.first['p']});
    } else {
      await db.update('list_items', row, where: 'id = ?', whereArgs: [i.id]);
    }
  }());

  Future<void> deleteItem(int id) => _mutate(db.delete('list_items', where: 'id = ?', whereArgs: [id]));

  Future<void> clearDone(int listId) =>
      _mutate(db.delete('list_items', where: 'list_id = ? AND done = 1', whereArgs: [listId]));

  // ---------- Journal ----------

  Future<void> saveJournal(JournalEntry j) => _mutate(
    db.insert('journal', {
      'date': j.date,
      'mood': j.mood,
      'feelings': _tags(j.feelings),
      'note': j.note,
    }, conflictAlgorithm: ConflictAlgorithm.replace),
  );

  // ---------- Period ----------

  Future<List<PeriodDay>> _periodDays() async => [
    for (final r in await db.query('period_days', orderBy: 'date')) _period(r),
  ];

  Future<CycleSummary> cycleSummary() async => computeCycles(await _periodDays(), DateTime.now());

  Future<void> savePeriod(PeriodDay pd) => _mutate(
    db.insert('period_days', {
      'date': pd.date,
      'flow': pd.flow,
      'symptoms': _tags(pd.symptoms),
      'note': pd.note,
    }, conflictAlgorithm: ConflictAlgorithm.replace),
  );

  Future<void> deletePeriod(String date) => _mutate(db.delete('period_days', where: 'date = ?', whereArgs: [date]));

  // ---------- Trackers ----------

  Future<List<Tracker>> trackers({bool archived = false}) async => [
    for (final r in await db.query('trackers', where: archived ? null : 'archived = 0', orderBy: 'position, id'))
      _tracker(r),
  ];

  Future<void> saveTracker(Tracker t) => _mutate(() async {
    final row = _trackerRow(t);
    if (t.id == 0) {
      final r = await db.rawQuery('SELECT COALESCE(MAX(position), 0) + 1 AS p FROM trackers');
      await db.insert('trackers', {...row, 'position': r.first['p']});
    } else {
      await db.update('trackers', row, where: 'id = ?', whereArgs: [t.id]);
    }
  }());

  Future<void> deleteTracker(int id) => _mutate(db.delete('trackers', where: 'id = ?', whereArgs: [id]));

  Future<List<TrackerEntry>> entries(int trackerId, {required String from, required String to}) async => [
    for (final r in await db.query(
      'tracker_entries',
      where: 'tracker_id = ? AND date >= ? AND date <= ?',
      whereArgs: [trackerId, from, to],
      orderBy: 'date',
    ))
      TrackerEntry(r['tracker_id'] as int, r['date'] as String, (r['value'] as num).toDouble()),
  ];

  /// Sets a tracker's value for a day; null removes it.
  Future<void> setEntry(int trackerId, String date, double? value) => _mutate(
    value == null
        ? db.delete('tracker_entries', where: 'tracker_id = ? AND date = ?', whereArgs: [trackerId, date])
        : db.insert('tracker_entries', {
            'tracker_id': trackerId,
            'date': date,
            'value': value,
          }, conflictAlgorithm: ConflictAlgorithm.replace),
  );

  // ---------- Backup ----------

  static const _backupFormat = 'diario-backup';
  static const _backupVersion = 1;

  /// Every table as JSON, to be saved wherever the user wants.
  Future<String> exportJson() async {
    final tables = <String, Object>{};
    for (final t in _tables) {
      tables[t] = await db.query(t);
    }
    return const JsonEncoder.withIndent(' ').convert({
      'format': _backupFormat,
      'version': _backupVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'tables': tables,
    });
  }

  /// Replaces all data with a backup made by [exportJson]. Nothing changes if
  /// the file is invalid.
  Future<void> importJson(String text) => _mutate(() async {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw StoreException('El archivo no es una copia de Diario válida');
    }
    if (data['format'] != _backupFormat || data['tables'] is! Map) {
      throw StoreException('El archivo no es una copia de Diario válida');
    }
    if ((data['version'] as int? ?? 0) > _backupVersion) {
      throw StoreException('La copia es de una versión más nueva de la app');
    }
    final tables = data['tables'] as Map<String, dynamic>;
    await db.transaction((tx) async {
      for (final t in _tables.reversed) {
        await tx.delete(t);
      }
      for (final t in _tables) {
        for (final row in (tables[t] as List? ?? const [])) {
          await tx.insert(t, Map<String, Object?>.from(row as Map));
        }
      }
    });
  }());
}

class _CalDay {
  final String date;
  final events = <CalendarEvent>[];
  int mood = 0, flow = 0, dueItems = 0;
  bool predicted = false, fertile = false, ovulation = false;
  _CalDay(this.date);

  CalendarDay build() => CalendarDay(
    date: date,
    events: events,
    mood: mood,
    flow: flow,
    predictedPeriod: predicted,
    fertile: fertile,
    ovulation: ovulation,
    dueItems: dueItems,
  );
}
