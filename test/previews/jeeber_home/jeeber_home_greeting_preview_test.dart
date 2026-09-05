// Render tests for the JeeberHomeGreeting previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_home_greeting.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'getMe in flight · greets nobody': jeeberHomeGreetingPending,
  'Landed nameless · fallback greeting': jeeberHomeGreetingResolvedNameless,
  'Landed named': jeeberHomeGreetingNamed,
  'No ambient cubit · fallback greeting': jeeberHomeGreetingNoCubit,
};

Finder _loadingId() =>
    find.bySemanticsIdentifier(JeeberHomeGreeting.loadingIdentifier);

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeeberHomeGreeting',
    _previews,
    expectedText: const <String, String>{
      'getMe in flight · greets nobody': 'Jeeber dashboard',
      'Landed nameless · fallback greeting': 'Welcome back',
      'Landed named': 'Ahlan, Karim',
      'No ambient cubit · fallback greeting': 'Welcome back',
    },
  );

  group('JeeberHomeGreeting preview specifics', () {
    testWidgets('the pending preview greets nobody', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberHomeGreetingPending);
      expect(_loadingId(), findsOneWidget);
      expect(find.text('Welcome back'), findsNothing);
      expect(find.text('?'), findsNothing);
    });

    for (final MapEntry<String, Widget Function()> landed
        in <String, Widget Function()>{
      'Landed nameless · fallback greeting': jeeberHomeGreetingResolvedNameless,
      'Landed named': jeeberHomeGreetingNamed,
      'No ambient cubit · fallback greeting': jeeberHomeGreetingNoCubit,
    }.entries) {
      testWidgets('${landed.key} carries no loading tag', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, landed.value);
        expect(_loadingId(), findsNothing);
      });
    }
  });
}
