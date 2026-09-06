import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_pull_to_refresh.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_state_host.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Empty block, pullable': jeebStateHostPullableEmpty,
  'No refresh handler': jeebStateHostStatic,
  'Overflowing block scrolls': jeebStateHostOverflow,
};

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeebStateHost',
    _previews,
    expectedText: const <String, String>{
      'Empty block, pullable': 'Empty block, pullable',
      'No refresh handler': 'No refresh handler',
      'Overflowing block scrolls': 'Overflowing block scrolls',
    },
  );

  group('JeebStateHost preview specifics', () {
    testWidgets('the pullable previews mount a ring; the static one does not', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebStateHostPullableEmpty);
      expect(find.byType(JeebPullToRefresh), findsOneWidget);

      await pumpPreview(tester, jeebStateHostStatic);
      expect(find.byType(JeebPullToRefresh), findsNothing);
      expect(find.byType(JeebStateHost), findsOneWidget);
    });

    testWidgets('an empty state inside the host is still findable', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebStateHostPullableEmpty);

      expect(find.bySemanticsIdentifier('preview_empty'), findsOneWidget);
    });

    testWidgets('a block taller than the canvas does not overflow', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebStateHostOverflow);

      expect(tester.takeException(), isNull);
    });
  });
}
