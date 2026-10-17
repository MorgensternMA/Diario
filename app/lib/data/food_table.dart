/// Approximate nutrition of common foods, per 100 g (cooked where it applies),
/// to fill calories and protein from a weight. Values are rounded averages
/// from standard food-composition tables; the user can always edit them.
class FoodRef {
  final String name;
  final double kcal; // per 100 g
  final double protein; // grams per 100 g
  final double grams; // a typical portion
  final String unit; // how that portion reads, e.g. "1 huevo"

  const FoodRef(this.name, this.kcal, this.protein, this.grams, [this.unit = '']);

  double kcalFor(double g) => kcal * g / 100;
  double proteinFor(double g) => protein * g / 100;
}

const foodTable = [
  // Carnes, pescados y huevos
  FoodRef('Pechuga de pollo', 165, 31, 150),
  FoodRef('Muslo de pollo', 209, 26, 120),
  FoodRef('Carne vacuna magra', 217, 26, 150),
  FoodRef('Carne picada', 250, 26, 150),
  FoodRef('Bondiola / cerdo', 242, 27, 150),
  FoodRef('Lomo de cerdo', 196, 29, 150),
  FoodRef('Jamón cocido', 130, 19, 30, '2 fetas'),
  FoodRef('Salmón', 206, 22, 150),
  FoodRef('Merluza', 95, 20, 150),
  FoodRef('Atún al natural', 116, 26, 120, '1 lata'),
  FoodRef('Huevo', 143, 12.6, 50, '1 huevo'),
  FoodRef('Clara de huevo', 52, 11, 33, '1 clara'),
  // Lácteos
  FoodRef('Leche entera', 61, 3.2, 200, '1 vaso'),
  FoodRef('Leche descremada', 35, 3.4, 200, '1 vaso'),
  FoodRef('Yogur natural', 61, 3.5, 190, '1 pote'),
  FoodRef('Yogur griego', 73, 10, 170, '1 pote'),
  FoodRef('Queso cremoso', 290, 18, 40),
  FoodRef('Mozzarella', 280, 22, 40),
  FoodRef('Queso rallado', 430, 38, 10, '1 cda'),
  FoodRef('Ricota', 174, 11, 60),
  FoodRef('Queso untable', 250, 6, 20, '1 cda'),
  // Legumbres y proteína vegetal
  FoodRef('Lentejas', 116, 9, 150),
  FoodRef('Garbanzos', 164, 8.9, 150),
  FoodRef('Porotos', 132, 8.9, 150),
  FoodRef('Tofu', 144, 15, 100),
  FoodRef('Hummus', 166, 7.9, 50),
  FoodRef('Proteína en polvo', 400, 80, 30, '1 scoop'),
  // Cereales y harinas
  FoodRef('Arroz blanco', 130, 2.7, 150),
  FoodRef('Arroz integral', 123, 2.7, 150),
  FoodRef('Fideos', 158, 5.8, 180),
  FoodRef('Pan francés', 270, 9, 60),
  FoodRef('Pan integral', 250, 11, 50, '2 rebanadas'),
  FoodRef('Avena', 389, 16.9, 40),
  FoodRef('Galletitas de agua', 420, 10, 30, '5 galletitas'),
  FoodRef('Pizza muzzarella', 266, 11, 120, '1 porción'),
  // Verduras y frutas
  FoodRef('Papa', 87, 1.9, 150),
  FoodRef('Batata', 90, 2, 150),
  FoodRef('Brócoli', 35, 2.4, 100),
  FoodRef('Ensalada (lechuga y tomate)', 18, 1, 150),
  FoodRef('Palta', 160, 2, 70, '½ palta'),
  FoodRef('Banana', 89, 1.1, 120, '1 banana'),
  FoodRef('Manzana', 52, 0.3, 150, '1 manzana'),
  // Frutos secos y otros
  FoodRef('Maní', 567, 26, 30),
  FoodRef('Almendras', 579, 21, 30),
  FoodRef('Mantequilla de maní', 588, 25, 16, '1 cda'),
  FoodRef('Dulce de leche', 315, 7, 20, '1 cda'),
  FoodRef('Chocolate con leche', 535, 7.7, 25),
];

String _fold(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áà]'), 'a')
    .replaceAll(RegExp('[éè]'), 'e')
    .replaceAll(RegExp('[íì]'), 'i')
    .replaceAll(RegExp('[óò]'), 'o')
    .replaceAll(RegExp('[úùü]'), 'u');

/// Reference foods whose name contains [query], ignoring case and accents.
List<FoodRef> searchFoods(String query) {
  final q = _fold(query.trim());
  if (q.isEmpty) return const [];
  return [
    for (final f in foodTable)
      if (_fold(f.name).contains(q)) f,
  ];
}
