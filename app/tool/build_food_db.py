#!/usr/bin/env python3
"""Builds assets/foods.db, the offline food search database.

Usage (from app/):
    python3 -I tool/build_food_db.py <FoodData_Central_sr_legacy_food_json_*.json>

The USDA file is the public-domain "SR Legacy" dataset, downloaded by hand
from https://fdc.nal.usda.gov/download-datasets (FoodData Central). This
script never touches the network: it only reads that file and
tool/generic_foods.tsv, which maps Spanish names to USDA descriptions.
"""

import json
import os
import sqlite3
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'assets', 'foods.db')
MAPPING = os.path.join(HERE, 'generic_foods.tsv')


def fold(s):
    """Lowercase without accents; must match foldText() in lib/data/food_db.dart."""
    s = unicodedata.normalize('NFD', s.lower())
    return ''.join(c for c in s if unicodedata.category(c) != 'Mn')


def usda_values(path):
    """description -> (fdcId, kcal per 100 g, protein g per 100 g)."""
    with open(path, encoding='utf-8') as f:
        foods = json.load(f)['SRLegacyFoods']
    out = {}
    for food in foods:
        kcal = protein = None
        for n in food['foodNutrients']:
            name, unit = n['nutrient']['name'], n['nutrient']['unitName']
            if name == 'Energy' and unit == 'kcal':
                kcal = n.get('amount')
            elif name == 'Protein':
                protein = n.get('amount')
        if kcal is not None and protein is not None:
            out[food['description']] = (food['fdcId'], float(kcal), float(protein))
    return out


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    usda = usda_values(sys.argv[1])

    rows, missing = [], []
    with open(MAPPING, encoding='utf-8') as f:
        for line in f:
            if not line.strip() or line.startswith('#'):
                continue
            parts = line.rstrip('\n').split('\t')
            name, desc, grams = parts[0], parts[1], float(parts[2])
            unit = parts[3] if len(parts) > 3 else ''
            if desc not in usda:
                missing.append(desc)
                continue
            fdc, kcal, protein = usda[desc]
            rows.append((name, fold(name), kcal, protein, grams, unit, 'usda', fdc))
    if missing:
        sys.exit('Not found in the USDA file:\n  ' + '\n  '.join(missing))

    if os.path.exists(OUT):
        os.remove(OUT)
    db = sqlite3.connect(OUT)
    db.executescript('''
        CREATE TABLE foods (
            id        INTEGER PRIMARY KEY,
            name      TEXT NOT NULL,
            search    TEXT NOT NULL,  -- folded name for accent-insensitive LIKE
            kcal      REAL NOT NULL,  -- per 100 g
            protein   REAL NOT NULL,  -- grams per 100 g
            grams     REAL NOT NULL,  -- typical portion
            unit      TEXT NOT NULL,  -- portion label, e.g. "1 huevo"
            source    TEXT NOT NULL,
            source_id INTEGER
        );
        CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
    ''')
    db.executemany(
        'INSERT INTO foods(name, search, kcal, protein, grams, unit, source, source_id) VALUES (?,?,?,?,?,?,?,?)',
        rows,
    )
    db.execute(
        "INSERT INTO meta VALUES ('attribution', 'USDA, Agricultural Research Service. FoodData Central: SR Legacy (dominio público).')"
    )
    db.execute('PRAGMA user_version = 1')
    db.commit()
    db.execute('VACUUM')
    db.close()
    print(f'{len(rows)} alimentos -> {os.path.normpath(OUT)} ({os.path.getsize(OUT) // 1024} KB)')


if __name__ == '__main__':
    main()
