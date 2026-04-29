import 'package:flutter/material.dart';

/// User-selectable color palette. Each palette maps to a seed color used by
/// Material 3 [ColorScheme.fromSeed], plus a few accent colors that are
/// overlaid on top of M3-generated tones.
enum AppPalette {
  forest,
  jade,
  midnight,
  sunset,
  ocean,
  lavender,
}

class PaletteSpec {
  final AppPalette id;
  final String labelRu;
  final String labelEn;
  final Color seed;
  final Color accent;
  final Color income;
  final Color expense;
  final Color warning;
  final Color danger;

  const PaletteSpec({
    required this.id,
    required this.labelRu,
    required this.labelEn,
    required this.seed,
    required this.accent,
    required this.income,
    required this.expense,
    required this.warning,
    required this.danger,
  });
}

const Map<AppPalette, PaletteSpec> kPalettes = {
  AppPalette.forest: PaletteSpec(
    id: AppPalette.forest,
    labelRu: 'Лес',
    labelEn: 'Forest',
    seed: Color(0xFF2E7D32),
    accent: Color(0xFF66BB6A),
    income: Color(0xFF2E7D32),
    expense: Color(0xFFE53935),
    warning: Color(0xFFF9A825),
    danger: Color(0xFFD32F2F),
  ),
  AppPalette.jade: PaletteSpec(
    id: AppPalette.jade,
    labelRu: 'Нефрит',
    labelEn: 'Jade',
    seed: Color(0xFF00897B),
    accent: Color(0xFF26A69A),
    income: Color(0xFF00897B),
    expense: Color(0xFFE64A19),
    warning: Color(0xFFFFB300),
    danger: Color(0xFFC62828),
  ),
  AppPalette.midnight: PaletteSpec(
    id: AppPalette.midnight,
    labelRu: 'Полночь',
    labelEn: 'Midnight',
    seed: Color(0xFF3949AB),
    accent: Color(0xFF5C6BC0),
    income: Color(0xFF43A047),
    expense: Color(0xFFEF5350),
    warning: Color(0xFFFFA726),
    danger: Color(0xFFD32F2F),
  ),
  AppPalette.sunset: PaletteSpec(
    id: AppPalette.sunset,
    labelRu: 'Закат',
    labelEn: 'Sunset',
    seed: Color(0xFFE64A19),
    accent: Color(0xFFFF7043),
    income: Color(0xFF388E3C),
    expense: Color(0xFFC62828),
    warning: Color(0xFFFFB300),
    danger: Color(0xFFC62828),
  ),
  AppPalette.ocean: PaletteSpec(
    id: AppPalette.ocean,
    labelRu: 'Океан',
    labelEn: 'Ocean',
    seed: Color(0xFF0277BD),
    accent: Color(0xFF29B6F6),
    income: Color(0xFF26A69A),
    expense: Color(0xFFD84315),
    warning: Color(0xFFF57C00),
    danger: Color(0xFFC62828),
  ),
  AppPalette.lavender: PaletteSpec(
    id: AppPalette.lavender,
    labelRu: 'Лаванда',
    labelEn: 'Lavender',
    seed: Color(0xFF7B1FA2),
    accent: Color(0xFFAB47BC),
    income: Color(0xFF388E3C),
    expense: Color(0xFFD81B60),
    warning: Color(0xFFFFA726),
    danger: Color(0xFFC62828),
  ),
};

PaletteSpec paletteSpec(AppPalette p) => kPalettes[p] ?? kPalettes[AppPalette.forest]!;
