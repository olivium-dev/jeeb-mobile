// Render tests for the OfferAcceptSheet previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. Every state below pins a DISTINCT string — five
// previews of the same sheet would otherwise all pass while showing the same
// thing — and the state whose difference is a spinner rather than copy gets its
// own group, because `pumpAndSettle` never returns with an indeterminate
// `CircularProgressIndicator` on screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_accept_sheet.dart';

import '../preview_test_harness.dart';

/// The inline failure banner the sheet renders only in `OfferAcceptStatus.failed`.
final Finder _errorBanner = find.byKey(const Key('offer-accept-error'));

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Submitting · B-01 lock` — see the dedicated group.
  testPreviewsRender(
    'OfferAcceptSheet',
    const <String, Widget Function()>{
      'Idle · named Jeeber': offerAcceptSheetIdle,
      'Failed · request closed (409)': offerAcceptSheetFailedRequestClosed,
      'Failed · Jeeber at capacity': offerAcceptSheetFailedAtCapacity,
      'Synthetic handle suppressed': offerAcceptSheetSyntheticHandle,
      'Long name · LBP fee': offerAcceptSheetLongContent,
    },
    expectedText: const <String, String>{
      // SW-14: the title is a QUESTION about a pending act, never the
      // past-tense chat system message it used to borrow.
      'Idle · named Jeeber': "Accept Kamal Hajj's offer?",
      // sprint-009 scenario #7 — the 409 accept race, spoken out loud.
      'Failed · request closed (409)': 'This request is no longer open.',
      // fix/offer-accept-409-mislabel — BR-10 gets its OWN copy.
      'Failed · Jeeber at capacity':
          'This Jeeber already has the maximum active deliveries. Choose another offer.',
      // W6/SW-08 — the synthetic handle is replaced, not rendered.
      'Synthetic handle suppressed': "Accept New Jeeber's offer?",
      'Long name · LBP fee':
          "Accept Abdulrahman Al-Muhandis Al-Trabulsi's offer?",
    },
  );

  // `OfferAcceptStatus.submitting` swaps the Confirm label for
  // `OmdsButtonLoading`, i.e. an INDETERMINATE `CircularProgressIndicator`.
  // `pumpAndSettle` (which `pumpPreview` calls) never returns while one is on
  // screen, so this preview gets the same three assertions the shared suite
  // makes — builds in EN, builds in AR, renders its OWN state — driven by fixed
  // pumps instead.
  group('OfferAcceptSheet previews · Submitting · B-01 lock', () {
    Future<void> pumpSubmitting(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(offerAcceptSheetSubmitting, locale),
      );
      await tester.pump(); // resolve localizations
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Submitting · B-01 lock · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpSubmitting(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Submitting · B-01 lock renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpSubmitting(tester);

      // Still the same offer being confirmed…
      expect(find.text("Accept Kamal Hajj's offer?"), findsOneWidget);
      // …but the Confirm label has been replaced by the spinner, and no failure
      // has been reported. That triple is true of no other preview in this file.
      expect(find.text('Accept Offer'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_errorBanner, findsNothing);
    });

    testWidgets('B-01 — both CTAs are untappable while the accept is in flight',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpSubmitting(tester);

      // The accept POST is the accept-exactly-ONE moment: a live tap target
      // here is how a customer fires a second accept (Confirm) or tears the
      // sheet down mid-POST and goes to accept a different offer (Cancel).
      for (final String id in const <String>[
        'offer_accept_confirm_cta',
        'offer_accept_cancel_cta',
      ]) {
        expect(
          tester.getSemantics(find.bySemanticsIdentifier(id)),
          isSemantics(identifier: id, isButton: true, hasTapAction: false),
          reason: '$id must be inert while state.isSubmitting',
        );
      }
      handle.dispose();
    });
  });

  group('OfferAcceptSheet preview specifics', () {
    testWidgets('SW-14 — the title asks, it never reports', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerAcceptSheetIdle);

      // NEGATIVE control for the copy this slot used to borrow from chat
      // (`chatSystemOfferAcceptedNamed`, "{name}'s offer was accepted").
      expect(find.textContaining('was accepted'), findsNothing);
    });

    testWidgets('W6/SW-08 — the raw jeeb-<hash> never reaches the title', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerAcceptSheetSyntheticHandle);

      expect(find.textContaining('jeeb-e1a35ea8a520'), findsNothing);
      expect(find.text("Accept New Jeeber's offer?"), findsOneWidget);
    });

    // The guard against every preview in this file seeding the same state:
    // the three idle states must show no inline banner, the two failed ones
    // must. Each preview gets its OWN test on purpose — re-pumping a second
    // `OfferAcceptSheet` into a live tree reuses the `BlocProvider` element and
    // never re-runs `create`, so a loop inside one test would silently review
    // the FIRST preview's cubit five times over.
    for (final MapEntry<String, Widget Function()> entry
        in <String, Widget Function()>{
      'Idle · named Jeeber': offerAcceptSheetIdle,
      'Synthetic handle suppressed': offerAcceptSheetSyntheticHandle,
      'Long name · LBP fee': offerAcceptSheetLongContent,
    }.entries) {
      testWidgets('${entry.key} carries no inline error banner', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, entry.value);

        expect(_errorBanner, findsNothing);
      });
    }

    for (final MapEntry<String, Widget Function()> entry
        in <String, Widget Function()>{
      'Failed · request closed (409)': offerAcceptSheetFailedRequestClosed,
      'Failed · Jeeber at capacity': offerAcceptSheetFailedAtCapacity,
    }.entries) {
      testWidgets('${entry.key} carries the inline error banner', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, entry.value);

        expect(_errorBanner, findsOneWidget);
        // …and it is announced, not just drawn: a failure the customer cannot
        // see (they were watching the spinner) must still reach them.
        expect(
          find.bySemanticsIdentifier('offer_accept_error'),
          findsOneWidget,
        );
        // The sheet stays usable: confirm is retryable, cancel is available.
        expect(
          find.bySemanticsIdentifier('offer_accept_confirm_cta'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('offer_accept_cancel_cta'),
          findsOneWidget,
        );
      });
    }

    testWidgets(
        'fix/offer-accept-409-mislabel — capacity never borrows the '
        '"offer no longer available" copy', (WidgetTester tester) async {
      await pumpPreview(tester, offerAcceptSheetFailedAtCapacity);

      // BR-10 means the OFFER is still pending upstream; saying it is gone
      // sends the customer looking for a bid that has not moved.
      expect(find.text('This offer is no longer available.'), findsNothing);
      expect(find.text('This request is no longer open.'), findsNothing);
    });

    testWidgets('the LBP fee keeps its LTR isolate and thousands grouping', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, offerAcceptSheetLongContent);

      // U+2066 LEFT-TO-RIGHT ISOLATE … U+2069 POP DIRECTIONAL ISOLATE. Without
      // them the amount reorders under the AR rendering of the matrix, which is
      // the whole reason MoneyFormat emits them.
      expect(
        find.text('\u2066LBP 4,500,000.00\u2069'),
        findsOneWidget,
        reason: 'the fee must stay LTR-isolated and grouped',
      );
    });
  });
}
