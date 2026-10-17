import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'data/store.dart';
import 'theme.dart';

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
  '#E07A5F', '#F2A65A', '#E9C46A', '#81B29A', '#5FA8A0', '#7FB3D5', //
  '#6C8EBF', '#9B8AD8', '#C38FD1', '#E58FA8', '#B5838D', '#8D7B68',
];

const iconMap = <String, IconData>{
  'event': Icons.event_rounded,
  'school': Icons.school_rounded,
  'medical': Icons.medical_services_rounded,
  'people': Icons.people_rounded,
  'work': Icons.work_rounded,
  'favorite': Icons.favorite_rounded,
  'cake': Icons.cake_rounded,
  'travel': Icons.flight_rounded,
  'home': Icons.home_rounded,
  'pets': Icons.pets_rounded,
  'book': Icons.menu_book_rounded,
  'music': Icons.music_note_rounded,
  'star': Icons.star_rounded,
  'money': Icons.savings_rounded,
  'check': Icons.check_circle_rounded,
  'list': Icons.list_alt_rounded,
  'cart': Icons.shopping_cart_rounded,
  'bag': Icons.shopping_bag_rounded,
  'gift': Icons.card_giftcard_rounded,
  'water': Icons.water_drop_rounded,
  'fitness': Icons.fitness_center_rounded,
  'walk': Icons.directions_walk_rounded,
  'sleep': Icons.bedtime_rounded,
  'food': Icons.restaurant_rounded,
  'pill': Icons.medication_rounded,
  'spa': Icons.spa_rounded,
  'meditation': Icons.self_improvement_rounded,
  'mood': Icons.mood_rounded,
  'phone': Icons.phone_android_rounded,
  'brush': Icons.brush_rounded,
};

IconData iconFor(String name) => iconMap[name] ?? Icons.label_rounded;

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

const periodColor = Color(0xFFD46A86);
const fertileColor = Palette.sage;

Color flowColor(int flow) => periodColor.withValues(alpha: 0.18 + 0.14 * flow);

const levelLabels = {
  'energy': ('Energía', 'Sin fuerza', 'Mucha fuerza'),
  'motivation': ('Ganas', 'Sin ganas', 'Muchas ganas'),
  'hunger': ('Hambre', 'Poca', 'Mucha'),
};

// ---------- Feedback helpers ----------

void showError(BuildContext context, Object e) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
}

/// Runs a store call, showing any error as a snackbar. Returns success.
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

/// State mixin for screens that load data from the store and reload whenever
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
    return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
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

/// Round tinted badge holding an icon, used as each section's mark.
class IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBubble(this.icon, this.color, {super.key, this.size = 38});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(size * 0.36)),
    child: Icon(icon, color: color, size: size * 0.54),
  );
}

/// White rounded card with a soft shadow.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final Color? color;
  final VoidCallback? onTap;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: t.shadow, blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Material(
          color: color ?? t.card,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final Color? color;
  final String? subtitle;
  final VoidCallback? onTap;

  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.color,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBubble(icon, color ?? theme.colorScheme.primary, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (subtitle != null)
                      Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: Tokens.of(context).muted)),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          Padding(padding: const EdgeInsets.only(right: 8), child: child),
        ],
      ),
    );
  }
}

/// Big serif page title with an optional line under it, for tab roots.
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Tokens.of(context).muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                Text(title, style: theme.textTheme.headlineLarge),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

/// Five tappable dots for a 1-5 level; tapping the current value clears it.
class LevelPicker extends StatelessWidget {
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;
  const LevelPicker({super.key, required this.value, required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = Tokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value == i ? 0 : i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 26,
                height: 12,
                decoration: BoxDecoration(color: i <= value ? color : t.line, borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
      ],
    );
  }
}

class EmptyHint extends StatelessWidget {
  final String text;
  const EmptyHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Text(text, style: TextStyle(color: Tokens.of(context).muted)),
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
              radius: 17,
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
            selectedColor: color?.withValues(alpha: 0.22),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            onSelected: (on) => onChanged(on ? [...selected, o] : selected.where((s) => s != o).toList()),
          ),
        ActionChip(
          avatar: const Icon(Icons.add_rounded, size: 16),
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
