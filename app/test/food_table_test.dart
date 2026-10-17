import 'package:diario/data/food_table.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search ignores case and accents', () {
    expect(searchFoods('JAMON').map((f) => f.name), ['Jamón cocido']);
    expect(searchFoods('pollo').length, 2);
    expect(searchFoods('  '), isEmpty);
  });

  test('scales per 100 g values to a portion', () {
    final chicken = searchFoods('pechuga').single;
    expect(chicken.kcalFor(150), closeTo(247.5, 0.01));
    expect(chicken.proteinFor(150), closeTo(46.5, 0.01));
  });

  test('table values are plausible', () {
    for (final f in foodTable) {
      // Protein has 4 kcal/g, so it can't exceed the food's calories.
      expect(f.protein * 4, lessThanOrEqualTo(f.kcal + 1), reason: f.name);
      expect(f.grams, greaterThan(0), reason: f.name);
    }
  });
}
