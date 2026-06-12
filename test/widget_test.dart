import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/app/app.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';

import 'support/sync_app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.onboarding.completed': true,
    });
  });

  testWidgets('App boots and renders the bottom-nav shell',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    // Inject the synchronous localizations delegate: the production delegate's
    // `rootBundle.loadString` round-trip does NOT complete under the headless
    // `flutter test` binding, so `Localizations` would withhold the route
    // subtree forever (the historical "flake" — actually a deterministic hang).
    await tester.pumpWidget(
      JeebApp(
        preferences: prefs,
        localizationsDelegateOverride: const SyncAppLocalizationsDelegate(),
      ),
    );
    // With the delegate resolving synchronously, the GoRouter redirect lands on
    // `/` (onboarding completed, biometric disabled) and mounts the shell. A
    // bounded pump flushes the redirect + the post-frame push-chain setState.
    await tester.pump(); // first frame builds MaterialApp.router
    await tester.pump(); // redirect evaluates → ShellScreen mounts
    await tester.pump(); // post-frame _initPushChain setState settles

    expect(find.byType(ShellScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);

    // The push chain + shell tabs schedule short-lived timers; drain them so
    // the test ends with no pending timers (the binding asserts on leak).
    await tester.pump(const Duration(milliseconds: 200));
  });
}
