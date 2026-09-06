import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Filtered (clear filters)': jeebEmptyStateFiltered,
  'Error + second act': jeebEmptyStateErrorWithSecondAct,
};

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeebEmptyState',
    _previews,
    expectedText: const <String, String>{
      'Filtered (clear filters)': 'No orders in this range',
      'Error + second act': 'Something went wrong',
    },
  );

  group('JeebEmptyState preview specifics', () {
    testWidgets('the filtered empty offers the way back under the primary act',
        (WidgetTester tester) async {
      await pumpPreview(tester, jeebEmptyStateFiltered);

      expect(
        tester.getCenter(find.text('Clear filters')).dy,
        greaterThan(tester.getCenter(find.text('New request')).dy),
      );
    });

    testWidgets('the error rung announces itself with its own copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebEmptyStateErrorWithSecondAct);

      final SemanticsData data = tester
          .getSemantics(find.bySemanticsIdentifier('preview_error'))
          .getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, isTrue);
      expect(data.label, isNotEmpty);
    });
  });
}
