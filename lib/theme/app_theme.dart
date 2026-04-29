import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF2E7D32);
  static const primaryLight = Color(0xFF60AD5E);
  static const primaryDark = Color(0xFF005005);
  static const accent = Color(0xFF66BB6A);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF7F8F7);
  static const cardBg = Color(0xFFFFFFFF);
  static const muted = Color(0xFFEFF3EE);
  static const textPrimary = Color(0xFF1B1F1B);
  static const textSecondary = Color(0xFF6C7470);
  static const danger = Color(0xFFD32F2F);
  static const warning = Color(0xFFF9A825);
  static const info = Color(0xFF1976D2);
  static const expense = Color(0xFFE53935);
  static const income = Color(0xFF2E7D32);
}

class AppPalette {
  final String key;
  final String label;
  final Color seed;
  final Color lightBg;
  final Color darkBg;
  final Color muted;
  const AppPalette({
    required this.key,
    required this.label,
    required this.seed,
    required this.lightBg,
    required this.darkBg,
    required this.muted,
  });
}

const kPalettes = <AppPalette>[
  AppPalette(key: 'green', label: 'Green', seed: Color(0xFF2E7D32),
    lightBg: Color(0xFFF7F8F7), darkBg: Color(0xFF101410), muted: Color(0xFFEFF3EE)),
  AppPalette(key: 'blue', label: 'Blue', seed: Color(0xFF1565C0),
    lightBg: Color(0xFFF6F8FB), darkBg: Color(0xFF0E141C), muted: Color(0xFFE9EFF7)),
  AppPalette(key: 'purple', label: 'Purple', seed: Color(0xFF6A1B9A),
    lightBg: Color(0xFFFAF7FB), darkBg: Color(0xFF160E1A), muted: Color(0xFFF1EAF5)),
  AppPalette(key: 'orange', label: 'Orange', seed: Color(0xFFE65100),
    lightBg: Color(0xFFFCF8F4), darkBg: Color(0xFF1A130C), muted: Color(0xFFF7EDDF)),
  AppPalette(key: 'pink', label: 'Pink', seed: Color(0xFFC2185B),
    lightBg: Color(0xFFFCF6F8), darkBg: Color(0xFF1A0E14), muted: Color(0xFFF7E8EE)),
  AppPalette(key: 'teal', label: 'Teal', seed: Color(0xFF00796B),
    lightBg: Color(0xFFF4FAF8), darkBg: Color(0xFF0B1614), muted: Color(0xFFE3F1EC)),
];

AppPalette paletteByKey(String key) =>
    kPalettes.firstWhere((p) => p.key == key, orElse: () => kPalettes.first);

class AppTheme {
  static ThemeData light({String paletteKey = 'green', ColorScheme? dynamicScheme}) {
    final p = paletteByKey(paletteKey);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: dynamicScheme ?? ColorScheme.fromSeed(
        seedColor: p.seed,
        brightness: Brightness.light,
        primary: p.seed,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: p.lightBg,
      fontFamily: 'Roboto',
    );
    return base.copyWith(
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadowColor: Colors.black.withOpacity(0.04),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.seed,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.seed,
          minimumSize: const Size(double.infinity, 52),
          side: BorderSide(color: p.seed, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.seed,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.seed, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.muted,
        selectedColor: p.seed,
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFEFEFEF), thickness: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: p.seed,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 8,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        height: 68,
        indicatorColor: p.muted,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.seed,
        foregroundColor: Colors.white,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
    );
  }

  static ThemeData dark({String paletteKey = 'green', ColorScheme? dynamicScheme, bool amoled = false}) {
    final p = paletteByKey(paletteKey);
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: dynamicScheme ?? ColorScheme.fromSeed(
        seedColor: p.seed,
        brightness: Brightness.dark,
      ),
    );
    final bg = amoled ? Colors.black : p.darkBg;
    final cardBg = amoled ? const Color(0xFF0A0A0A) : const Color(0xFF1B201B);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.seed,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.seed,
        foregroundColor: Colors.white,
      ),
    );
  }
}
