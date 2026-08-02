// Render tests for the DeliveryJeeberCard previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_status/presentation/widgets/delivery_jeeber_card.dart';

import '../preview_test_harness.dart';

/// Reference phone width used by the whole preview folder.
const double _phoneWidth = 390;

/// Body height of a 390x844 phone once the app bar and system insets are gone —
/// the budget the delivery-status column really has.
const double _phoneBodyHeight = 700;

/// Pumps [preview] at a real device width and text scale and returns the height
/// of the whole card.
Future<double> _cardHeight(
  WidgetTester tester,
  Widget Function() preview, {
  double width = _phoneWidth,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = Size(width * 3, 4000 * 3);
  tester.view.devicePixelRatio = 3.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(previewCanvas(preview, locale));
  await tester.pumpAndSettle();

  return tester.getSize(find.byKey(DeliveryJeeberCard.rootKey)).height;
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DeliveryJeeberCard',
    const <String, Widget Function()>{
      'Matched · rating shown': deliveryJeeberCardMatched,
      'Waiting for a match': deliveryJeeberCardWaiting,
      'No rating yet': deliveryJeeberCardNoRating,
      'Blank display name': deliveryJeeberCardBlankName,
      'Longest content': deliveryJeeberCardLongContent,
      'Arabic name in EN UI': deliveryJeeberCardArabicName,
    },
    expectedText: const <String, String>{
      'Matched · rating shown': 'Karim H.',
      'Waiting for a match': 'Looking for a Jeeber…',
      'No rating yet': 'Kamal Hajj',
      'Blank display name': 'Pickup truck',
      'Longest content': 'Abdulrahman Al-Muhandis Al-Trabulsi',
      'Arabic name in EN UI': 'كريم حجازي',
    },
  );

  group('DeliveryJeeberCard preview specifics', () {
    testWidgets('the waiting state replaces the whole row, not just the name', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryJeeberCardWaiting);

      // Title survives — it is the card, not the content, that stays put.
      expect(find.text('Your Jeeber'), findsOneWidget);
      expect(find.text('Looking for a Jeeber…'), findsOneWidget);
      // ...and nothing from the matched row is mounted: no avatar disc, no
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('★'), findsNothing);
    });

    testWidgets('a blank display name yields "?" over an EMPTY name line', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryJeeberCardBlankName);

      // `_initial()` guards the avatar...
      expect(find.text('?'), findsOneWidget);
      // ...and nothing guards the name, so the card paints a blank line where
      expect(find.text(''), findsOneWidget);
      expect(find.text('Pickup truck'), findsOneWidget);
    });

    testWidgets('the rating chip renders only when a rating exists', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryJeeberCardMatched);
      expect(find.text('4.8 ★'), findsOneWidget);

      await pumpPreview(tester, deliveryJeeberCardNoRating);
      // Dropped entirely — never "—", never "0.0".
      expect(find.textContaining('★'), findsNothing);
      expect(find.text('0.0'), findsNothing);
    });

    testWidgets('the row mirrors under RTL: avatar leads, chip trails', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryJeeberCardMatched);
      final double avatarEn = tester.getCenter(find.text('K')).dx;
      final double chipEn = tester.getCenter(find.text('4.8 ★')).dx;
      expect(avatarEn, lessThan(chipEn), reason: 'EN: avatar on the left');

      await pumpPreview(
        tester,
        deliveryJeeberCardMatched,
        locale: const Locale('ar'),
      );
      final double avatarAr = tester.getCenter(find.text('K')).dx;
      final double chipAr = tester.getCenter(find.text('4.8 ★')).dx;
      expect(avatarAr, greaterThan(chipAr), reason: 'AR: avatar on the right');
    });

    testWidgets('the rating chip costs the name column its width budget', (
      WidgetTester tester,
    ) async {
      // Same 390 dp box, same 200% text scale. The chipped state carries the
      final double withChip = await _cardHeight(
        tester,
        deliveryJeeberCardMatched,
        textScale: 2.0,
      );
      final double withoutChip = await _cardHeight(
        tester,
        deliveryJeeberCardNoRating,
        textScale: 2.0,
      );

      expect(withChip, greaterThan(withoutChip));
    });

    testWidgets('nothing clamps: long content grows past a phone body', (
      WidgetTester tester,
    ) async {
      // The control — the same fixture fits comfortably at 100% text.
      final double atNormalText = await _cardHeight(
        tester,
        deliveryJeeberCardLongContent,
      );
      expect(atNormalText, lessThan(_phoneBodyHeight));

      // Neither Text sets maxLines/overflow, so at 200% the single card is
      final double atLargeText = await _cardHeight(
        tester,
        deliveryJeeberCardLongContent,
        textScale: 2.0,
      );
      expect(atLargeText, greaterThan(_phoneBodyHeight));
      expect(tester.takeException(), isNull, reason: 'grows, never overflows');
    });
  });
}
