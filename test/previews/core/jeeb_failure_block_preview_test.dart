import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_failure_block.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Network (retry)': jeebFailureBlockNetwork,
  'Server 500 (retry)': jeebFailureBlockServer,
  'Session expired (exit)': jeebFailureBlockSessionExpired,
  'Not found (no CTA)': jeebFailureBlockNotFound,
  'Rate limited (30s)': jeebFailureBlockRateLimited,
  'Compact (inline)': jeebFailureBlockCompact,
};

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeebFailureBlock',
    _previews,
    expectedText: const <String, String>{
      'Network (retry)': 'Network (retry)',
      'Server 500 (retry)': 'Server 500 (retry)',
      'Session expired (exit)': 'Session expired (exit)',
      'Not found (no CTA)': 'Not found (no CTA)',
      'Rate limited (30s)': 'Rate limited (30s)',
      'Compact (inline)': 'Compact (inline)',
    },
  );

  group('JeebFailureBlock preview specifics', () {
    testWidgets('the retryable previews all offer a Retry', (
      WidgetTester tester,
    ) async {
      for (final String state in const <String>[
        'Network (retry)',
        'Server 500 (retry)',
        'Rate limited (30s)',
        'Compact (inline)',
      ]) {
        await pumpPreview(tester, _previews[state]!);
        expect(
          find.bySemanticsIdentifier('preview_retry_cta'),
          findsOneWidget,
          reason: '$state is retryable',
        );
        expect(find.bySemanticsIdentifier('preview_exit_cta'), findsNothing);
      }
    });

    testWidgets('the expired session offers an exit and NO retry', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebFailureBlockSessionExpired);

      expect(find.bySemanticsIdentifier('preview_exit_cta'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('preview_retry_cta'),
        findsNothing,
        reason: 'onRetry IS wired on this preview — the widget must still '
            'refuse to render a Retry a 401 can never win',
      );
    });

    testWidgets('a 404 with no exit wired renders no CTA at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebFailureBlockNotFound);

      expect(find.bySemanticsIdentifier('preview_retry_cta'), findsNothing);
      expect(find.bySemanticsIdentifier('preview_exit_cta'), findsNothing);
    });

    testWidgets('the rate-limited preview renders its countdown', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeebFailureBlockRateLimited);

      expect(find.textContaining('30 second'), findsOneWidget);
    });
  });
}
