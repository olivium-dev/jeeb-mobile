import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';

/// Automated WCAG 2.2 AA contrast gate for the Jeeb color-role system.
/// This is the "audit harness the UX plan calls for" (UX-AUDIT sprint-009
void main() {
  /// WCAG relative-luminance contrast ratio in [1, 21].
  /// `Color.computeLuminance()` implements the WCAG relative-luminance formula.
  double contrast(Color fg, Color bg) {
    final l1 = fg.computeLuminance();
    final l2 = bg.computeLuminance();
    final hi = math.max(l1, l2);
    final lo = math.min(l1, l2);
    return (hi + 0.05) / (lo + 0.05);
  }

  const double aaText = 4.5; // normal-size text minimum

  /// Every text-role pairing that must clear AA, resolved from a built theme.
  /// Keyed by a human-readable name so a failure names the offending pair.
  Map<String, ({Color fg, Color bg})> textPairs(ThemeData theme) {
    final cs = theme.colorScheme;
    final roles = theme.extension<JeebColorRoles>()!;
    return {
      // ── Material 3 core roles (source of truth: ColorScheme) ──────────────
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
      'onError / error': (fg: cs.onError, bg: cs.error),
      // ── Jeeb semantic roles (source of truth: JeebColorRoles) ─────────────
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
    };
  }

  for (final entry in <String, ThemeData>{
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
  }.entries) {
    final themeName = entry.key;
    final theme = entry.value;

    group('WCAG AA contrast — $themeName theme', () {
      textPairs(theme).forEach((name, pair) {
        test('$name >= $aaText to 1', () {
          final ratio = contrast(pair.fg, pair.bg);
          expect(
            ratio,
            greaterThanOrEqualTo(aaText),
            reason: '$themeName "$name" is '
                '${ratio.toStringAsFixed(2)}:1 — below AA $aaText:1',
          );
        });
      });

      test('JeebColorRoles extension is present', () {
        expect(theme.extension<JeebColorRoles>(), isNotNull);
      });
    });
  }

  group('Fixed light-theme offenders (UX-AUDIT §T2/T3 regression guards)', () {
    final light = AppTheme.light();
    final cs = light.colorScheme;

    test('onSurfaceVariant on white surface is AA (the migrated label role)',
        () {
      // Destination/progress labels + saved-address subtitle now use this.
      expect(contrast(cs.onSurfaceVariant, cs.surface),
          greaterThanOrEqualTo(aaText));
    });

    test('the OLD periwinkle-on-white pairing was genuinely failing', () {
      // Documents WHY the migration was needed: onSecondaryContainer over the
      expect(
        contrast(cs.onSecondaryContainer, cs.surface),
        lessThan(aaText),
        reason: 'If this ever passes, onSecondaryContainer changed — re-check '
            'the migrated labels can safely use it on a white surface.',
      );
    });

    test('Open chat tonal pairing (onSurface on surfaceContainerHigh) is AA',
        () {
      expect(contrast(cs.onSurface, cs.surfaceContainerHigh),
          greaterThanOrEqualTo(aaText));
    });

    test('search hint uses onSurfaceVariant on its field surface and is AA',
        () {
      final hintColor = light.inputDecorationTheme.hintStyle?.color;
      expect(hintColor, cs.onSurfaceVariant);
      expect(
        contrast(hintColor!, cs.surfaceContainerHighest),
        greaterThanOrEqualTo(aaText),
        reason: 'OmdsSearchBar paints its hint on surfaceContainerHighest.',
      );
    });
  });
}
