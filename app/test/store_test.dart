import 'dart:io';

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

  test('food log, frequent foods and calorie goal', () async {
    await s.saveFood(const FoodEntry(date: '2026-10-20', meal: 'breakfast', name: 'Tostadas', kcal: 250, protein: 8));
    await s.saveFood(const FoodEntry(date: '2026-10-20', meal: 'lunch', name: 'Ensalada', kcal: 400, protein: 30));
    await s.saveFood(const FoodEntry(date: '2026-10-21', meal: 'breakfast', name: 'tostadas', kcal: 300, portion: '2'));
    await s.setCalorieGoal(1800);
    await s.setProteinGoal(90);

    final day = await s.day('2026-10-20');
    expect(day.calories, 650);
    expect(day.calorieGoal, 1800);
    expect(day.protein, 38);
    expect(day.proteinGoal, 90);
    final totals = await s.dailyTotals('2026-10-19', '2026-10-21');
    expect(totals.keys, ['2026-10-20', '2026-10-21']);
    expect([totals['2026-10-20']!.kcal, totals['2026-10-20']!.protein], [650, 38]);

    // Same food in different case counts once, with its latest calories.
    final freq = await s.frequentFoods();
    expect(freq.first.kcal, 300);
    expect(freq, hasLength(2));
  });

  test('medicines and daily levels', () async {
    await s.saveMed(const MedEntry(date: '2026-10-20', name: 'Ibuprofeno', dose: '400 mg', time: '10:30'));
    await s.saveJournal(const JournalEntry(date: '2026-10-20', energy: 2, motivation: 3, hunger: 5));
    final day = await s.day('2026-10-20');
    expect(day.meds.single.dose, '400 mg');
    expect([day.journal!.energy, day.journal!.motivation, day.journal!.hunger], [2, 3, 5]);
    expect((await s.frequentMeds()).single.name, 'Ibuprofeno');
    expect(await s.journalEntries(), hasLength(1));
  });

  test('hidden sections setting', () async {
    expect(await s.hiddenSections(), isEmpty);
    await s.setHiddenSections({'cycle', 'food'});
    expect(await s.hiddenSections(), {'cycle', 'food'});
  });

  test('rejects empty names', () async {
    expect(() => s.saveList(const TodoList(name: '  ')), throwsA(isA<StoreException>()));
  });

  test('backup round-trips and bad files change nothing', () async {
    await s.saveEvent(const Event(title: 'Turno', date: '2026-11-02'));
    await s.savePeriod(const PeriodDay(date: '2026-10-14', flow: 4));
    await s.saveFood(const FoodEntry(date: '2026-10-14', meal: 'lunch', name: 'Fideos', kcal: 600));
    await s.saveMed(const MedEntry(date: '2026-10-14', name: 'Ibuprofeno'));
    await s.setCalorieGoal(2000);
    final backup = await s.exportJson();

    await s.deleteList((await s.lists()).first.id);
    await s.saveEvent(const Event(title: 'Otro', date: '2026-11-03'));

    await expectLater(s.importJson('{"hola": 1}'), throwsA(isA<StoreException>()));
    await expectLater(s.importJson('no es json'), throwsA(isA<StoreException>()));
    expect(await s.lists(), hasLength(2));

    await s.importJson(backup);
    expect((await s.events()).map((e) => e.title), ['Turno']);
    expect(await s.lists(), hasLength(3));
    final day = await s.day('2026-10-14');
    expect(day.period!.flow, 4);
    expect(day.calories, 600);
    expect(day.meds.single.name, 'Ibuprofeno');
    expect(day.calorieGoal, 2000);
  });

  test('upgrades a version 1 database without losing data', () async {
    final path = '${Directory.systemTemp.createTempSync('diario').path}/v1.db';
    final v1 = await databaseFactoryFfiNoIsolate.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          for (final stmt in schemaV1) {
            await db.execute(stmt);
          }
          await db.insert('journal', {'date': '2026-01-01', 'mood': 5, 'note': 'año nuevo'});
        },
      ),
    );
    await v1.close();

    final up = await Store.open(path: path, factory: databaseFactoryFfiNoIsolate);
    final j = (await up.journalEntries()).single;
    expect([j.mood, j.note, j.energy], [5, 'año nuevo', 0]);
    await up.saveFood(const FoodEntry(date: '2026-01-01', meal: 'dinner', name: 'Vitel toné', kcal: 500));
    await up.saveJournal(const JournalEntry(date: '2026-01-01', mood: 5, energy: 3));
    expect((await up.day('2026-01-01')).journal!.energy, 3);
    await up.close();
  });
}
