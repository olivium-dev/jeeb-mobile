import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';

/// WCAG 2.2 AA gate for MIDNIGHT (M0-8). The brown-on-white guard is retired
/// with the light theme; hexes are quoted from the sheet, not read back.
void main() {
  /// WCAG relative-luminance contrast ratio in [1, 21].
  double contrast(Color fg, Color bg) {
    final l1 = fg.computeLuminance();
    final l2 = bg.computeLuminance();
    final hi = math.max(l1, l2);
    final lo = math.min(l1, l2);
    return (hi + 0.05) / (lo + 0.05);
  }

  const double aaText = 4.5; // normal-size text minimum
  const double aaLarge = 3.0; // ≥18.66px w400 / ≥14px w700

  // docs/redesign-midnight/01-TOKEN-SHEET.md §1–§3.
  const Color page = Color(0xFF070C33);
  const Color surface = Color(0xFF0B1351);
  const Color surfaceHigh = Color(0xFF10175E);
  const Color surfaceHighest = Color(0xFF151C69);
  const Color ink = Color(0xFFEDEFFC);
  const Color inkMuted = Color(0xFF8A93D8);
  const Color inkSoft = Color(0xFFB9C0F0);
  const Color orange = Color(0xFFD73B00);
  const Color white = Color(0xFFFFFFFF);
  const Color danger = Color(0xFFFF5252);
  const Color dangerSoft = Color(0xFFFF7B7B);
  const Color dangerContainer = Color(0xFF4A1220);
  const Color success = Color(0xFF3BB273);
  const Color successSoft = Color(0xFF7BD9A4);
  const Color successContainer = Color(0xFF0E3B2C);
  const Color amber = Color(0xFFFFC107);
  const Color amberSoft = Color(0xFFFFDF9E);
  const Color amberContainer = Color(0xFF4A3200);
  const Color onAmber = Color(0xFF3B2600);
  const Color orangeTint = Color(0xFFFFB499);
  const Color orangeContainer = Color(0xFF431505);

  final ThemeData theme = AppTheme.midnight();
  final ColorScheme cs = theme.colorScheme;
  final JeebColorRoles roles = theme.extension<JeebColorRoles>()!;
  final JeebSemanticColors semantic = theme.extension<JeebSemanticColors>()!;

  group('the built theme IS the ratified sheet', () {
    final Map<String, ({Color actual, Color expected})> bindings = {
      'colorScheme.primary': (actual: cs.primary, expected: orange),
      'colorScheme.onPrimary': (actual: cs.onPrimary, expected: white),
      'colorScheme.primaryContainer': (
        actual: cs.primaryContainer,
        expected: orangeContainer
      ),
      'colorScheme.onPrimaryContainer': (
        actual: cs.onPrimaryContainer,
        expected: orangeTint
      ),
      'colorScheme.secondary': (actual: cs.secondary, expected: inkMuted),
      'colorScheme.onSecondary': (actual: cs.onSecondary, expected: page),
      'colorScheme.secondaryContainer': (
        actual: cs.secondaryContainer,
        expected: surfaceHigh
      ),
      'colorScheme.onSecondaryContainer': (
        actual: cs.onSecondaryContainer,
        expected: inkSoft
      ),
      'colorScheme.tertiary (compat alias of primary)': (
        actual: cs.tertiary,
        expected: orange
      ),
      'colorScheme.surface': (actual: cs.surface, expected: surface),
      'colorScheme.onSurface': (actual: cs.onSurface, expected: ink),
      'colorScheme.onSurfaceVariant': (
        actual: cs.onSurfaceVariant,
        expected: inkMuted
      ),
      'colorScheme.surfaceContainerLowest': (
        actual: cs.surfaceContainerLowest,
        expected: page
      ),
      'colorScheme.surfaceContainerLow': (
        actual: cs.surfaceContainerLow,
        expected: const Color(0xFF0A1147)
      ),
      'colorScheme.surfaceContainer': (
        actual: cs.surfaceContainer,
        expected: surface
      ),
      'colorScheme.surfaceContainerHigh': (
        actual: cs.surfaceContainerHigh,
        expected: surfaceHigh
      ),
      'colorScheme.surfaceContainerHighest': (
        actual: cs.surfaceContainerHighest,
        expected: surfaceHighest
      ),
      'colorScheme.error': (actual: cs.error, expected: danger),
      'colorScheme.onError': (actual: cs.onError, expected: page),
      'colorScheme.errorContainer': (
        actual: cs.errorContainer,
        expected: dangerContainer
      ),
      'colorScheme.onErrorContainer': (
        actual: cs.onErrorContainer,
        expected: dangerSoft
      ),
      'colorScheme.outline (white 14%)': (
        actual: cs.outline,
        expected: const Color(0x24FFFFFF)
      ),
      'colorScheme.outlineVariant (white 12%)': (
        actual: cs.outlineVariant,
        expected: const Color(0x1FFFFFFF)
      ),
      'roles.success': (actual: roles.success, expected: success),
      'roles.onSuccess': (actual: roles.onSuccess, expected: page),
      'roles.warning': (actual: roles.warning, expected: amber),
      'roles.onWarning': (actual: roles.onWarning, expected: onAmber),
      'roles.info': (actual: roles.info, expected: inkMuted),
      'roles.onInfo': (actual: roles.onInfo, expected: page),
      'roles.accent': (actual: roles.accent, expected: orange),
      'roles.onAccent': (actual: roles.onAccent, expected: white),
      'semantic.mutedText': (actual: semantic.mutedText, expected: inkMuted),
      'semantic.inkSoft': (actual: semantic.inkSoft, expected: inkSoft),
      'semantic.amber': (actual: semantic.amber, expected: amber),
      'semantic.mutedSurface': (
        actual: semantic.mutedSurface,
        expected: surfaceHigh
      ),
    };

    bindings.forEach((name, b) {
      test(name, () => expect(b.actual, b.expected));
    });

    test('surfaceTint is transparent (M3 elevation tinting is OFF)', () {
      expect(cs.surfaceTint, Colors.transparent);
    });

    test('scaffoldBackgroundColor is the page navy, not the card navy', () {
      expect(theme.scaffoldBackgroundColor, page);
    });

    test('canvas and card colors are the card navy', () {
      expect(theme.canvasColor, surface);
      expect(theme.cardColor, surface);
    });

    test('every surface slot is genuinely dark', () {
      final Map<String, Color> surfaces = {
        'surface': cs.surface,
        'surfaceDim': cs.surfaceDim,
        'surfaceBright': cs.surfaceBright,
        'surfaceContainerLowest': cs.surfaceContainerLowest,
        'surfaceContainerLow': cs.surfaceContainerLow,
        'surfaceContainer': cs.surfaceContainer,
        'surfaceContainerHigh': cs.surfaceContainerHigh,
        'surfaceContainerHighest': cs.surfaceContainerHighest,
        'scaffoldBackgroundColor': theme.scaffoldBackgroundColor,
        'canvasColor': theme.canvasColor,
        'cardColor': theme.cardColor,
      };
      surfaces.forEach((name, color) {
        expect(
          color.computeLuminance(),
          lessThan(0.05),
          reason: '$name is not a Midnight surface — luminance '
              '${color.computeLuminance().toStringAsFixed(3)}',
        );
      });
    });

    test('the retired inks are gone from the scheme and the roles', () {
      // §10. Legacy periwinkle survives ONLY as a JeebMidnightField glow wash.
      const List<Color> retired = <Color>[
        Color(0xFF777FC0), // legacy periwinkle as ink
        Color(0xFF9DA3E0), // pass-1 dark muted
        Color(0xFF916F66), // brown outline
        Color(0xFF5C4038), // brown subtitle
        Color(0xFF0B0E53), // light-era navy ink
      ];
      final List<Color> live = <Color>[
        cs.primary, cs.onPrimary, cs.secondary, cs.onSecondary,
        cs.surface, cs.onSurface, cs.onSurfaceVariant,
        cs.outline, cs.outlineVariant, cs.error, cs.onError,
        roles.success, roles.warning, roles.info, roles.accent,
        semantic.mutedText, semantic.inkSoft,
      ];
      for (final Color dead in retired) {
        expect(
          live,
          isNot(contains(dead)),
          reason: '${dead.toARGB32().toRadixString(16)} is retired (sheet §10)',
        );
      }
    });

    test('light() and dark() are the same Midnight theme', () {
      expect(AppTheme.light().colorScheme, AppTheme.dark().colorScheme);
      expect(AppTheme.light().colorScheme, cs);
      expect(AppTheme.light().scaffoldBackgroundColor, page);
      expect(AppTheme.light().brightness, Brightness.dark);
    });
  });

  group('WCAG AA — Material 3 role pairs', () {
    final Map<String, ({Color fg, Color bg})> pairs = {
      'onPrimary / primary': (fg: cs.onPrimary, bg: cs.primary),
      'onPrimaryContainer / primaryContainer': (
        fg: cs.onPrimaryContainer,
        bg: cs.primaryContainer
      ),
      'onSecondary / secondary': (fg: cs.onSecondary, bg: cs.secondary),
      'onSecondaryContainer / secondaryContainer': (
        fg: cs.onSecondaryContainer,
        bg: cs.secondaryContainer
      ),
      'onTertiary / tertiary': (fg: cs.onTertiary, bg: cs.tertiary),
      'onSurface / surface': (fg: cs.onSurface, bg: cs.surface),
      'onSurfaceVariant / surface': (fg: cs.onSurfaceVariant, bg: cs.surface),
      'onSurface / surfaceContainerHigh': (
        fg: cs.onSurface,
        bg: cs.surfaceContainerHigh
      ),
      'onSurfaceVariant / surfaceContainerHighest': (
        fg: cs.onSurfaceVariant,
        bg: cs.surfaceContainerHighest
      ),
      'onError / error': (fg: cs.onError, bg: cs.error),
      'onErrorContainer / errorContainer': (
        fg: cs.onErrorContainer,
        bg: cs.errorContainer
      ),
    };

    pairs.forEach((name, pair) {
      test('$name >= $aaText to 1', () {
        final ratio = contrast(pair.fg, pair.bg);
        expect(
          ratio,
          greaterThanOrEqualTo(aaText),
          reason:
              '"$name" is ${ratio.toStringAsFixed(2)}:1 — below AA $aaText:1',
        );
      });
    });
  });

  group('WCAG AA — Jeeb semantic role pairs', () {
    final Map<String, ({Color fg, Color bg})> pairs = {
      // `onSuccess`/`onInfo` are page-navy: white on those solids fails AA.
      'onSuccess / success': (fg: roles.onSuccess, bg: roles.success),
      'onSuccessContainer / successContainer': (
        fg: roles.onSuccessContainer,
        bg: roles.successContainer
      ),
      'onWarning / warning': (fg: roles.onWarning, bg: roles.warning),
      'onWarningContainer / warningContainer': (
        fg: roles.onWarningContainer,
        bg: roles.warningContainer
      ),
      'onInfo / info': (fg: roles.onInfo, bg: roles.info),
      'onInfoContainer / infoContainer': (
        fg: roles.onInfoContainer,
        bg: roles.infoContainer
      ),
      // Clears AA by 0.15 — re-tone the orange and this fails first.
      'onAccent / accent': (fg: roles.onAccent, bg: roles.accent),
      'onAccentContainer / accentContainer': (
        fg: roles.onAccentContainer,
        bg: roles.accentContainer
      ),
    };

    pairs.forEach((name, pair) {
      test('$name >= $aaText to 1', () {
        final ratio = contrast(pair.fg, pair.bg);
        expect(
          ratio,
          greaterThanOrEqualTo(aaText),
          reason:
              '"$name" is ${ratio.toStringAsFixed(2)}:1 — below AA $aaText:1',
        );
      });
    });
  });

  group('WCAG AA — the §9 ink-on-navy matrix', () {
    // Real screens mix these freely; M3 only names a subset of them.
    final Map<String, ({Color fg, Color bg})> pairs = {
      'ink on page': (fg: ink, bg: page),
      'ink on surface': (fg: ink, bg: surface),
      'ink on surfaceHigh': (fg: ink, bg: surfaceHigh),
      'ink on surfaceHighest': (fg: ink, bg: surfaceHighest),
      'inkMuted on page': (fg: inkMuted, bg: page),
      'inkMuted on surface': (fg: inkMuted, bg: surface),
      'inkMuted on surfaceHigh': (fg: inkMuted, bg: surfaceHigh),
      'inkMuted on surfaceHighest': (fg: inkMuted, bg: surfaceHighest),
      'inkSoft on page': (fg: inkSoft, bg: page),
      'inkSoft on surface': (fg: inkSoft, bg: surface),
      'inkSoft on surfaceHigh': (fg: inkSoft, bg: surfaceHigh),
      'inkSoft on surfaceHighest': (fg: inkSoft, bg: surfaceHighest),
      'white on orange': (fg: white, bg: orange),
      'page on danger': (fg: page, bg: danger),
      'page on success': (fg: page, bg: success),
      'page on amber': (fg: page, bg: amber),
      'page on inkMuted': (fg: page, bg: inkMuted),
      'dangerSoft on dangerContainer': (fg: dangerSoft, bg: dangerContainer),
      'successSoft on successContainer': (
        fg: successSoft,
        bg: successContainer
      ),
      'amberSoft on amberContainer': (fg: amberSoft, bg: amberContainer),
      'orangeTint on orangeContainer': (fg: orangeTint, bg: orangeContainer),
    };

    pairs.forEach((name, pair) {
      test('$name >= $aaText to 1', () {
        final ratio = contrast(pair.fg, pair.bg);
        expect(
          ratio,
          greaterThanOrEqualTo(aaText),
          reason: '"$name" is ${ratio.toStringAsFixed(2)}:1 — below AA '
              '$aaText:1. Per sheet §9 the FIX IS NOT to shift the hex: mark '
              'the pair large-text-only ($aaLarge:1) and mirror what the board '
              'does with it.',
        );
      });
    });

    test('the muted ink clears the body-text bar on the darkest card', () {
      // §9's one at-risk pair: 5.17:1 lightest navy, 6.53:1 on the page.
      expect(contrast(inkMuted, surfaceHighest), greaterThan(5.0));
      expect(contrast(inkMuted, page), greaterThan(6.0));
    });

    test('white on danger is NOT used as ink — it fails AA', () {
      expect(contrast(white, danger), lessThan(aaText));
      expect(contrast(page, danger), greaterThanOrEqualTo(aaText));
    });

    test('white on success/periwinkle is NOT used as ink — it fails AA', () {
      expect(contrast(white, success), lessThan(aaText));
      expect(contrast(white, inkMuted), lessThan(aaText));
    });
  });

  group('the gate itself', () {
    test('JeebColorRoles extension is present', () {
      expect(theme.extension<JeebColorRoles>(), isNotNull);
    });

    test('JeebSemanticColors extension is present', () {
      expect(theme.extension<JeebSemanticColors>(), isNotNull);
    });

    test('the contrast formula is calibrated', () {
      // A gate that computes contrast wrongly passes everything.
      expect(contrast(ink, ink), closeTo(1, 0.001));
      expect(
        contrast(const Color(0xFF000000), white),
        closeTo(21, 0.001),
      );
    });
  });
}
