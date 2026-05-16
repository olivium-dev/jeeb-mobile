import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/app/app.dart';

void main() {
  setUp(() {
    // Pre-mark onboarding as completed so the boot test continues to verify
    // the shell, not the first-launch onboarding flow. Onboarding's own
    // first-launch behavior is covered by `onboarding_screen_test.dart`.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.onboarding.completed': true,
    });
  });

  testWidgets('App boots and renders the bottom-nav shell',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(JeebApp(preferences: prefs));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    // Default role is client → Home/Orders/Chat/Profile.
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Orders'), findsWidgets);
    expect(find.text('Chat'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
  });
}
