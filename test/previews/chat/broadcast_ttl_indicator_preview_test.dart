// Render tests for the BroadcastTtlIndicator previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// The two hidden states (`Expired window`, `No window`) cannot be pinned
// through `expectedText` — their whole contract is that they render NO text —
// so they are pinned below instead, by asserting the widget's own
// `Key('broadcast-ttl-indicator')` is absent. That is a stricter check than a
// string match, not a weaker one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/broadcast_ttl_indicator.dart';

import '../preview_test_harness.dart';

/// The band's own key, set in `broadcast_ttl_indicator.dart`.
const Key _band = Key('broadcast-ttl-indicator');

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'BroadcastTtlIndicator',
    const <String, Widget Function()>{
      'Fresh 5-minute window': broadcastTtlIndicatorFreshWindow,
      'Final seconds': broadcastTtlIndicatorFinalSeconds,
      'One second left': broadcastTtlIndicatorOneSecond,
      'Clock-skewed long count': broadcastTtlIndicatorClockSkew,
      'Expired window': broadcastTtlIndicatorExpired,
      'No window': broadcastTtlIndicatorNoWindow,
    },
    expectedText: const <String, String>{
      'Fresh 5-minute window': 'Offer window closes in 300s',
      'Final seconds': 'Offer window closes in 5s',
      'One second left': 'Offer window closes in 1s',
      'Clock-skewed long count': 'Offer window closes in 3900s',
    },
  );

  group('BroadcastTtlIndicator preview specifics', () {
    testWidgets('an expired window renders no band at all — not "0s"', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, broadcastTtlIndicatorExpired);

      expect(find.byKey(_band), findsNothing);
      expect(find.textContaining('Offer window'), findsNothing);
      expect(find.textContaining('-'), findsNothing);
    });

    testWidgets('a null window renders no band at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, broadcastTtlIndicatorNoWindow);

      expect(find.byKey(_band), findsNothing);
      expect(find.textContaining('Offer window'), findsNothing);
    });

    testWidgets('the label is localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        broadcastTtlIndicatorFinalSeconds,
        locale: const Locale('ar'),
      );

      expect(find.text('نافذة العروض تُغلق خلال 5 ثانية'), findsOneWidget);
      expect(find.textContaining('Offer window'), findsNothing);
    });

    testWidgets('the band spans the full width it is given', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, broadcastTtlIndicatorFreshWindow);

      expect(
        tester.getSize(find.byKey(_band)).width,
        tester.getSize(find.byType(Scaffold)).width,
      );
    });
  });
}
