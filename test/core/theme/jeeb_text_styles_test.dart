import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/theme/jeeb_text_styles.dart';

/// Gates for the MIDNIGHT type ramp (token sheet §6). Values are quoted from
/// the sheet, not read back from the code, so this file is the contract.
void main() {
  group('JeebTextStyles registration', () {
    test('the theme registers the extension', () {
      expect(AppTheme.midnight().extension<JeebTextStyles>(), isNotNull);
    });

    test('light() and dark() are the same ramp', () {
      expect(JeebTextStyles.light(), JeebTextStyles.dark());
      expect(JeebTextStyles.light(), JeebTextStyles.midnight());
      expect(
        AppTheme.light().extension<JeebTextStyles>(),
        AppTheme.dark().extension<JeebTextStyles>(),
      );
    });

    testWidgets('context.jeebText resolves the registered variant',
        (tester) async {
      late JeebTextStyles resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.midnight(),
          home: Builder(
            builder: (context) {
              resolved = context.jeebText;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved.h1.fontSize, 26);
      expect(resolved.h1.fontWeight, FontWeight.w700);
      expect(resolved.h1.letterSpacing, -0.6);
    });

    test('the accessor falls back to the ramp when no theme provides it', () {
      expect(ThemeData.light().extension<JeebTextStyles>(), isNull);
      expect(JeebTextStyles.midnight().h2.fontSize, 20);
    });
  });

  group('the ramp matches the ratified sheet (§6)', () {
    final styles = JeebTextStyles.midnight();

    /// `track` is `null` where the sheet specifies no tracking.
    final expected =
        <String, ({TextStyle style, double size, FontWeight w, double? track})>{
      'statHero': (
        style: styles.statHero,
        size: 40,
        w: FontWeight.w800,
        track: -1.2
      ),
      'statDisplay': (
        style: styles.statDisplay,
        size: 44,
        w: FontWeight.w800,
        track: null
      ),
      'h1': (style: styles.h1, size: 26, w: FontWeight.w700, track: -0.6),
      'h2': (style: styles.h2, size: 20, w: FontWeight.w700, track: -0.5),
      'titleProminent': (
        style: styles.titleProminent,
        size: 17,
        w: FontWeight.w700,
        track: -0.2
      ),
      'cardTitle': (
        style: styles.cardTitle,
        size: 15.5,
        w: FontWeight.w700,
        track: null
      ),
      'body': (style: styles.body, size: 14.5, w: FontWeight.w500, track: null),
      'bodySmall': (
        style: styles.bodySmall,
        size: 12.5,
        w: FontWeight.w600,
        track: null
      ),
      'caption': (
        style: styles.caption,
        size: 11.5,
        w: FontWeight.w600,
        track: null
      ),
      'label': (
        style: styles.label,
        size: 10.5,
        w: FontWeight.w700,
        track: null
      ),
      'badge': (
        style: styles.badge,
        size: 10.5,
        w: FontWeight.w800,
        track: 1.0
      ),
      'sectionLabel': (
        style: styles.sectionLabel,
        size: 11,
        w: FontWeight.w700,
        track: 1.2
      ),
      'price': (style: styles.price, size: 22, w: FontWeight.w800, track: -0.5),
      'button': (
        style: styles.button,
        size: 17,
        w: FontWeight.w600,
        track: null
      ),
      'keypadDigit': (
        style: styles.keypadDigit,
        size: 23,
        w: FontWeight.w700,
        track: null
      ),
      'codeInput': (
        style: styles.codeInput,
        size: 29,
        w: FontWeight.w800,
        track: null
      ),
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

      test('$name carries the tracking the board measures', () {
        expect(
          spec.style.letterSpacing,
          spec.track,
          reason: 'Pass 1 dropped the board tracking; §6 makes it contract.',
        );
      });

      test('$name carries the Arabic + emoji fallback chain', () {
        expect(
          spec.style.fontFamilyFallback,
          <String>['Baloo Bhaijaan 2', 'Apple Color Emoji', 'Noto Color Emoji'],
          reason: 'Sheet §6 puts the fallback chain on EVERY style.',
        );
      });
    });

    test('the Arabic face name is exactly the _ds token', () {
      // A typo degrades silently, and only on Arabic devices.
      expect(jeebFontFamilyFallback.first, 'Baloo Bhaijaan 2');
    });

    test('body carries the 21px line box', () {
      expect(styles.body.height, closeTo(21 / 14.5, 0.0001));
    });

    test('the ramp sits one step ABOVE the pass-1 ramp', () {
      expect(styles.h1.fontSize, isNot(24));
      expect(styles.body.fontSize, isNot(13.5));
      expect(styles.price.fontSize, isNot(21));
      expect(styles.statHero.fontSize, isNot(38));
      expect(styles.bodySmall.fontSize, isNot(12));
    });
  });

  group('cross-token invariants', () {
    test('sectionLabel ink equals JeebSemanticColors.mutedText', () {
      expect(
        JeebTextStyles.midnight().sectionLabel.color,
        JeebSemanticColors.midnight().mutedText,
      );
      expect(
        JeebTextStyles.midnight().sectionLabel.color,
        const Color(0xFF8A93D8),
      );
    });

    test('mutedSurface equals the scheme surfaceContainerHigh', () {
      // A const factory cannot read a ColorScheme, so the hex is duplicated.
      expect(
        JeebSemanticColors.midnight().mutedSurface,
        AppTheme.midnight().colorScheme.surfaceContainerHigh,
      );
    });

    test('the retired muted inks are gone from the ramp', () {
      expect(
        JeebTextStyles.midnight().sectionLabel.color,
        isNot(const Color(0xFF777FC0)),
      );
      expect(
        JeebTextStyles.midnight().sectionLabel.color,
        isNot(const Color(0xFF9DA3E0)),
      );
    });

    test('the M3 TextTheme also carries the fallback chain', () {
      // Family + fallbacks only; the M3 metrics stay unreshaped.
      final TextStyle? bodyMedium = AppTheme.midnight().textTheme.bodyMedium;
      expect(bodyMedium?.fontFamily, 'Inter');
      expect(bodyMedium?.fontFamilyFallback, jeebFontFamilyFallback);
    });
  });
}
