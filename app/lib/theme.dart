import 'package:flutter/material.dart';

/// Warm "bag" palette: cream paper, terracotta accent and one pastel per
/// compartment.
class Palette {
  static const coral = Color(0xFFD4705E);
  static const sage = Color(0xFF81B29A);

  // Compartments of the bag.
  static const agenda = Color(0xFF9B8AD8);
  static const lists = Color(0xFF81B29A);
  static const food = Color(0xFFF2A65A);
  static const habits = Color(0xFF7FB3D5);
  static const journal = Color(0xFFE58FA8);
  static const cycle = Color(0xFFB5838D);
  static const backup = Color(0xFF8D7B68);
}

const _lightBg = Color(0xFFFAF6F1);
const _darkBg = Color(0xFF191615);

/// Extra tokens Material's ColorScheme has no slot for.
class Tokens extends ThemeExtension<Tokens> {
  final Color background;
  final Color card;
  final Color muted;
  final Color line;
  final Color shadow;

  const Tokens({
    required this.background,
    required this.card,
    required this.muted,
    required this.line,
    required this.shadow,
  });

  static Tokens of(BuildContext context) => Theme.of(context).extension<Tokens>()!;

  @override
  Tokens copyWith() => this;

  @override
  Tokens lerp(Tokens? other, double t) => t < 0.5 ? this : (other ?? this);
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final tokens = dark
      ? const Tokens(
          background: _darkBg,
          card: Color(0xFF24201E),
          muted: Color(0xFFA69C95),
          line: Color(0xFF352F2B),
          shadow: Color(0x00000000),
        )
      : const Tokens(
          background: _lightBg,
          card: Colors.white,
          muted: Color(0xFF8A817C),
          line: Color(0xFFEDE5DC),
          shadow: Color(0x0F5A3A2A),
        );
  final ink = dark ? const Color(0xFFF3ECE6) : const Color(0xFF2D2926);
  final primary = dark ? const Color(0xFFE8897A) : Palette.coral;

  final scheme = ColorScheme.fromSeed(seedColor: Palette.coral, brightness: b).copyWith(
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: dark ? const Color(0xFF4A2A24) : const Color(0xFFF8DED7),
    onPrimaryContainer: dark ? const Color(0xFFFFDAD3) : const Color(0xFF5A2A20),
    secondary: Palette.sage,
    surface: tokens.card,
    onSurface: ink,
    onSurfaceVariant: tokens.muted,
    outline: tokens.muted,
    outlineVariant: tokens.line,
    surfaceContainerHighest: dark ? const Color(0xFF2E2926) : const Color(0xFFF2EBE4),
    surfaceContainerHigh: dark ? const Color(0xFF2A2523) : const Color(0xFFF5EFE9),
    surfaceContainer: tokens.background,
    surfaceContainerLow: tokens.background,
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Nunito');
  TextStyle serif(double size, [FontWeight w = FontWeight.w600]) =>
      TextStyle(fontFamily: 'Fraunces', fontSize: size, fontWeight: w, color: ink, height: 1.15, letterSpacing: -0.3);

  // Adjust sizes on top of Material's styles (keeping their colors and
  // metrics), then paint everything with the ink color.
  final mt = base.textTheme;
  final text = mt
      .copyWith(
        displaySmall: serif(34),
        headlineLarge: serif(30),
        headlineMedium: serif(26),
        headlineSmall: serif(22),
        titleLarge: serif(21),
        titleMedium: mt.titleMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
        titleSmall: mt.titleSmall!.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
        labelLarge: mt.labelLarge!.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
        bodyLarge: mt.bodyLarge!.copyWith(fontSize: 16),
        bodyMedium: mt.bodyMedium!.copyWith(fontSize: 14.5),
      )
      .apply(bodyColor: ink, displayColor: ink);

  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

  return base.copyWith(
    scaffoldBackgroundColor: tokens.background,
    textTheme: text,
    extensions: [tokens],
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.background,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: serif(24),
    ),
    cardTheme: CardThemeData(
      color: tokens.card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 70,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12.5,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
          color: s.contains(WidgetState.selected) ? ink : tokens.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? scheme.onPrimaryContainer : tokens.muted),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 2,
      highlightElevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: rounded,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: rounded,
        side: BorderSide(color: tokens.line, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: rounded,
        textStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: tokens.line),
      backgroundColor: tokens.card,
      selectedColor: scheme.primaryContainer,
      labelStyle: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600, color: ink, fontSize: 13.5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF2B2624) : const Color(0xFFF6F0EA),
      hintStyle: TextStyle(color: tokens.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: serif(22),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tokens.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dividerTheme: DividerThemeData(color: tokens.line, thickness: 1),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide(color: tokens.muted, width: 1.5),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: TextStyle(fontFamily: 'Nunito', fontSize: 15.5, fontWeight: FontWeight.w700, color: ink),
      subtitleTextStyle: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: tokens.muted),
      iconColor: tokens.muted,
    ),
  );
}
