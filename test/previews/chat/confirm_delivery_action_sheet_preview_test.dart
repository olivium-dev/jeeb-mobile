// Render tests for the ConfirmDeliveryActionSheet previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/confirm_delivery_action_sheet.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/delivery_confirm_illustration.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Confirming · spinner`, which cannot settle — see the
  testPreviewsRender(
    'ConfirmDeliveryActionSheet',
    const <String, Widget Function()>{
      'Picking · idle': confirmDeliveryActionSheetPicking,
      'Heading off · idle': confirmDeliveryActionSheetHeadingOff,
      'Narrow phone · 320 pt': confirmDeliveryActionSheetNarrowPhone,
      'Modal presentation · heading off':
          confirmDeliveryActionSheetInModalRoute,
    },
    expectedText: const <String, String>{
      'Picking · idle': 'Confirm Picking the order',
      'Heading off · idle': 'Confirm Heading off',
      // The CTA label: what the narrow box must not squeeze out.
      'Narrow phone · 320 pt': 'Confirm',
      // The subtitle: the line closest to the top of the modal frame.
      'Modal presentation · heading off': 'Help user track the order',
    },
  );

  // `isConfirming: true` renders `OmdsButtonLoading`, i.e. an INDETERMINATE
  group('ConfirmDeliveryActionSheet previews · Confirming · spinner', () {
    Future<void> pumpConfirming(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(confirmDeliveryActionSheetConfirming, locale),
      );
      await tester.pump(); // resolve localizations
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Confirming · spinner · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpConfirming(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Confirming · spinner renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpConfirming(tester);

      // The sheet is still the picking one…
      expect(find.text('Confirm Picking the order'), findsOneWidget);
      // …but the CTA label is gone, replaced by the spinner. That pair is true
      expect(find.text('Confirm'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('the in-flight CTA is a disabled, untappable semantics node', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpConfirming(tester);

      final Finder cta = find.bySemanticsIdentifier(
        'confirm_delivery_confirm_button',
      );
      expect(cta, findsOneWidget);
      expect(
        tester.getSemantics(cta),
        isSemantics(
          identifier: 'confirm_delivery_confirm_button',
          isButton: true,
          isEnabled: false,
          hasTapAction: false,
        ),
        reason: 'a live tap target during the call would fire the transition '
            'twice (QA B1 double-tap guard)',
      );
      handle.dispose();
    });

    testWidgets('the QA B1 leaf nodes survive the loading swap', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpConfirming(tester);

      for (final String id in const <String>[
        'confirm_delivery_drag_handle',
        'confirm_delivery_title',
        'confirm_delivery_subtitle',
        'confirm_delivery_confirm_button',
      ]) {
        expect(
          find.bySemanticsIdentifier(id),
          findsOneWidget,
          reason: 'expected an independent semantics node for $id',
        );
      }
      handle.dispose();
    });
  });

  group('ConfirmDeliveryActionSheet preview specifics', () {
    testWidgets('the two kinds never show each other\'s title', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, confirmDeliveryActionSheetPicking);
      expect(find.text('Confirm Heading off'), findsNothing);

      await pumpPreview(tester, confirmDeliveryActionSheetHeadingOff);
      expect(find.text('Confirm Picking the order'), findsNothing);
    });

    testWidgets('narrow-phone preview really is pinned to 320 pt', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, confirmDeliveryActionSheetNarrowPhone);

      // The render harness pumps an 800 px viewport, so without the SizedBox
      expect(
        tester.getSize(find.byType(ConfirmDeliveryActionSheet)).width,
        320,
      );
      // The illustration is a fraction of the sheet width, so it must have
      expect(
        tester.getSize(find.byType(DeliveryConfirmIllustration)).width,
        lessThan(320 - 2 * 24),
      );
    });

    testWidgets('modal preview shows the real bottom-sheet frame', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, confirmDeliveryActionSheetInModalRoute);

      // Pushed through ConfirmDeliveryActionSheet.show, not hand-placed: this
      expect(find.byType(BottomSheet), findsOneWidget);
      // …and it is anchored to the bottom of its host, under the scrim.
      final Rect sheet = tester.getRect(
        find.byType(ConfirmDeliveryActionSheet),
      );
      final Rect host = tester.getRect(find.byType(Navigator).last);
      expect(sheet.bottom, host.bottom);
    });

    testWidgets('the bare previews carry no bottom-sheet frame', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, confirmDeliveryActionSheetPicking);

      expect(find.byType(BottomSheet), findsNothing);
    });
  });
}
