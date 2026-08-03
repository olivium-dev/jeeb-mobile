import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/app/app.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';
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
    await tester.pumpWidget(
      JeebApp(
        preferences: prefs,
        localizationsDelegateOverride: const SyncAppLocalizationsDelegate(),
        sessionGate: const AlwaysAuthenticatedSessionGate(),
      ),
    );
    await tester.pump(); // first frame builds MaterialApp.router
    await tester.pump(); // redirect evaluates → ShellScreen mounts
    await tester.pump(); // post-frame _initPushChain setState settles

    expect(find.byType(ShellScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);

    await tester.pump(const Duration(milliseconds: 200));
  });
}
