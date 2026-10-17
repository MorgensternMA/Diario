import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'data/store.dart';

// ---------- Dates ----------

final _ymd = DateFormat('yyyy-MM-dd');

String ymd(DateTime d) => _ymd.format(d);

DateTime parseYmd(String s) => _ymd.parse(s);

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// "Viernes 16 de octubre"
String longDate(DateTime d) => _cap(DateFormat("EEEE d 'de' MMMM", 'es').format(d));

/// "16 oct"
String shortDate(String ymdStr) => DateFormat('d MMM', 'es').format(parseYmd(ymdStr));

/// "Hoy", "Mañana", "Ayer" or the long date.
String relativeDate(DateTime d) {
  final diff = d.difference(today()).inDays;
  return switch (diff) {
    0 => 'Hoy',
    1 => 'Mañana',
    -1 => 'Ayer',
    _ => longDate(d),
  };
}

// ---------- Colors & icons ----------

Color hexColor(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.tryParse(h, radix: 16) ?? 0xFF9E9E9E);
}

String colorHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

const palette = [
  '#EF5350', '#EC407A', '#AB47BC', '#7E57C2', '#5C6BC0', '#42A5F5', '#26C6DA', //
  '#26A69A', '#66BB6A', '#D4E157', '#FFCA28', '#FFA726', '#8D6E63', '#78909C',
];

const iconMap = <String, IconData>{
  'event': Icons.event,
  'school': Icons.school,
  'medical': Icons.medical_services,
  'people': Icons.people,
  'work': Icons.work,
  'favorite': Icons.favorite,
  'cake': Icons.cake,
  'travel': Icons.flight,
  'home': Icons.home,
  'pets': Icons.pets,
  'book': Icons.menu_book,
  'music': Icons.music_note,
  'star': Icons.star,
  'money': Icons.savings,
  'check': Icons.check_circle,
  'list': Icons.list_alt,
  'cart': Icons.shopping_cart,
  'bag': Icons.shopping_bag,
  'gift': Icons.card_giftcard,
  'water': Icons.water_drop,
  'fitness': Icons.fitness_center,
  'walk': Icons.directions_walk,
  'sleep': Icons.bedtime,
  'food': Icons.restaurant,
  'pill': Icons.medication,
  'spa': Icons.spa,
  'meditation': Icons.self_improvement,
  'mood': Icons.mood,
  'phone': Icons.phone_android,
  'brush': Icons.brush,
};

IconData iconFor(String name) => iconMap[name] ?? Icons.label;

// ---------- Mood & period vocab ----------

const moodEmoji = ['', '😞', '😕', '😐', '🙂', '😄'];
const moodLabel = ['', 'Muy mal', 'Mal', 'Normal', 'Bien', 'Genial'];

const feelingOptions = [
  'Feliz', 'En calma', 'Con energía', 'Motivación', 'Cansancio', //
  'Ansiedad', 'Estrés', 'Tristeza', 'Irritabilidad', 'Sensibilidad',
];

const flowLabel = ['Nada', 'Manchado', 'Leve', 'Medio', 'Abundante'];

const symptomOptions = [
  'Cólicos', 'Dolor de cabeza', 'Hinchazón', 'Acné', 'Dolor de espalda', //
  'Senos sensibles', 'Cansancio', 'Antojos', 'Náuseas', 'Insomnio',
];

const periodColor = Color(0xFFE53970);
const fertileColor = Color(0xFF26A69A);

Color flowColor(int flow) => periodColor.withValues(alpha: 0.25 + 0.18 * flow);

// ---------- Feedback helpers ----------

void showError(BuildContext context, Object e) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
}

/// Runs an API call, showing any error as a snackbar. Returns success.
Future<bool> attempt(BuildContext context, Future<void> Function() f) async {
  try {
    await f();
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

Future<bool> confirm(BuildContext context, String message, {String action = 'Eliminar'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
      ],
    ),
  );
  return ok ?? false;
}

// ---------- Loading pattern ----------

/// State mixin for screens that load data from the API and reload whenever
/// anything changes (see [bus]).
mixin Loader<W extends StatefulWidget, T> on State<W> {
  T? data;
  Object? error;
  bool loading = true;
  int _gen = 0;

  Future<T> fetch();

  Future<void> reload() async {
    // Drop responses from requests superseded by a newer reload.
    final gen = ++_gen;
    try {
      final d = await fetch();
      if (!mounted || gen != _gen) return;
      setState(() {
        data = d;
        error = null;
        loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    bus.addListener(reload);
    reload();
  }

  @override
  void dispose() {
    bus.removeListener(reload);
    super.dispose();
  }

  /// Renders loading/error states, or [builder] once data is available.
  Widget body(Widget Function(T data) builder) {
    final d = data;
    if (d != null) return RefreshIndicator(onRefresh: reload, child: builder(d));
    if (error != null) return ErrorView(error: error!, onRetry: reload);
    return const Center(child: CircularProgressIndicator());
  }
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text('$error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

// ---------- Small shared widgets ----------

class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final Color? color;

  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color ?? theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                ?trailing,
              ],
            ),
            const SizedBox(height: 4),
            Padding(padding: const EdgeInsets.only(right: 8), child: child),
          ],
        ),
      ),
    );
  }
}

class EmptyHint extends StatelessWidget {
  final String text;
  const EmptyHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
  );
}

class ColorPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const ColorPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final hex in palette)
          GestureDetector(
            onTap: () => onChanged(hex),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: hexColor(hex),
              child: hex.toUpperCase() == value.toUpperCase()
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          ),
      ],
    );
  }
}

class IconPicker extends StatelessWidget {
  final String value;
  final String color;
  final ValueChanged<String> onChanged;
  const IconPicker({super.key, required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = hexColor(color);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final e in iconMap.entries)
          IconButton(
            onPressed: () => onChanged(e.key),
            isSelected: e.key == value,
            style: IconButton.styleFrom(backgroundColor: e.key == value ? c.withValues(alpha: 0.2) : null),
            icon: Icon(e.value, color: e.key == value ? c : null),
          ),
      ],
    );
  }
}

/// Multi-select chips with the option to add custom values.
class TagPicker extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final Color? color;

  const TagPicker({super.key, required this.options, required this.selected, required this.onChanged, this.color});

  Future<void> _addCustom(BuildContext context) async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar'),
        content: TextField(controller: ctrl, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Agregar')),
        ],
      ),
    );
    final t = text?.trim() ?? '';
    if (t.isNotEmpty && !selected.contains(t)) onChanged([...selected, t]);
  }

  @override
  Widget build(BuildContext context) {
    final all = [...options, ...selected.where((s) => !options.contains(s))];
    return Wrap(
      spacing: 6,
      runSpacing: 0,
      children: [
        for (final o in all)
          FilterChip(
            label: Text(o),
            selected: selected.contains(o),
            selectedColor: color?.withValues(alpha: 0.25),
            visualDensity: VisualDensity.compact,
            onSelected: (on) => onChanged(on ? [...selected, o] : selected.where((s) => s != o).toList()),
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 16),
          label: const Text('Otro'),
          visualDensity: VisualDensity.compact,
          onPressed: () => _addCustom(context),
        ),
      ],
    );
  }
}

/// Formats numbers without a trailing ".0".
String fmtNum(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
