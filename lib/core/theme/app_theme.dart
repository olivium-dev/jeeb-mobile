import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omds/omds.dart';

import 'jeeb_color_roles.dart';
import 'jeeb_semantic_colors.dart';
import 'jeeb_tier_colors.dart';

/// Jeeb app theme derived from the Figma design (ZOi3kKtw7sd42ssSVX3Kn4).
///
/// Brand palette extracted from Figma node 56535:1525:
///   - Primary / secondary-container: deep navy `#0B1351`
///   - Primary-container / progress bars: vibrant orange `#D73B00`
///   - On-secondary-container (muted text): `#777FC0`
///   - Outline (chip borders): warm brown `#916F66`
///   - On-surface-variant (subtitle text): `#5C4038`
///   - Surface-container-high (search bg): `#EAE7EB`
///   - On-primary: `#FFFFFF`
///
/// Typography note: the Figma calls for Roboto (body) and Urbanist (nav
/// labels), but we override to **Inter** per OMDS standard (audit doc §5.1).
/// Inter is bundled locally as discrete static instances (Regular/Medium/
/// SemiBold/Bold, OFL-1.1; see pubspec.yaml + test/inter_font_weight_test.dart)
/// and applied as a normal Flutter font family — NOT fetched at runtime via
/// `google_fonts`. Runtime fetching throws a `HandshakeException` on a
/// no-egress device (no path to `fonts.gstatic.com`), which crashed the theme
/// build on first frame; the bundled font makes every branded screen render
/// offline. `Bootstrap.minimal` additionally disables any residual
/// `google_fonts` runtime fetch as defence-in-depth. See
/// `flutter-material3-colorscheme-discipline` + `flutter-env-dart-define`.
///
/// This file is the **single source of truth** for the Jeeb palette. The
/// brand seeds are intentionally `private` (`_jeebNavy` etc.) so feature
/// code cannot reach in and bypass the `ColorScheme` / `OmdsColorTokens` /
/// `JeebSemanticColors` boundary. If you need a brand color in a feature,
/// resolve it via:
///
///   1. `Theme.of(context).colorScheme.<role>` (M3 roles)
///   2. `context.omdsColorTokens.<token>` (semantic OMDS tokens)
///   3. `Theme.of(context).extension<JeebSemanticColors>()!.<role>`
///   4. `Theme.of(context).extension<JeebTierColors>()!.<tier>`
class AppTheme {
  AppTheme._();

  /// Bundled-Inter family name. Must match the `family:` declared under
  /// `flutter > fonts` in `pubspec.yaml`.
  static const String _fontFamily = 'Inter';

  // ───────────────────────────────────────────────────────────────────────
  // Private brand seeds — only consumed by the ColorScheme below.
  // Never exposed publicly; do not promote without architectural review.
  // ───────────────────────────────────────────────────────────────────────

  static const Color _jeebNavy = Color(0xFF0B1351);
  static const Color _jeebOrange = Color(0xFFD73B00);
  static const Color _jeebMutedPurple = Color(0xFF777FC0);
  static const Color _jeebWarmBrown = Color(0xFF916F66);
  static const Color _jeebSubtitle = Color(0xFF5C4038);
  static const Color _jeebSurfaceHigh = Color(0xFFEAE7EB);
  static const Color _jeebSurfaceHighest = Color(0xFFE5E1E5);

  /// On-surface ink for body text in the light Jeeb scheme. Deep blue tuned
  /// to read against the warm white surface; not the same as `_jeebNavy`.
  static const Color _jeebOnSurface = Color(0xFF0B0E53);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final colorScheme = isLight
        ? const ColorScheme.light(
            primary: _jeebNavy,
            onPrimary: Colors.white,
            primaryContainer: _jeebOrange,
            onPrimaryContainer: Colors.white,
            secondary: _jeebNavy,
            onSecondary: Colors.white,
            secondaryContainer: _jeebNavy,
            onSecondaryContainer: _jeebMutedPurple,
            tertiary: _jeebOrange,
            onTertiary: Colors.white,
            surface: Colors.white,
            onSurface: _jeebOnSurface,
            onSurfaceVariant: _jeebSubtitle,
            outline: _jeebWarmBrown,
            outlineVariant: _jeebSurfaceHighest,
            surfaceContainerHighest: _jeebSurfaceHighest,
            surfaceContainerHigh: _jeebSurfaceHigh,
          )
        : ColorScheme.fromSeed(
            seedColor: _jeebNavy,
            brightness: Brightness.dark,
          );

    final baseTextTheme = _interTextTheme(
      isLight ? ThemeData.light().textTheme : ThemeData.dark().textTheme,
    );

    final omds = OmdsTheme(baseTextTheme);
    final base = isLight
        ? omds.lightWithScheme(colorScheme)
        : omds.darkWithScheme(colorScheme);

    final List<ThemeExtension<dynamic>> extensions = <dynamic>[
      JeebTierColors.standard(),
      isLight ? JeebSemanticColors.light() : JeebSemanticColors.dark(),
      // The single semantic color-role layer (success/warning/info). M3 roles
      // stay in `colorScheme`; this only adds the roles M3 omits. Read via
      // `context.jeebRoles`. Contrast-gated in color_role_contrast_test.dart.
      isLight ? JeebColorRoles.light() : JeebColorRoles.dark(),
      ...base.extensions.values,
    ].cast<ThemeExtension<dynamic>>();

    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
        elevation: 0,
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              ),
      ),
      scaffoldBackgroundColor: isLight ? colorScheme.surface : null,
      chipTheme: ChipThemeData(
        selectedColor: colorScheme.primary,
        labelStyle: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: OmdsBorderRadius.xSmall,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        // Allowed: `Colors.transparent` is the documented exemption for
        // hit-testing / overlay intent that has no semantic equivalent.
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return baseTextTheme.labelSmall?.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.2,
            color: isSelected ? colorScheme.primary : colorScheme.outline,
          );
        }),
      ),
      extensions: extensions,
    );
  }

  /// Applies the bundled [Inter] family to every style in [base].
  ///
  /// Drop-in replacement for `GoogleFonts.interTextTheme(base)` that resolves
  /// the font from local assets only — no network, so it cannot throw a
  /// `HandshakeException` on a no-egress device. When a glyph is missing from
  /// Inter, Flutter falls back to the platform font automatically.
  static TextTheme _interTextTheme(TextTheme base) =>
      base.apply(fontFamily: _fontFamily);
}
