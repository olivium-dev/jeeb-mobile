// Render tests for the DeliveryReceiptScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/delivery_receipt/presentation/delivery_receipt_screen.dart';

import '../preview_test_harness.dart';

/// `receipt_confirm_cta` — "Yes, I received it".
final Finder _confirmCta = find.byKey(const Key('receipt-confirm-cta'));

/// `receipt_not_yet_cta` — "Not yet", the dispute fork.
final Finder _notYetCta = find.byKey(const Key('receipt-not-yet-cta'));

/// The load-failure body. Keyed on the screen, so it distinguishes a failed
/// LOAD from the confirm banner, which is a `Text` inside the loaded body.
final Finder _loadError = find.byKey(const Key('receipt-load-error'));

/// `receipt_proof_photo` — present in BOTH branches, photo or placeholder.
final Finder _proofPhoto = find.bySemanticsIdentifier('receipt_proof_photo');

/// EN `receiptProofPhotoLabel`.
const String _proofPhotoLabel = 'Proof of delivery photo';

/// EN `receiptPromptHeading` — the one string every loaded state shares.
const String _promptHeading = 'Did you receive your order?';

/// EN `receiptErrorTransition`, the 422 the confirm fixture raises.
const String _confirmRejectedCopy =
    "We couldn't confirm receipt right now. Please try again.";

// The cash-on-delivery lines, copied exactly as they render.
const String _cashKamal = 'Pay \u2066\$9.00\u2069 cash to Kamal Hajj';
const String _cashFallbackNoun = 'Pay \u2066\$9.00\u2069 cash to the Jeeber';
const String _cashRami = 'Pay \u2066\$42.00\u2069 cash to Rami Saab';
const String _cashLongLbp = 'Pay \u2066LBP 1,250,000.00\u2069 cash to '
    'Abdulrahman Al-Muhandis Al-Trabulsi Al-Shami';

/// Run-22 P1-A: the amount-less degrade. Never `Pay $0.00`.
const String _cashNoAmountKamal = 'Pay the order amount in cash to Kamal Hajj';
const String _cashNoAmountNour = 'Pay the order amount in cash to Nour Chami';

/// Scrolls `receipt_not_yet_cta` into the tree.
/// The body is a `ListView`, so the dispute fork is not merely off-screen when
Future<void> _revealNotYetCta(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    _notYetCta,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except the two that cannot settle — see the groups at the
  testPreviewsRender(
    'DeliveryReceiptScreen',
    const <String, Widget Function()>{
      'Amount unknown · gateway dropped it': deliveryReceiptScreenAmountUnknown,
      'Amount zero · never fabricate \$0.00': deliveryReceiptScreenAmountZero,
      'No jeeber name · generic fallback': deliveryReceiptScreenNoJeeberName,
      'Long jeeber name · LBP amount': deliveryReceiptScreenLongContent,
      'Error · 404 receipt not found': deliveryReceiptScreenNotFound,
      'Error · network, retry keeps failing': deliveryReceiptScreenNetworkDown,
      'Confirm rejected · 422 transition': deliveryReceiptScreenConfirmRejected,
    },
    expectedText: const <String, String>{
      'Amount unknown · gateway dropped it': _cashNoAmountKamal,
      'Amount zero · never fabricate \$0.00': _cashNoAmountNour,
      'No jeeber name · generic fallback': _cashFallbackNoun,
      'Long jeeber name · LBP amount': _cashLongLbp,
      'Error · 404 receipt not found': 'We couldn\'t find this delivery.',
      'Error · network, retry keeps failing':
          "Couldn't reach the server. Check your connection and try again.",
      'Confirm rejected · 422 transition': _cashRami,
    },
  );

  group('DeliveryReceiptScreen previews · the run-22 P1-A amount guard', () {
    testWidgets('an ABSENT amount degrades — it never renders as \$0.00', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReceiptScreenAmountUnknown);

      expect(find.text(_cashNoAmountKamal), findsOneWidget);
      // The whole point of the guard: no fabricated money token, of any shape.
      expect(find.textContaining('0.00'), findsNothing);
      expect(find.textContaining('\$'), findsNothing);
    });

    testWidgets('a ZERO amount takes the same branch as an absent one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReceiptScreenAmountZero);

      expect(find.text(_cashNoAmountNour), findsOneWidget);
      expect(find.textContaining('\$'), findsNothing);
      // Still a normal, confirmable receipt — the degrade is copy-only.
      expect(_confirmCta, findsOneWidget);
      await _revealNotYetCta(tester);
      expect(_notYetCta, findsOneWidget);
    });

    testWidgets('a KNOWN amount keeps its LTR isolate in Arabic', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        deliveryReceiptScreenLongContent,
        locale: const Locale('ar'),
      );

      // The AR template reorders the sentence around the token, but the token
      expect(
        find.text('ادفع \u2066LBP 1,250,000.00\u2069 نقداً إلى '
            'Abdulrahman Al-Muhandis Al-Trabulsi Al-Shami'),
        findsOneWidget,
      );
    });
  });

  group('DeliveryReceiptScreen previews · the proof-photo slot', () {
    testWidgets('with NO photo the slot is the neutral placeholder', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReceiptScreenNoJeeberName);

      expect(find.byType(OmdsCachedImage), findsNothing);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    });

    testWidgets('…and still announces itself as an IMAGE labelled "Proof of '
        'delivery photo"', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, deliveryReceiptScreenNoJeeberName);

      // The `Semantics(identifier: 'receipt_proof_photo', image: true, label:)`
      expect(_proofPhoto, findsOneWidget);
      expect(
        tester.getSemantics(_proofPhoto),
        isSemantics(label: _proofPhotoLabel, isImage: true),
      );
      handle.dispose();
    });
  });

  group('DeliveryReceiptScreen previews · the two forks', () {
    testWidgets('confirm SUCCEEDS → the customer is released to mutual-rating',
        (WidgetTester tester) async {
      await pumpPreview(tester, deliveryReceiptScreenNoJeeberName);
      expect(find.text(_promptHeading), findsOneWidget);

      await tester.tap(_confirmCta);
      await tester.pumpAndSettle();

      // `context.goNamed('mutual-rating')` REPLACES the stack, so the prompt
      expect(tester.takeException(), isNull);
      expect(find.text('mutual-rating · JM-034'), findsOneWidget);
      expect(find.text(_promptHeading), findsNothing);
    });

    testWidgets('"Not yet" PUSHES the dispute screen, keeping the prompt alive',
        (WidgetTester tester) async {
      await pumpPreview(tester, deliveryReceiptScreenNoJeeberName);
      await _revealNotYetCta(tester);

      await tester.tap(_notYetCta);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('dispute-open-evidence · JM-060'), findsOneWidget);
    });

    testWidgets('confirm REJECTED → the banner appears in place and the body '
        'survives', (WidgetTester tester) async {
      await pumpPreview(tester, deliveryReceiptScreenConfirmRejected);

      // First frame: an ordinary loaded body. The failure is a tap away.
      expect(find.text(_cashRami), findsOneWidget);
      expect(find.text(_confirmRejectedCopy), findsNothing);

      await tester.tap(_confirmCta);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(_confirmRejectedCopy), findsOneWidget);
      // The confirm sub-status is deliberately separate from the screen
      expect(find.text(_cashRami), findsOneWidget);
      expect(_confirmCta, findsOneWidget);
      // And nothing navigated: a rejected confirm must not reach the rating
      expect(find.text('mutual-rating · JM-034'), findsNothing);
      await _revealNotYetCta(tester);
      expect(_notYetCta, findsOneWidget);
    });

    testWidgets('a second confirm re-fails rather than throwing', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryReceiptScreenConfirmRejected);

      await tester.tap(_confirmCta);
      await tester.pumpAndSettle();
      await tester.tap(_confirmCta);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(_confirmRejectedCopy), findsOneWidget);
    });
  });

  group('DeliveryReceiptScreen previews · the failed-load dead end', () {
    testWidgets('404 replaces the whole body — including the dispute escape '
        'hatch', (WidgetTester tester) async {
      await pumpPreview(tester, deliveryReceiptScreenNotFound);

      expect(_loadError, findsOneWidget);
      // `receipt_not_yet_cta` is the only non-confirm way off this screen, and
      expect(_notYetCta, findsNothing);
      expect(_confirmCta, findsNothing);
      expect(find.text(_promptHeading), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
    });

    testWidgets('retry against a still-404 repository re-errors rather than '
        'throwing', (WidgetTester tester) async {
      await pumpPreview(tester, deliveryReceiptScreenNotFound);

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text("We couldn't find this delivery."), findsOneWidget);
    });

    testWidgets('the network failure is told apart from the 404 by copy alone',
        (WidgetTester tester) async {
      await pumpPreview(tester, deliveryReceiptScreenNetworkDown);

      expect(_loadError, findsOneWidget);
      expect(
        find.text(
          "Couldn't reach the server. Check your connection and try again.",
        ),
        findsOneWidget,
      );
      // Same shape as the 404: same icon, same single button. Only one of the
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
      expect(_notYetCta, findsNothing);
    });
  });

  // `Loading · fetch in flight` — an indeterminate spinner held open by a read
  group('DeliveryReceiptScreen previews · Loading · fetch in flight', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(deliveryReceiptScreenLoading, locale),
      );
      await tester.pump(); // resolve localizations + the nested Router
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · fetch in flight · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpLoading(tester, locale: locale);

        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    }

    testWidgets('renders its own state', (WidgetTester tester) async {
      await pumpLoading(tester);

      // The caption is the only text on screen: `OmdsLoadingState` is given no
      expect(
        find.text(DeliveryReceiptScreenCaptions.loading),
        findsOneWidget,
      );
      expect(find.text(_promptHeading), findsNothing);
      expect(_proofPhoto, findsNothing);
      expect(_confirmCta, findsNothing);
    });
  });

  // `Loaded · proof photo + $9.00 cash` — the only state that renders
  group('DeliveryReceiptScreen previews · Loaded · proof photo', () {
    Future<void> pumpLoaded(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(deliveryReceiptScreenLoaded, locale),
      );
      await tester.pump(); // resolve localizations + the nested Router
      await tester.pump(); // the fake's fetchReceipt microtask
      await tester.pump(const Duration(milliseconds: 16)); // one shimmer frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loaded · proof photo · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpLoaded(tester, locale: locale);

        expect(tester.takeException(), isNull);
        expect(find.byType(OmdsCachedImage), findsOneWidget);
      });
    }

    testWidgets('renders its own state', (WidgetTester tester) async {
      await pumpLoaded(tester);

      expect(find.text(_cashKamal), findsOneWidget);
      expect(find.text(_promptHeading), findsOneWidget);
      // The photo branch, not the placeholder — this is the one card where the
      expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
      expect(_confirmCta, findsOneWidget);
      // `receipt_not_yet_cta` is below the fold on the harness surface and this
    });
  });

  // `previewCanvas` pumps onto the 800 x 600 test surface, not the `size:` a
  group('DeliveryReceiptScreen previews · measured at 390 x 844', () {
    Future<void> pumpPhone(
      WidgetTester tester,
      Widget Function() preview, {
      required Locale locale,
      required double textScale,
    }) async {
      tester.view.physicalSize = const Size(1170, 2532); // 390 x 844 @3x
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(previewCanvas(preview, locale));
      await tester.pumpAndSettle();
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('the longest cash line survives 200% text in '
          '${locale.languageCode}', (WidgetTester tester) async {
        await pumpPhone(
          tester,
          deliveryReceiptScreenLongContent,
          locale: locale,
          textScale: 2,
        );

        // `Icon + Expanded(Text)` inside the primary-container pill: the text
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the proof-photo slot does NOT grow with text scale', (
      WidgetTester tester,
    ) async {
      await pumpPhone(
        tester,
        deliveryReceiptScreenAmountUnknown,
        locale: const Locale('en'),
        textScale: 2,
      );

      // Both branches hardcode `height: 200`, so at 200% text everything else
      expect(tester.getSize(_proofPhoto).height, 200);
    });

    testWidgets('at 100% text a 390 x 844 phone shows BOTH forks without '
        'scrolling', (WidgetTester tester) async {
      await pumpPhone(
        tester,
        deliveryReceiptScreenAmountUnknown,
        locale: const Locale('en'),
        textScale: 1,
      );

      // The confirm/dispute fork is the whole screen. On the device these
      expect(_confirmCta, findsOneWidget);
      expect(_notYetCta, findsOneWidget);
      expect(tester.getBottomLeft(_notYetCta).dy, lessThanOrEqualTo(844));
    });

    testWidgets('at 200% text the dispute fork drops below the fold', (
      WidgetTester tester,
    ) async {
      await pumpPhone(
        tester,
        deliveryReceiptScreenAmountUnknown,
        locale: const Locale('en'),
        textScale: 2,
      );

      // Neither CTA is even BUILT. The 200 pt photo slot is a hardcoded height
      expect(find.text(_promptHeading), findsOneWidget);
      expect(_confirmCta, findsNothing);
      expect(_notYetCta, findsNothing);

      // It is reachable, just not visible: the body scrolls.
      await _revealNotYetCta(tester);
      expect(_confirmCta, findsOneWidget);
      expect(_notYetCta, findsOneWidget);
    });
  });
}
