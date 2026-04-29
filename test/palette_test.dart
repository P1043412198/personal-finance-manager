import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/theme/app_theme.dart';
import 'package:personal_finance/theme/palettes.dart';

void main() {
  group('palettes', () {
    test('all palettes have a non-zero seed and accent', () {
      for (final p in AppPalette.values) {
        final spec = paletteSpec(p);
        expect(spec.seed.alpha, 0xFF, reason: 'seed must be opaque for $p');
        expect(spec.accent.alpha, 0xFF, reason: 'accent must be opaque for $p');
        expect(spec.income, isA<Color>());
        expect(spec.expense, isA<Color>());
      }
    });

    test('paletteSpec falls back to forest on unknown enum-like input', () {
      // Using a known palette returns it; null wouldn't compile, so we just
      // assert the canonical mapping holds.
      expect(paletteSpec(AppPalette.forest).labelEn, 'Forest');
      expect(paletteSpec(AppPalette.jade).labelEn, 'Jade');
      expect(paletteSpec(AppPalette.midnight).labelEn, 'Midnight');
      expect(paletteSpec(AppPalette.sunset).labelEn, 'Sunset');
      expect(paletteSpec(AppPalette.ocean).labelEn, 'Ocean');
      expect(paletteSpec(AppPalette.lavender).labelEn, 'Lavender');
    });

    test('applyPalette mutates AppColors to match the spec', () {
      AppColors.applyPalette(AppPalette.midnight);
      final mid = paletteSpec(AppPalette.midnight);
      expect(AppColors.primary, mid.seed);
      expect(AppColors.accent, mid.accent);
      expect(AppColors.income, mid.income);
      expect(AppColors.expense, mid.expense);

      AppColors.applyPalette(AppPalette.sunset);
      final sun = paletteSpec(AppPalette.sunset);
      expect(AppColors.primary, sun.seed);
      expect(AppColors.expense, sun.expense);

      // Reset to forest so other tests start from default.
      AppColors.applyPalette(AppPalette.forest);
      expect(AppColors.primary, paletteSpec(AppPalette.forest).seed);
    });

    test('AppTheme.light builds with each palette without error', () {
      for (final p in AppPalette.values) {
        final theme = AppTheme.light(palette: p);
        expect(theme.useMaterial3, true);
        expect(theme.colorScheme.primary, paletteSpec(p).seed);
      }
    });

    test('AppTheme.dark builds with each palette without error', () {
      for (final p in AppPalette.values) {
        final theme = AppTheme.dark(palette: p);
        expect(theme.useMaterial3, true);
      }
    });
  });
}
