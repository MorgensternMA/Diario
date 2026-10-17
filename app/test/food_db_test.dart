import 'dart:io';

import 'package:diario/data/food_db.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late FoodDb db;

  setUpAll(() async => db = await FoodDb.openFile(File('assets/foods.db').absolute.path, databaseFactoryFfiNoIsolate));

  test('folds case and accents like the build script', () {
    expect(foldText('Jamón ÑANDÚ Açaí'), 'jamon nandu acai');
  });

  test('search ignores case and accents, needs every word', () async {
    expect((await db.search('JAMON')).map((f) => f.name), ['Jamón cocido']);
    expect((await db.search('pollo pechuga')).single.name, 'Pechuga de pollo (cocida)');
    expect(await db.search('  '), isEmpty);
  });

  test('names starting with the query come first', () async {
    final eggs = await db.search('huevo');
    expect(eggs.first.name, startsWith('Huevo'));
  });

  test('values come from USDA and scale to a portion', () async {
    final chicken = (await db.search('pechuga de pollo')).single;
    expect([chicken.kcal, chicken.protein], [165, 31]);
    expect(chicken.proteinFor(150), closeTo(46.5, 0.01));
  });

  test('every food has plausible values', () async {
    final all = await db.db.query('foods');
    expect(all.length, greaterThan(100));
    for (final r in all) {
      final kcal = (r['kcal'] as num).toDouble(), protein = (r['protein'] as num).toDouble();
      // Protein has 4 kcal/g, so it can't exceed the food's calories.
      expect(protein * 4, lessThanOrEqualTo(kcal + 1), reason: '${r['name']}');
      expect((r['grams'] as num) > 0, isTrue, reason: '${r['name']}');
    }
  });
}
