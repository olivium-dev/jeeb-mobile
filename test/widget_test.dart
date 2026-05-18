import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/app/app.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.onboarding.completed': true,
    });
  });

  testWidgets('App boots and renders the bottom-nav shell',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(JeebApp(preferences: prefs));
    // Allow GoRouter redirect to evaluate and the postFrameCallback to
    // fire (push-notification wiring). Multiple pumps cover the redirect
    // microtask, the setState in _initPushChain, and any pending frames.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byType(ShellScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
