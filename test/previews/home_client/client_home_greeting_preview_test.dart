// Render tests for the ClientHomeGreeting previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/home_client/presentation/widgets/client_home_greeting.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ClientHomeGreeting',
    const <String, Widget Function()>{
      'Named + avatar': clientHomeGreetingNamed,
      'Generic fallback': clientHomeGreetingFallback,
      'Name, no avatar': clientHomeGreetingInitialsOnly,
      'Synthetic handle suppressed': clientHomeGreetingSyntheticHandle,
      'Long name overflow': clientHomeGreetingLongName,
    },
    expectedText: const <String, String>{
      'Named + avatar': 'Hello, Sami',
      'Generic fallback': 'Welcome back',
      'Name, no avatar': 'Hello, Layla',
      'Synthetic handle suppressed': 'Welcome back',
      'Long name overflow': 'Hello, Abdulrahman',
    },
  );

  group('ClientHomeGreeting preview specifics', () {
    testWidgets('greets the FIRST name only', (WidgetTester tester) async {
      await pumpPreview(tester, clientHomeGreetingNamed);

      expect(find.text('Hello, Sami'), findsOneWidget);
      expect(find.textContaining('Fawaz'), findsNothing);
    });

    testWidgets('never shows the raw synthetic handle (audit §T5)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientHomeGreetingSyntheticHandle);

      expect(find.textContaining('jeeb-e1a35ea8a520'), findsNothing);
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });
}
