import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_pull_to_refresh.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'List (pullable)': jeebPullToRefreshList,
  'Empty list (still pullable)': jeebPullToRefreshEmpty,
};

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeebPullToRefresh',
    _previews,
    expectedText: const <String, String>{
      'List (pullable)': 'List (pullable)',
      'Empty list (still pullable)': 'Empty list (still pullable)',
    },
  );

  group('JeebPullToRefresh preview specifics', () {
    testWidgets('the ring is never the accent orange', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebPullToRefreshList);

      final RefreshIndicator indicator = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      final ColorScheme scheme = Theme.of(
        tester.element(find.byType(RefreshIndicator)),
      ).colorScheme;
      expect(indicator.color, isNot(scheme.primary));
    });

    testWidgets('the EMPTY list still mounts the gesture', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebPullToRefreshEmpty);

      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.textContaining('Row '), findsNothing);
    });
  });
}
