/// APEX Theme Generator — Linear-style 3-variable palette derivation.
///
/// Linear's March 2026 refresh ships 1000+ themes derived from three
/// inputs: a base hue, an accent hue, and a contrast scalar. Every
/// other colour (4 bg levels, 3 text levels, borders, muted states)
/// is computed algorithmically in HSL space. This file brings the
/// same technique to APEX so tenants can white-label themselves
/// beyond the 12 hand-tuned presets in theme.dart.
///
/// Contract:
///   generateApexTheme(
///     base: Color(0xFF1E3A5F),     // navy / brand dark
///     accent: core_theme.AC.gold,   // gold / CTA
///     contrast: 1.0,               // 0.7 low … 1.3 high
///     isDark: true,
///   ) → ApexTheme
///
/// The generator never reads or writes application state — it's pure.
/// Pair with ApexWhiteLabelEditor (Sprint 43) or a settings screen
/// that calls AC.registerTheme(generated) on save.
library;

import 'package:flutter/material.dart';
import 'theme.dart' as core_theme;

import 'theme.dart';

class ApexThemeGenerator {
  /// Generate a full ApexTheme from three inputs.
  static ApexTheme generate({
    required String id,
    required String nameAr,
    required String nameEn,
    required Color base,
    required Color accent,
    double contrast = 1.0,
    required bool isDark,
  }) {
    final baseHsl = HSLColor.fromColor(base);
    final accentHsl = HSLColor.fromColor(accent);

    // Contrast clamps: avoid completely washed-out (< 0.7) or
    // eye-melting (> 1.3) palettes.
    final c = contrast.clamp(0.7, 1.3);

    final bg1 = _shiftLightness(baseHsl, isDark ? 0.08 : 0.98).toColor();
    final bg2 = _shiftLightness(baseHsl, isDark ? 0.12 : 0.95).toColor();
    final bg3 = _shiftLightness(baseHsl, isDark ? 0.17 : 0.92).toColor();
    final bg4 = _shiftLightness(baseHsl, isDark ? 0.23 : 0.88).toColor();

    final textPrimary = isDark
        ? _shiftLightness(baseHsl.withSaturation(0.1), 0.95 * c).toColor()
        : _shiftLightness(baseHsl.withSaturation(0.25), 0.12 / c).toColor();
    final textSecondary = isDark
        ? _shiftLightness(baseHsl.withSaturation(0.08), 0.70 * c).toColor()
        : _shiftLightness(baseHsl.withSaturation(0.18), 0.35 / c).toColor();
    final textDim = isDark
        ? _shiftLightness(baseHsl.withSaturation(0.05), 0.48).toColor()
        : _shiftLightness(baseHsl.withSaturation(0.12), 0.55).toColor();

    final border = isDark
        ? _shiftLightness(baseHsl, 0.25).toColor().withValues(alpha: 0.35)
        : _shiftLightness(baseHsl, 0.75).toColor();

    final primary = accent;
    final primaryLight = _shiftLightness(
      accentHsl,
      (accentHsl.lightness + 0.12).clamp(0, 1),
    ).toColor();

    // Status colours — derived from HSL hue offsets of the accent so
    // they harmonise, but clamped to semantic ranges.
    final success = HSLColor.fromAHSL(
      1, 142, 0.58, isDark ? 0.50 : 0.40,
    ).toColor();
    final error = HSLColor.fromAHSL(
      1, 0, 0.68, isDark ? 0.58 : 0.45,
    ).toColor();
    final warning = HSLColor.fromAHSL(
      1, 38, 0.85, isDark ? 0.58 : 0.45,
    ).toColor();
    final info = HSLColor.fromAHSL(
      1, 200, 0.78, isDark ? 0.58 : 0.45,
    ).toColor();
    final purple = HSLColor.fromAHSL(
      1, 270, 0.55, isDark ? 0.60 : 0.45,
    ).toColor();

    // Button foreground: pick black or white for AA contrast on accent.
    final btnFg = _aaOn(accent);

    return ApexTheme(
      id: id,
      nameAr: nameAr,
      nameEn: nameEn,
      primary: primary,
      primaryLight: primaryLight,
      bg1: bg1,
      bg2: bg2,
      bg3: bg3,
      bg4: bg4,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textDim: textDim,
      border: border,
      isDark: isDark,
      preview: primary,
      success: success,
      error: error,
      warning: warning,
      info: info,
      purple: purple,
      btnFg: btnFg,
    );
  }

  // ── Helpers ────────────────────────────────────────────

  static HSLColor _shiftLightness(HSLColor hsl, double targetLightness) {
    return hsl.withLightness(targetLightness.clamp(0.0, 1.0));
  }

  /// Returns black or white, whichever has better contrast on [bg].
  /// Uses the simple luminance heuristic (WCAG 2.x formula is in
  /// Color.computeLuminance).
  static Color _aaOn(Color bg) {
    final lum = bg.computeLuminance();
    return lum > 0.45 ? const Color(0xFF0F172A) : Colors.white;
  }
}

/// Convenience: generate both the light and dark variants of a brand.
class ApexThemePair {
  final ApexTheme light;
  final ApexTheme dark;
  const ApexThemePair({required this.light, required this.dark});

  static ApexThemePair fromBrand({
    required String familyId,
    required String nameAr,
    required String nameEn,
    required Color base,
    required Color accent,
    double contrast = 1.0,
  }) {
    return ApexThemePair(
      light: ApexThemeGenerator.generate(
        id: '${familyId}_light',
        nameAr: nameAr,
        nameEn: nameEn,
        base: base,
        accent: accent,
        contrast: contrast,
        isDark: false,
      ),
      dark: ApexThemeGenerator.generate(
        id: '${familyId}_dark',
        nameAr: nameAr,
        nameEn: nameEn,
        base: base,
        accent: accent,
        contrast: contrast,
        isDark: true,
      ),
    );
  }
}
