import 'package:diario/data/store.dart';
import 'package:diario/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Store s;

  setUp(() async {
    s = await Store.open(path: inMemoryDatabasePath, factory: databaseFactoryFfiNoIsolate);
  });
  tearDown(() => s.close());

  test('seeds default sections, lists and trackers', () async {
    expect(await s.categories(), hasLength(4));
    expect((await s.lists()).map((l) => l.name), ['Pendientes', 'Supermercado', 'Compras importantes']);
    expect(await s.trackers(), hasLength(3));
  });

  test('day aggregates everything and the calendar marks it', () async {
    final cat = (await s.categories()).firstWhere((c) => c.name == 'Exámenes');
    await s.saveEvent(Event(title: 'Final', date: '2026-10-20', time: '09:30', categoryId: cat.id));
    await s.saveJournal(const JournalEntry(date: '2026-10-20', mood: 4, feelings: ['Feliz'], note: 'hola'));
    await s.savePeriod(const PeriodDay(date: '2026-10-20', flow: 3, symptoms: ['Cólicos']));
    final water = (await s.trackers()).first;
    await s.setEntry(water.id, '2026-10-20', 6);
    final purchases = (await s.lists()).last;
    await s.saveItem(purchases.id, const Item(text: 'Cubiertos', dueDate: '2026-10-20'));

    final day = await s.day('2026-10-20');
    expect(day.events.single.title, 'Final');
    expect(day.journal!.feelings, ['Feliz']);
    expect(day.period!.symptoms, ['Cólicos']);
    expect(day.trackers.first.value, 6);
    expect(day.trackers[1].value, isNull);
    expect(day.dueItems.single.text, 'Cubiertos');

    final cal = {for (final c in await s.calendar('2026-10-01', '2026-10-31')) c.date: c};
    final c = cal['2026-10-20']!;
    expect([c.events.single.color, c.mood, c.flow, c.dueItems], [cat.color, 4, 3, 1]);

    // Deleting a section keeps its events, uncategorized.
    await s.deleteCategory(cat.id);
    expect((await s.events(from: '2026-10-20', to: '2026-10-20')).single.categoryId, isNull);
  });

  test('list items: pending first, clear done, cascade delete', () async {
    final l = await s.saveList(const TodoList(name: 'Viaje'));
    await s.saveItem(l.id, const Item(text: 'Pasaporte'));
    await s.saveItem(l.id, const Item(text: 'Cargador', quantity: '2'));
    final first = (await s.items(l.id)).first;
    await s.saveItem(l.id, first.copyWith(done: true));
    expect((await s.items(l.id)).map((i) => i.text), ['Cargador', 'Pasaporte']);
    expect((await s.lists()).firstWhere((x) => x.id == l.id).pending, 1);

    await s.clearDone(l.id);
    expect(await s.items(l.id), hasLength(1));
    await s.deleteList(l.id);
    expect(await s.items(l.id), isEmpty);
  });

  test('rejects empty names', () async {
    expect(() => s.saveList(const TodoList(name: '  ')), throwsA(isA<StoreException>()));
  });

  test('backup round-trips and bad files change nothing', () async {
    await s.saveEvent(const Event(title: 'Turno', date: '2026-11-02'));
    await s.savePeriod(const PeriodDay(date: '2026-10-14', flow: 4));
    final backup = await s.exportJson();

    await s.deleteList((await s.lists()).first.id);
    await s.saveEvent(const Event(title: 'Otro', date: '2026-11-03'));

    await expectLater(s.importJson('{"hola": 1}'), throwsA(isA<StoreException>()));
    await expectLater(s.importJson('no es json'), throwsA(isA<StoreException>()));
    expect(await s.lists(), hasLength(2));

    await s.importJson(backup);
    expect((await s.events()).map((e) => e.title), ['Turno']);
    expect(await s.lists(), hasLength(3));
    expect((await s.day('2026-10-14')).period!.flow, 4);
  });
}
