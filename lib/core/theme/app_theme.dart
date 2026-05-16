import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:omds/omds.dart';

import 'jeeb_tier_colors.dart';

/// Jeeb app theme — thin wrapper around [OmdsTheme] with the Jeeb brand seed
/// and the [JeebTierColors] extension layered on.
///
/// All theming flows through `package:omds` so raw Material widget defaults
/// stay outside the app and any future OMDS-wide token change reaches Jeeb
/// automatically.
///
/// Source-of-truth for color decisions: `docs/design/03-color-token-mapping.md`.
/// Source-of-truth for typography: `docs/design/04-typography-validation.md`.
class AppTheme {
  AppTheme._();

  // ─── Brand seed (see 03-color-token-mapping.md §1) ─────────────────────────
  static const Color _primarySeed = Color(0xFF1B6B4E);
  static const Color _secondarySeed = Color(0xFF4A6741);
  static const Color _tertiarySeed = Color(0xFF3D6373);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primarySeed,
      secondary: _secondarySeed,
      tertiary: _tertiarySeed,
      brightness: brightness,
    );

    final baseTextTheme = brightness == Brightness.dark
        ? GoogleFonts.interTextTheme(
            ThemeData(brightness: Brightness.dark).textTheme,
          )
        : GoogleFonts.interTextTheme();

    final omds = OmdsTheme(baseTextTheme);
    final base = brightness == Brightness.dark
        ? omds.darkWithScheme(colorScheme)
        : omds.lightWithScheme(colorScheme);

    // Type-erase the iterable before passing to copyWith. `copyWith` takes
    // `Iterable<ThemeExtension<dynamic>>`, but Dart's stricter generic
    // inference around `ThemeExtension<T extends ThemeExtension<T>>` causes
    // the unparameterised `<ThemeExtension<dynamic>>[...]` literal to coerce
    // into `ThemeExtension<ThemeExtension<dynamic>>` at runtime, which then
    // rejects `_CompactValuesIterable<ThemeExtension<dynamic>>` (the type of
    // `base.extensions.values`). Materialising into an explicit
    // `List<ThemeExtension<dynamic>>` via `<dynamic>[].cast<...>()` keeps the
    // outer parameter open and lets the framework's internal cast widen.
    final List<ThemeExtension<dynamic>> extensions = <dynamic>[
      JeebTierColors.standard(),
      ...base.extensions.values,
    ].cast<ThemeExtension<dynamic>>();
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(centerTitle: true),
      extensions: extensions,
    );
  }
}
