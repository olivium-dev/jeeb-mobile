// Render tests for the RequestCard previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/request_card.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'RequestCard',
    const <String, Widget Function()>{
      'Standard · live countdown': requestCardLive,
      'Accepting · both locked': requestCardAccepting,
      'Declining · outlined disabled': requestCardDeclining,
      'Expired · 0s linger': requestCardExpired,
      'No tier, no countdown': requestCardNoHeader,
      'Long addresses · LBP earnings': requestCardLongContent,
    },
    // One string per state that ONLY that state can produce. A suite that
    expectedText: const <String, String>{
      'Standard · live countdown': 'Expires in 45s',
      'Accepting · both locked': 'Accepting…',
      'Declining · outlined disabled': 'Declining…',
      'Expired · 0s linger': 'Expires in 0s',
      'No tier, no countdown': '12.7 km',
      'Long addresses · LBP earnings': '≈ 4500000.00 LBP',
    },
  );

  group('RequestCard preview specifics', () {
    testWidgets('in-flight accept narrates only the acting button', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, requestCardAccepting);

      expect(find.text('Accepting…'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      // The decline button keeps its idle label while disabled.
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Declining…'), findsNothing);
    });

    testWidgets('expired card keeps live labels and its zero countdown', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, requestCardExpired);

      // The G3 linger window: still on screen, still labelled Accept/Decline,
      expect(find.text('Expires in 0s'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets('no tier and no deadline drops the whole header row', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, requestCardNoHeader);

      expect(find.byKey(const Key('requestFeed.card.tierChip')), findsNothing);
      expect(find.textContaining('Expires in'), findsNothing);
      // The body below the missing header is untouched.
      expect(find.text('Pickup'), findsOneWidget);
      expect(find.text('Dropoff'), findsOneWidget);
    });

    testWidgets('currency code is passed through, never localized', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        requestCardLongContent,
        locale: const Locale('ar'),
      );

      // Arabic rendering still shows the raw ISO code inline in RTL text.
      expect(find.textContaining('LBP'), findsOneWidget);
    });
  });
}
