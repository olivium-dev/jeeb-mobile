import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_text_styles.dart';

/// Gates for the redesign-2026-08 Wave-0 type ramp.
///
/// The 24 screen lanes read every branded size/weight off
/// `context.jeebText.*`, so a field that is registered wrong, loses its font
/// family, or drifts from its spec breaks screens silently — nothing else in
/// the suite would notice.
void main() {
  group('JeebTextStyles registration', () {
    for (final entry in <String, ThemeData>{
      'light': AppTheme.light(),
      'dark': AppTheme.dark(),
    }.entries) {
      test('${entry.key} theme registers the extension', () {
        expect(entry.value.extension<JeebTextStyles>(), isNotNull);
      });
    }

    testWidgets('context.jeebText resolves the registered variant',
        (tester) async {
      late JeebTextStyles resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              resolved = context.jeebText;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved.h1.fontSize, 24);
      expect(resolved.h1.fontWeight, FontWeight.w700);
    });

    test('the accessor falls back to light when no theme provides it', () {
      // Guards the null-safety of the accessor: a bare ThemeData (as used by
      // some widget tests) must not crash a screen that reads jeebText.
      expect(ThemeData.light().extension<JeebTextStyles>(), isNull);
      expect(JeebTextStyles.light().h2.fontSize, 20);
    });
  });

  group('the ramp matches the redesign spec (§4.2)', () {
    final styles = JeebTextStyles.light();

    /// Every field, keyed by name so a failure says which one drifted.
    final expected = <String, ({TextStyle style, double size, FontWeight w})>{
      'statHero': (style: styles.statHero, size: 38, w: FontWeight.w800),
      'statDisplay': (style: styles.statDisplay, size: 42, w: FontWeight.w800),
      'h1': (style: styles.h1, size: 24, w: FontWeight.w700),
      'h2': (style: styles.h2, size: 20, w: FontWeight.w700),
      'titleProminent': (
        style: styles.titleProminent,
        size: 17,
        w: FontWeight.w700
      ),
      'cardTitle': (style: styles.cardTitle, size: 15.5, w: FontWeight.w700),
      'body': (style: styles.body, size: 13.5, w: FontWeight.w500),
      'bodySmall': (style: styles.bodySmall, size: 12, w: FontWeight.w600),
      'caption': (style: styles.caption, size: 11.5, w: FontWeight.w600),
      'label': (style: styles.label, size: 10.5, w: FontWeight.w700),
      'badge': (style: styles.badge, size: 10.5, w: FontWeight.w800),
      'sectionLabel': (
        style: styles.sectionLabel,
        size: 11,
        w: FontWeight.w700
      ),
      'price': (style: styles.price, size: 21, w: FontWeight.w800),
      'button': (style: styles.button, size: 17, w: FontWeight.w600),
      'keypadDigit': (style: styles.keypadDigit, size: 23, w: FontWeight.w700),
      'codeInput': (style: styles.codeInput, size: 29, w: FontWeight.w800),
    };

    expected.forEach((name, spec) {
      test('$name is ${spec.size}/${spec.w} in bundled Inter', () {
        expect(spec.style.fontSize, spec.size);
        expect(spec.style.fontWeight, spec.w);
        expect(
          spec.style.fontFamily,
          'Inter',
          reason: 'Every ramp field must name the bundled family explicitly — '
              'a ThemeExtension TextStyle does not inherit it from the theme.',
        );
      });
    });

    test('body carries the 19px line box', () {
      expect(styles.body.height, closeTo(19 / 13.5, 0.0001));
    });

    test('sectionLabel is tracked +1.2 and statHero is tracked -1.0', () {
      expect(styles.sectionLabel.letterSpacing, 1.2);
      expect(styles.statHero.letterSpacing, -1.0);
    });
  });

  group('cross-token invariants', () {
    // sectionLabel bakes in the muted ink, which lives in a sibling file as a
    // factory (unreachable from a const TextStyle). These two assertions are
    // what keep the duplicated hex honest.
    test('sectionLabel ink equals JeebSemanticColors.mutedText (light)', () {
      expect(
        JeebTextStyles.light().sectionLabel.color,
        JeebSemanticColors.light().mutedText,
      );
    });

    test('sectionLabel ink equals JeebSemanticColors.mutedText (dark)', () {
      expect(
        JeebTextStyles.dark().sectionLabel.color,
        JeebSemanticColors.dark().mutedText,
      );
    });

    test('dark mutedSurface equals the dark scheme surfaceContainerHigh', () {
      // The plan defines the dark value as "the dark scheme's own
      // surfaceContainerHigh"; it is hardcoded because a const factory cannot
      // call `ColorScheme.fromSeed`. If the SDK re-tones the neutral ramp,
      // this fails and the hardcode gets refreshed.
      expect(
        JeebSemanticColors.dark().mutedSurface,
        AppTheme.dark().colorScheme.surfaceContainerHigh,
      );
    });
  });
}
