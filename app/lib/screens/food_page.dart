import 'package:flutter/material.dart';

import '../common.dart';
import '../data/food_table.dart';
import '../data/store.dart';
import '../models.dart';
import '../theme.dart';

/// Meal that fits the current time of day.
String _mealNow() {
  final h = DateTime.now().hour;
  if (h < 11) return 'breakfast';
  if (h < 16) return 'lunch';
  if (h < 20) return 'snack';
  return 'dinner';
}

String kcal(double v) => '${v.round()} kcal';

/// Grams of protein, e.g. "24 g".
String grams(double v) => '${fmtNum(double.parse(v.toStringAsFixed(v < 10 ? 1 : 0)))} g';

const proteinColor = Palette.agenda;

/// Rounded progress bar for a daily goal.
class GoalBar extends StatelessWidget {
  final double value;
  final double goal;
  final Color color;
  final double height;
  const GoalBar({super.key, required this.value, required this.goal, required this.color, this.height = 8});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(height / 2),
    child: LinearProgressIndicator(
      minHeight: height,
      value: goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0,
      color: color,
      backgroundColor: Tokens.of(context).line,
    ),
  );
}

/// Compact calories and protein card for "Hoy".
class FoodSummaryCard extends StatelessWidget {
  final Day day;
  const FoodSummaryCard({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    final total = day.calories;
    final protein = day.protein;
    final byMeal = <String, double>{};
    for (final f in day.food) {
      byMeal[f.meal] = (byMeal[f.meal] ?? 0) + f.kcal;
    }
    final muted = Tokens.of(context).muted;
    Widget line(String label, String value, double v, double goal, Color color) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
              const Spacer(),
              Text(
                value,
                style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (goal > 0) ...[const SizedBox(height: 5), GoalBar(value: v, goal: goal, color: color, height: 7)],
        ],
      ),
    );
    return SectionCard(
      title: 'Comidas',
      icon: Icons.restaurant_rounded,
      color: Palette.food,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FoodPage(date: parseYmd(day.date)))),
      trailing: IconButton(
        tooltip: 'Agregar comida',
        onPressed: () => showFoodSheet(context, date: day.date),
        icon: const Icon(Icons.add_rounded),
      ),
      child: day.food.isEmpty
          ? const EmptyHint('Todavía no anotaste comidas')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line(
                  'Calorías',
                  day.calorieGoal > 0 ? '${total.round()} de ${kcal(day.calorieGoal)}' : kcal(total),
                  total,
                  day.calorieGoal,
                  Palette.food,
                ),
                line(
                  'Proteína',
                  day.proteinGoal > 0 ? '${grams(protein)} de ${grams(day.proteinGoal)}' : grams(protein),
                  protein,
                  day.proteinGoal,
                  proteinColor,
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final m in meals.entries)
                      if (byMeal.containsKey(m.key)) _Pill('${m.value} · ${byMeal[m.key]!.round()}'),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: Palette.food.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
  );
}

typedef _FoodData = (List<FoodEntry>, double, double, Map<String, ({double kcal, double protein})>);

/// A day's meals with calories, protein and goals.
class FoodPage extends StatefulWidget {
  final DateTime date;
  const FoodPage({super.key, required this.date});

  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> with Loader<FoodPage, _FoodData> {
  late DateTime _date = widget.date;

  @override
  Future<_FoodData> fetch() => (
    store.food(ymd(_date)),
    store.calorieGoal(),
    store.proteinGoal(),
    store.dailyTotals(ymd(_date.subtract(const Duration(days: 7))), ymd(_date.subtract(const Duration(days: 1)))),
  ).wait;

  void _shift(int days) {
    setState(() => _date = DateTime(_date.year, _date.month, _date.day + days));
    reload();
  }

  Future<void> _editGoals(double kcalGoal, double proteinGoal) async {
    final k = TextEditingController(text: kcalGoal > 0 ? kcalGoal.round().toString() : '');
    final p = TextEditingController(text: proteinGoal > 0 ? proteinGoal.round().toString() : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Metas diarias'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: k,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Calorías', hintText: 'Ej: 2000', suffixText: 'kcal'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: p,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Proteína', hintText: 'Ej: 90', suffixText: 'g'),
            ),
            const SizedBox(height: 8),
            Text('Dejá vacío lo que no quieras seguir.', style: TextStyle(fontSize: 12.5, color: Tokens.of(ctx).muted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    double parse(String s) => double.tryParse(s.replaceAll(',', '.').trim()) ?? 0;
    await attempt(context, () async {
      await store.setCalorieGoal(parse(k.text));
      await store.setProteinGoal(parse(p.text));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comidas'),
        actions: [
          IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
          IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Palette.food,
        onPressed: () => showFoodSheet(context, date: ymd(_date)),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: body((d) {
        final (food, kcalGoal, proteinGoal, week) = d;
        final total = food.fold<double>(0, (s, f) => s + f.kcal);
        final protein = food.fold<double>(0, (s, f) => s + f.protein);
        final muted = Tokens.of(context).muted;
        final avgKcal = week.isEmpty ? null : week.values.fold<double>(0, (s, t) => s + t.kcal) / week.length;
        final avgProtein = week.isEmpty ? null : week.values.fold<double>(0, (s, t) => s + t.protein) / week.length;
        return ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
              child: Text(relativeDate(_date), style: Theme.of(context).textTheme.titleMedium),
            ),
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _Ring(total: total, goal: kcalGoal),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kcalGoal <= 0
                                  ? 'Sin meta de calorías'
                                  : total <= kcalGoal
                                  ? 'Te quedan ${kcal(kcalGoal - total)}'
                                  : '${kcal(total - kcalGoal)} sobre la meta',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const Text('Proteína', style: TextStyle(fontWeight: FontWeight.w700)),
                                const Spacer(),
                                Text(
                                  proteinGoal > 0 ? '${grams(protein)} / ${grams(proteinGoal)}' : grams(protein),
                                  style: TextStyle(color: muted, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (proteinGoal > 0)
                              GoalBar(value: protein, goal: proteinGoal, color: proteinColor)
                            else
                              Text('Sin meta de proteína', style: TextStyle(fontSize: 12.5, color: muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (avgKcal != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Promedio de la semana: ${kcal(avgKcal)} · ${grams(avgProtein!)} de proteína',
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: () => _editGoals(kcalGoal, proteinGoal),
                    icon: const Icon(Icons.flag_rounded, size: 18),
                    label: Text(kcalGoal > 0 || proteinGoal > 0 ? 'Cambiar metas' : 'Poner metas'),
                  ),
                ],
              ),
            ),
            for (final m in meals.entries)
              _mealCard(context, m.key, m.value, food.where((f) => f.meal == m.key).toList()),
          ],
        );
      }),
    );
  }

  Widget _mealCard(BuildContext context, String meal, String label, List<FoodEntry> entries) {
    final sum = entries.fold<double>(0, (s, f) => s + f.kcal);
    final prot = entries.fold<double>(0, (s, f) => s + f.protein);
    final muted = Tokens.of(context).muted;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 10, 8, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
              if (sum > 0)
                Text(
                  prot > 0 ? '${kcal(sum)} · ${grams(prot)}' : kcal(sum),
                  style: TextStyle(color: muted, fontWeight: FontWeight.w700),
                ),
              IconButton(
                tooltip: 'Agregar a $label',
                onPressed: () => showFoodSheet(context, date: ymd(_date), meal: meal),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          for (final f in entries)
            Dismissible(
              key: ValueKey(f.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => attempt(context, () => store.deleteFood(f.id)),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete_outline_rounded),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => showFoodSheet(context, date: f.date, entry: f),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 6, 12, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            if (f.portion.isNotEmpty) Text(f.portion, style: TextStyle(fontSize: 13, color: muted)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(f.kcal.round().toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (f.protein > 0)
                            Text('${grams(f.protein)} prot.', style: TextStyle(fontSize: 12.5, color: muted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final double total;
  final double goal;
  const _Ring({required this.total, required this.goal});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: goal > 0 ? (total / goal).clamp(0.0, 1.0) : (total > 0 ? 1 : 0),
              strokeWidth: 11,
              strokeCap: StrokeCap.round,
              color: Palette.food,
              backgroundColor: Tokens.of(context).line,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(total.round().toString(), style: Theme.of(context).textTheme.headlineMedium),
              Text('kcal', style: TextStyle(color: Tokens.of(context).muted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showFoodSheet(BuildContext context, {required String date, String? meal, FoodEntry? entry}) async {
  final frequent = await store.frequentFoods();
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FoodSheet(date: date, meal: entry?.meal ?? meal ?? _mealNow(), entry: entry, frequent: frequent),
  );
}

class _FoodSheet extends StatefulWidget {
  final String date;
  final String meal;
  final FoodEntry? entry;
  final List<FoodEntry> frequent;
  const _FoodSheet({required this.date, required this.meal, this.entry, required this.frequent});

  @override
  State<_FoodSheet> createState() => _FoodSheetState();
}

class _FoodSheetState extends State<_FoodSheet> {
  late String _meal = widget.meal;
  late final _name = TextEditingController(text: widget.entry?.name);
  late final _kcal = TextEditingController(text: widget.entry == null ? '' : widget.entry!.kcal.round().toString());
  late final _protein = TextEditingController(
    text: widget.entry == null || widget.entry!.protein == 0 ? '' : fmtNum(widget.entry!.protein),
  );
  late final _portion = TextEditingController(text: widget.entry?.portion);
  final _grams = TextEditingController();

  /// Reference food picked from the table; calories and protein follow the grams.
  FoodRef? _ref;

  @override
  void dispose() {
    for (final c in [_name, _kcal, _protein, _portion, _grams]) {
      c.dispose();
    }
    super.dispose();
  }

  String _num(double v) => fmtNum(double.parse(v.toStringAsFixed(v < 10 ? 1 : 0)));

  void _pickRef(FoodRef r) {
    setState(() {
      _ref = r;
      _name.text = r.name;
      _grams.text = _num(r.grams);
      _applyGrams();
    });
  }

  void _applyGrams() {
    final r = _ref;
    final g = double.tryParse(_grams.text.replaceAll(',', '.'));
    if (r == null || g == null) return;
    _kcal.text = r.kcalFor(g).round().toString();
    _protein.text = _num(r.proteinFor(g));
    _portion.text = r.unit.isNotEmpty && g == r.grams ? '${r.unit} (${_num(g)} g)' : '${_num(g)} g';
  }

  void _pickFrequent(FoodEntry f) {
    setState(() {
      _ref = null;
      _name.text = f.name;
      _kcal.text = f.kcal.round().toString();
      _protein.text = f.protein == 0 ? '' : fmtNum(f.protein);
      _portion.text = f.portion;
    });
  }

  Future<void> _save() async {
    double parse(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.').trim()) ?? 0;
    final ok = await attempt(
      context,
      () => store.saveFood(
        FoodEntry(
          id: widget.entry?.id ?? 0,
          date: widget.date,
          meal: _meal,
          name: _name.text,
          kcal: parse(_kcal),
          protein: parse(_protein),
          portion: _portion.text,
        ),
      ),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Tokens.of(context).muted;
    final query = _name.text.trim().toLowerCase();
    final showSuggestions = _ref == null && widget.entry == null;
    final mine = [
      for (final f in widget.frequent)
        if (query.isEmpty || f.name.toLowerCase().contains(query)) f,
    ].take(8).toList();
    final table = showSuggestions ? searchFoods(query).take(8).toList() : const <FoodRef>[];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.entry == null ? 'Anotar comida' : 'Editar comida',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in meals.entries)
                    ChoiceChip(
                      showCheckmark: false,
                      label: Text(m.value),
                      selected: _meal == m.key,
                      selectedColor: Palette.food.withValues(alpha: 0.25),
                      onSelected: (_) => setState(() => _meal = m.key),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {
                  if (_ref != null && _name.text != _ref!.name) _ref = null;
                }),
                decoration: const InputDecoration(
                  hintText: '¿Qué comiste? (ej: pollo, huevo, yogur)',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              if (showSuggestions && (mine.isNotEmpty || table.isNotEmpty)) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final f in mine)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            avatar: const Icon(Icons.history_rounded, size: 16),
                            label: Text('${f.name} · ${f.kcal.round()}'),
                            onPressed: () => _pickFrequent(f),
                          ),
                        ),
                      for (final r in table)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            avatar: const Icon(Icons.menu_book_rounded, size: 16),
                            label: Text(r.name),
                            onPressed: () => _pickRef(r),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (_ref != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _grams,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(_applyGrams),
                        decoration: const InputDecoration(labelText: 'Cantidad', suffixText: 'g'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Cada 100 g: ${_ref!.kcal.round()} kcal · ${_num(_ref!.protein)} g de proteína (aprox.)',
                        style: TextStyle(fontSize: 12.5, color: muted),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _kcal,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Calorías', suffixText: 'kcal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _protein,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Proteína', suffixText: 'g'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _portion,
                decoration: const InputDecoration(labelText: 'Porción (opcional)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _save, child: const Text('Guardar')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
