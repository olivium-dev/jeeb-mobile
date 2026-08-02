// Render tests for the JeebApp previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/app/app.dart';
import 'package:jeeb_mobile/features/account_status/presentation/account_status_screen.dart';
import 'package:jeeb_mobile/features/biometric_auth/presentation/biometric_lock_screen.dart';
import 'package:jeeb_mobile/features/onboarding/presentation/onboarding_screen.dart';
import 'package:jeeb_mobile/features/registration/presentation/registration_screen.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';

import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// Unmounts the tree between two `pumpPreview` calls in one test.
/// `_JeebAppState` initializes every cubit from `widget.preferences` in a
Future<void> _unmount(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());

/// The surface [JeebApp]'s router landed on, as a type.
Type _surface(WidgetTester tester) {
  for (final Type screen in <Type>[
    ShellScreen,
    OnboardingScreen,
    BiometricLockScreen,
    AccountStatusScreen,
    RegistrationScreen,
  ]) {
    if (tester.any(find.byType(screen))) return screen;
  }
  fail('no known surface mounted');
}

void main() {
  setUpAll(() {
    loadPreviewArbs();
    // The preview canvas leaves this null and uses the production delegate,
    jeebAppPreviewLocalizations = const SyncAppLocalizationsDelegate();
  });

  testPreviewsRender(
    'JeebApp',
    const <String, Widget Function()>{
      'First launch · onboarding': jeebAppFirstLaunch,
      'Signed in · shell': jeebAppSignedIn,
      'Biometric lock': jeebAppBiometricLocked,
      'Account suspended': jeebAppAccountSuspended,
      'Arabic app language': jeebAppArabicLanguage,
    },
    expectedText: const <String, String>{
      'First launch · onboarding': 'Skip',
      'Signed in · shell': 'What do you need?',
      'Biometric lock': 'Unlock Jeeb',
      'Account suspended': 'Your account is suspended',
      // The Arabic rendering of the SAME line the signed-in preview pins, so
      'Arabic app language': 'ماذا تحتاج؟',
    },
  );

  group('JeebApp preview specifics', () {
    testWidgets('each preview lands on its own gate outcome', (
      WidgetTester tester,
    ) async {
      // The failure this suite exists to catch: five previews of a widget that
      final Map<String, Type> landed = <String, Type>{};
      for (final MapEntry<String, Widget Function()> entry
          in <String, Widget Function()>{
        'first-launch': jeebAppFirstLaunch,
        'signed-in': jeebAppSignedIn,
        'locked': jeebAppBiometricLocked,
        'suspended': jeebAppAccountSuspended,
        'arabic': jeebAppArabicLanguage,
      }.entries) {
        await _unmount(tester);
        await pumpPreview(tester, entry.value);
        landed[entry.key] = _surface(tester);
      }

      expect(landed, <String, Type>{
        'first-launch': OnboardingScreen,
        'signed-in': ShellScreen,
        'locked': BiometricLockScreen,
        'suspended': AccountStatusScreen,
        // Same surface as `signed-in` on purpose — the mirror pair. The two are
        'arabic': ShellScreen,
      });
    });

    testWidgets('the first-run gate runs onboarding BEFORE the session', (
      WidgetTester tester,
    ) async {
      // The fresh-install preview injects a signed-OUT gate, so if the order in
      await pumpPreview(tester, jeebAppFirstLaunch);

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(RegistrationScreen), findsNothing);
    });

    testWidgets('the CANVAS locale does not reach JeebApp', (
      WidgetTester tester,
    ) async {
      // JeebApp builds its own MaterialApp.router and sets `locale:` from
      await pumpPreview(tester, jeebAppSignedIn, locale: const Locale('ar'));

      expect(find.text('What do you need?'), findsOneWidget);
      expect(find.text('ماذا تحتاج؟'), findsNothing);
      expect(
        Directionality.of(tester.element(find.text('What do you need?'))),
        TextDirection.ltr,
      );
    });

    testWidgets('the persisted language DOES reach it, and mirrors the tree', (
      WidgetTester tester,
    ) async {
      // The other half: seeded through the same SharedPreferences key
      await pumpPreview(
        tester,
        jeebAppArabicLanguage,
        locale: const Locale('en'),
      );

      final Finder line = find.text('ماذا تحتاج؟');
      expect(line, findsOneWidget);
      expect(find.text('What do you need?'), findsNothing);
      expect(Directionality.of(tester.element(line)), TextDirection.rtl);
    });

    testWidgets('the account-status gate blocks every tab', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebAppAccountSuspended);

      expect(find.byType(ShellScreen), findsNothing);
      expect(find.text('Contact support'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('at 200% text the shell overflows its own phone frame', (
      WidgetTester tester,
    ) async {
      // The finding the `EN 200% text` cell of the signed-in preview surfaces,
      Future<List<String>> overflowsAt(
        double scale,
        Widget Function() preview,
      ) async {
        final List<String> seen = <String>[];
        final void Function(FlutterErrorDetails)? previous =
            FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          seen.add(details.exceptionAsString());
        };
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData.fromView(tester.view)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: previewCanvas(preview, const Locale('en')),
          ),
        );
        await tester.pumpAndSettle();
        FlutterError.onError = previous;
        return seen
            .where((String s) => s.contains('overflowed'))
            .toList(growable: false);
      }

      // The preview's own canvas box, so this measures what a reviewer sees.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      expect(await overflowsAt(1.0, jeebAppAccountSuspended), isEmpty);
      await _unmount(tester);
      expect(await overflowsAt(2.0, jeebAppAccountSuspended), isEmpty);

      await _unmount(tester);
      expect(
        await overflowsAt(2.0, jeebAppSignedIn),
        isNotEmpty,
        reason: 'the bottom bar needs ~888 dp inside the 390 dp frame at 200% '
            'text: every tab label is clipped, with no ellipsis to say so',
      );
    });

    testWidgets('the lock gate needs BOTH the opt-in and an available sensor', (
      WidgetTester tester,
    ) async {
      // The locked preview injects an enrolled gateway on top of the persisted
      await pumpPreview(tester, jeebAppBiometricLocked);
      expect(find.byType(BiometricLockScreen), findsOneWidget);

      await _unmount(tester);
      await pumpPreview(tester, jeebAppSignedIn);
      expect(find.byType(BiometricLockScreen), findsNothing);
    });
  });
}
