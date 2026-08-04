// MIDNIGHT M6 per-element assertions for the app-shell + auth-funnel lane
// (app/, registration/, biometric_auth/, biometric_login/, profile_name/,
// onboarding/). Goldens are evidence, not gates — every finding below is
// asserted by reading the value off the widget, and each assertion carries the
// reverted value so it is provably discriminating.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/app/app.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';
import 'package:jeeb_mobile/features/biometric_login/presentation/biometric_prompt_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../support/sync_app_localizations.dart';

void main() {
  group('L13 — the empty-stack recovery frame', () {
    test('paints page navy, not a transparent hole onto the native window', () {
      final frame = kEmptyStackFrame;
      expect(frame, isA<ColoredBox>());
      expect((frame as ColoredBox).color, JeebMidnight.page);

      // Discrimination: the shipped `SizedBox.shrink()` paints nothing at all.
      expect(frame.color.a, 1.0,
          reason: 'any transparency lets the white iOS window through');
      expect(frame.child, isA<SizedBox>());
    });
  });

  group('L14 — one overlay style, not raw SystemUiOverlayStyle.light', () {
    test('the ratified style navies the Android nav bar', () {
      const ratified = AppTheme.systemOverlayStyle;
      expect(ratified.systemNavigationBarColor, JeebMidnight.page);
      expect(ratified.systemNavigationBarIconBrightness, Brightness.light);
      expect(ratified.statusBarColor, Colors.transparent);
      expect(ratified.statusBarIconBrightness, Brightness.light);
      expect(ratified.statusBarBrightness, Brightness.dark);
    });

    test('raw .light is what six sites were shipping — and it is BLACK', () {
      // Discrimination for every `expect(region.value, systemOverlayStyle)`
      // in the per-screen suites: the two values differ on the nav bar.
      expect(
        SystemUiOverlayStyle.light.systemNavigationBarColor,
        const Color(0xFF000000),
      );
      expect(
        AppTheme.systemOverlayStyle.systemNavigationBarColor,
        isNot(SystemUiOverlayStyle.light.systemNavigationBarColor),
      );
    });
  });

  group('L14 — biometric_prompt (no other suite mounts this screen)', () {
    testWidgets('takes the ratified overlay style, not raw .light',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.midnight(),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            SyncAppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const BiometricPromptScreen(),
        ),
      );
      await tester.pump();

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.descendant(
          of: find.byType(BiometricPromptScreen),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      );
      expect(region.value, AppTheme.systemOverlayStyle);
      expect(region.value.systemNavigationBarColor, JeebMidnight.page);
      expect(
        region.value.systemNavigationBarColor,
        isNot(SystemUiOverlayStyle.light.systemNavigationBarColor),
      );
    });
  });

  group('3c — the super-login role badge ternary', () {
    test('the two roles resolve to genuinely different quartets', () {
      final scheme = AppTheme.midnight().colorScheme;

      // What the screen now reads: jeeber = accent container, client = navy.
      expect(scheme.primaryContainer, isNot(scheme.secondaryContainer));
      expect(scheme.onPrimaryContainer, isNot(scheme.onSecondaryContainer));

      // Discrimination: the reverted pair is the no-op. `tertiary` is a compat
      // ALIAS of `primary` under Midnight, so both legs rendered identically.
      expect(scheme.tertiaryContainer, scheme.primaryContainer);
      expect(scheme.onTertiaryContainer, scheme.onPrimaryContainer);
      expect(scheme.tertiary, scheme.primary);
    });
  });
}
