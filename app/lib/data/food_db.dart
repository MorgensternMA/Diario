import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// A food from the bundled reference database, with values per 100 g.
class FoodRef {
  final String name;
  final double kcal;
  final double protein; // grams per 100 g
  final double grams; // a typical portion
  final String unit; // how that portion reads, e.g. "1 huevo"

  const FoodRef(this.name, this.kcal, this.protein, this.grams, [this.unit = '']);

  double kcalFor(double g) => kcal * g / 100;
  double proteinFor(double g) => protein * g / 100;
}

/// Lowercase without accents; must match fold() in tool/build_food_db.py.
String foldText(String s) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const to = 'aaaaaeeeeiiiiooooouuuunc';
  final lower = s.toLowerCase();
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    out.write(i < 0 ? ch : to[i]);
  }
  return out.toString();
}

late FoodDb foodDb;

/// Read-only search over assets/foods.db (USDA FoodData Central, public
/// domain), built by tool/build_food_db.py. Works offline.
class FoodDb {
  /// Bump together with PRAGMA user_version in the build script so updated
  /// data replaces the copy on the device.
  static const _version = 1;

  final Database db;
  FoodDb._(this.db);

  static Future<FoodDb> open() async {
    final path = p.join(await getDatabasesPath(), 'foods_v$_version.db');
    if (!File(path).existsSync()) {
      final data = await rootBundle.load('assets/foods.db');
      await File(path).writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
    }
    return FoodDb._(await openReadOnlyDatabase(path));
  }

  /// Opens a database file directly (tests).
  static Future<FoodDb> openFile(String path, DatabaseFactory factory) async =>
      FoodDb._(await factory.openDatabase(path, options: OpenDatabaseOptions(readOnly: true)));

  /// Foods whose name contains every word of [query], ignoring case and
  /// accents; names starting with the first word come first.
  Future<List<FoodRef>> search(String query, {int limit = 8}) async {
    final words = foldText(query).split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    final rows = await db.query(
      'foods',
      where: List.filled(words.length, 'search LIKE ?').join(' AND '),
      whereArgs: [for (final w in words) '%$w%'],
      orderBy: "search LIKE '${words.first.replaceAll("'", "''")}%' DESC, length(name)",
      limit: limit,
    );
    return [
      for (final r in rows)
        FoodRef(
          r['name'] as String,
          (r['kcal'] as num).toDouble(),
          (r['protein'] as num).toDouble(),
          (r['grams'] as num).toDouble(),
          r['unit'] as String,
        ),
    ];
  }
}
