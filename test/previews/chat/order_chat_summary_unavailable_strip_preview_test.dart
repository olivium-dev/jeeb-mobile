// Render tests for the OrderChatSummaryUnavailableStrip previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/order_chat_summary_unavailable_strip.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'OrderChatSummaryUnavailableStrip',
    const <String, Widget Function()>{
      'Summary unavailable · retry':
          orderChatSummaryUnavailableStripRetryable,
      'Summary unavailable · offline':
          orderChatSummaryUnavailableStripOffline,
      'Summary unavailable · no retry':
          orderChatSummaryUnavailableStripUnrecoverable,
    },
    expectedText: const <String, String>{
      'Summary unavailable · retry': "We couldn't load the order details.",
      'Summary unavailable · offline': "We couldn't load the order details.",
      'Summary unavailable · no retry': "We couldn't load the order details.",
    },
  );

  group('OrderChatSummaryUnavailableStrip preview specifics', () {
    testWidgets('a retryable failure offers the reload', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderChatSummaryUnavailableStripRetryable);

      expect(
        find.bySemanticsIdentifier('order_chat_summary_unavailable'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('order_chat_summary_retry'),
        findsOneWidget,
      );
    });

    // R6: an unrecoverable failure never gets an inert Retry.
    testWidgets('a 403 renders the strip with NO retry', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderChatSummaryUnavailableStripUnrecoverable);

      expect(
        find.bySemanticsIdentifier('order_chat_summary_unavailable'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('order_chat_summary_retry'),
        findsNothing,
      );
    });
  });
}
