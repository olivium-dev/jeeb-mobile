import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_refresh_failed_note.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Retry + dismiss': jeebRefreshFailedNoteRetryable,
  'Dismiss only': jeebRefreshFailedNoteDismissOnly,
};

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeebRefreshFailedNote',
    _previews,
    expectedText: const <String, String>{
      'Retry + dismiss': 'Retry + dismiss',
      'Dismiss only': 'Dismiss only',
    },
  );

  group('JeebRefreshFailedNote preview specifics', () {
    testWidgets('both acts are present only when onRetry is wired', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebRefreshFailedNoteRetryable);
      expect(
        find.bySemanticsIdentifier('preview_refresh_failed_retry_cta'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('preview_refresh_failed_dismiss_cta'),
        findsOneWidget,
      );

      await pumpPreview(tester, jeebRefreshFailedNoteDismissOnly);
      expect(
        find.bySemanticsIdentifier('preview_refresh_failed_retry_cta'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('preview_refresh_failed_dismiss_cta'),
        findsOneWidget,
      );
    });
  });
}
