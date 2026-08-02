// Render tests for the ClientOffersScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// This screen picks ONE of three bodies off `ClientOffersState` — spinner,
// centred error, or the list — and then stacks a variable amount of chrome
// (countdown band, closed banner, error strip) above the cards, so most of these
// previews would satisfy a render-only check while showing the wrong surface
// entirely. An "empty" preview whose fixture started throwing looks exactly like
// the failure state to a render-only assertion. Every state therefore pins a
// string only IT can produce, and the groups below pin the contracts the pairs
// exist for: empty vs failed, and locally-elapsed vs server-expired.
//
// ## Two font facts this suite depends on
//
// **1. The real face has to be loaded.** Widget tests lay out with the
// FlutterTest font, whose every glyph is one em wide — it measures
// `OfferSortBar` at 389 dp where the shipping Inter measures 238 (the geometry
// group in `offer_sort_bar_preview_test.dart` pins both numbers). This screen
// hands that bar a 358 dp slot on a 390 dp phone, so WITHOUT `loadInterTestFont`
// every loaded state here throws `RenderFlex overflowed by 31 pixels` and the
// shared render suite fails on a defect that exists on no device.
//
// **2. Arabic is still laid out in the fake face, and there is no fix for that
// from here.** `loadInterTestFont` registers a Noto Arabic subset under its own
// family, but the preview canvas builds `AppTheme.light()` unmodified, and the
// theme carries no `fontFamilyFallback` — that is what `withGoldenTestFonts`
// exists to add, and only the golden suites apply it. So every Arabic glyph in
// these tests falls back to the 1-em test face and Arabic strings measure far
// wider than they ever do on a device. Measured through the golden fonts, the
// sort bar is **238 dp in EN and 223.6 dp in AR**, against slots of 358 dp
// (390 pt phone) and 288 dp (320 pt phone) — comfortable in every combination.
// Under the fake face the AR bar measures 303 dp, which still fits the 358 dp
// slot and does NOT fit the 288 dp one. That is why exactly one group below
// tolerates an overflow, and why it tolerates it only in Arabic.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/client_offers/presentation/client_offers_screen.dart';

import '../../support/load_test_fonts.dart';
import '../preview_test_harness.dart';

/// The longest-content preview's Jeeber. Declared here rather than imported so a
/// preview quietly rewired to a short fixture fails instead of silently losing
/// the one state that contests the 320 pt frame.
const String _kLongestName = 'Alexander Bartholomew Montgomery the Third';

/// The scrollable inside the offers list, for the states whose evidence sits
/// below the fold: the render surface is 800x600, so a preview asking for a
/// 844 pt phone gets ~600 and the third card is off-screen.
Finder get _offerList => find.descendant(
  of: find.byKey(const Key('offer-list')),
  matching: find.byType(Scrollable),
);

/// Pumps [preview] with framework errors intercepted rather than recorded.
///
/// `tester.takeException()` cannot be used to inspect them: once a second error
/// lands the binding collapses both into "Multiple exceptions (2) were
/// detected…", which says nothing about what they were. Taking them at
/// [FlutterError.onError] keeps each one, so the caller can decide which are
/// tolerable — and every error still has to be accounted for, because the
/// handler is restored before any assertion runs.
Future<List<FlutterErrorDetails>> _pumpCatchingErrors(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = caught.add;
  try {
    await pumpPreview(tester, preview, locale: locale);
  } finally {
    FlutterError.onError = previous;
  }
  return caught;
}

void main() {
  setUpAll(loadPreviewArbs);
  setUpAll(loadInterTestFont);

  // Every preview except `Loading · cold read`, whose spinner cannot settle, and
  // `Longest content · compact 320`, whose Arabic rendering trips the font
  // artifact described above. Both get a dedicated group.
  testPreviewsRender(
    'ClientOffersScreen',
    const <String, Widget Function()>{
      'Fresh window · three bids': clientOffersScreenFreshWindow,
      'Empty · no bids yet': clientOffersScreenEmpty,
      'Load failed · network': clientOffersScreenLoadFailed,
      'Refresh failed · list kept': clientOffersScreenRefreshFailed,
      'Window elapsed locally · offers still live':
          clientOffersScreenElapsedWindow,
      'Request closed': clientOffersScreenRequestClosed,
      'Server-expired · terminal': clientOffersScreenServerExpired,
    },
    expectedText: const <String, String>{
      // The cheapest bid, first in the default price-ascending order. Unique to
      // this fixture's cast.
      'Fresh window · three bids': 'Karim Nassar',
      // A read that came back with nothing while the window is still open.
      'Empty · no bids yet': 'Waiting for offers',
      // The classified network branch of the COLD failure.
      'Load failed · network': 'Check your connection, then retry.',
      // …and the generic LOAD-phase fallback, which only the inline banner
      // renders here. A load failure must never say "accepting".
      'Refresh failed · list kept': "Couldn't load offers. Retry.",
      // The frozen local countdown — NOT "Offer window expired".
      'Window elapsed locally · offers still live': 'Window: 0:00 left',
      // The lock banner is shared with the server-expired state, so this pins
      // the cast instead.
      'Request closed': 'Nour Haddad',
      // Only a terminal server snapshot renders this band.
      'Server-expired · terminal': 'Offer window expired',
    },
  );

  // The ceiling state, on the one frame narrow enough for the missing Arabic
  // face to matter. It gets the same three assertions the shared suite makes —
  // builds in EN, builds in AR, renders its OWN state — with the AR pass
  // tolerating overflow and nothing else.
  //
  // The tolerance is deliberately NOT "this screen overflows at 320 pt". Through
  // the golden fonts the bar is 223.6 dp of content in a 288 dp slot; the
  // overflow appears only because the test face is ~35% wider per Arabic glyph.
  // Widening the frame until it disappears would have been the other way to make
  // this suite green, and it would have thrown away the one preview that shows
  // the 200% ceiling on the narrowest supported phone.
  group('ClientOffersScreen previews · Longest content · compact 320', () {
    testWidgets('Longest content · compact 320 · en', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientOffersScreenLongestContent);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Longest content · compact 320 · ar', (
      WidgetTester tester,
    ) async {
      final List<FlutterErrorDetails> caught = await _pumpCatchingErrors(
        tester,
        clientOffersScreenLongestContent,
        locale: const Locale('ar'),
      );

      for (final FlutterErrorDetails details in caught) {
        expect(
          details.exception.toString(),
          contains('overflowed'),
          reason: 'only the documented Arabic test-font overflow is tolerated',
        );
      }
      // Nothing may reach the binding either — an error raised outside the
      // intercepted pump is not covered by the note above.
      expect(tester.takeException(), isNull);
    });

    testWidgets('Longest content · compact 320 renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientOffersScreenLongestContent);

      expect(find.text(_kLongestName), findsOneWidget);
    });
  });

  // The loading body is an `OmdsLoadingState`, i.e. a repeating
  // `CircularProgressIndicator`. `pumpAndSettle` (which `pumpPreview` calls)
  // never returns while one is on screen, so this preview gets the same three
  // assertions the shared suite makes, driven by fixed pumps instead. It has no
  // text to pin at all, so its state is pinned by the indicator plus the absence
  // of every other body.
  group('ClientOffersScreen previews · Loading · cold read', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(clientOffersScreenLoading, locale));
      await tester.pump(); // the mount-time load() emit
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · cold read · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpLoading(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · cold read renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      // None of the three other bodies, and none of the chrome the loaded body
      // stacks above them.
      expect(find.byKey(const Key('offer-list')), findsNothing);
      expect(find.byKey(const Key('offer-empty-state')), findsNothing);
      expect(find.byKey(const Key('offer-load-error')), findsNothing);
      expect(find.byKey(const Key('offer-window-timer')), findsNothing);
      // …and nothing to tap. The whole body is replaced for as long as the read
      // takes, which on a 429 back-off is Retry-After seconds of a bare spinner.
      expect(find.byKey(const Key('offer-review-cancel-cta')), findsNothing);
    });
  });

  group('ClientOffersScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    // does NOT rebuild these — `previewCanvas` produces the same widget types,
    // so the `BlocProvider` element is UPDATED rather than replaced and keeps
    // the cubit the first preview created.
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
      // the host would measure 800 here, and none of this layout applies there.
      await pumpPreview(tester, clientOffersScreenFreshWindow);

      expect(tester.getSize(find.byType(ClientOffersScreen)).width, 390);
    });

    testWidgets('the longest-content preview pins the 320 x 568 floor', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientOffersScreenLongestContent);

      expect(
        tester.getSize(find.byType(ClientOffersScreen)),
        const Size(320, 568),
      );
    });

    testWidgets('the reference state renders every bid, cheapest first', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientOffersScreenFreshWindow);

      expect(find.byKey(const Key('offer-card-bid-karim')), findsOneWidget);
      expect(find.byKey(const Key('offer-card-bid-hadi')), findsOneWidget);
      // Default sort is price ascending: $4.50 → $6.00 → $9.25.
      expect(
        tester.getTopLeft(find.byKey(const Key('offer-card-bid-karim'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('offer-card-bid-hadi'))).dy,
        ),
      );

      // The third card and the Cancel CTA are below the fold on the 600 pt test
      // surface, which is itself worth knowing: on a real 844 pt phone the same
      // three cards do not fit either.
      await tester.scrollUntilVisible(
        find.byKey(const Key('offer-review-cancel-cta')),
        200,
        scrollable: _offerList,
      );
      expect(find.byKey(const Key('offer-card-bid-rana')), findsOneWidget);
      // The unrated bid shows the honest cold-start line, not a fabricated
      // "0.0 (0)" — the SW-08 contract, visible only when a fixture has one.
      expect(find.text('No ratings yet'), findsOneWidget);
      // Free pre-accept cancel (D69) is offered while the request is open.
      expect(find.byKey(const Key('offer-review-cancel-cta')), findsOneWidget);
    });

    // The empty/failed pair. A failed read leaves `offers` empty too, so a body
    // that tested emptiness first would render "Waiting for offers" over a read
    // that never happened — a claim about server data with no evidence behind
    // it, and the reason both states are previewed adjacently.
    testWidgets('the empty preview is the EMPTY state, not the error one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientOffersScreenEmpty);

      expect(find.byKey(const Key('offer-empty-state')), findsOneWidget);
      expect(find.byKey(const Key('offer-load-error')), findsNothing);
      // The window band and the sort bar still render above the empty state.
      expect(find.byKey(const Key('offer-window-timer')), findsOneWidget);
      expect(find.byKey(const Key('offer-sort-price')), findsOneWidget);
    });

    testWidgets('the failure body is an error with a retry, never the empty '
        'state', (WidgetTester tester) async {
      await pumpPreview(tester, clientOffersScreenLoadFailed);

      expect(find.byKey(const Key('offer-load-error')), findsOneWidget);
      expect(find.byKey(const Key('offer-empty-state')), findsNothing);
      expect(find.text('Waiting for offers'), findsNothing);
      // An error the user cannot act on is barely better than the empty state
      // it replaced.
      expect(find.text('Retry'), findsOneWidget);
      // The cold failure replaces the whole body — there is no stale list left.
      expect(find.byKey(const Key('offer-list')), findsNothing);
    });

    testWidgets('a failed refresh KEEPS the list and adds a dismissible strip', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientOffersScreenRefreshFailed);

      expect(find.byKey(const Key('offer-error-banner')), findsOneWidget);
      // Non-destructive: the bid the customer can still accept is untouched,
      // and the full-screen error body never appears.
      expect(find.byKey(const Key('offer-card-bid-layal')), findsOneWidget);
      expect(find.byKey(const Key('offer-load-error')), findsNothing);
    });

    // The locally-elapsed / server-expired pair — one boolean apart, and the
    // whole reason `requestIsExpired` exists separately from `windowExpiresAt`.
    testWidgets('a locally elapsed window neither expires the band nor '
        'disables Accept', (WidgetTester tester) async {
      await pumpPreview(tester, clientOffersScreenElapsedWindow);

      expect(find.text('Window: 0:00 left'), findsOneWidget);
      expect(find.text('Offer window expired'), findsNothing);
      expect(find.byKey(const Key('offer-request-closed-banner')), findsNothing);
      expect(
        tester
            .widget<OmdsPrimaryButton>(
              find.byKey(const Key('offer-card-accept-bid-ziad')),
            )
            .isEnabled,
        isTrue,
        reason: 'request status is the action authority, not the local clock',
      );
    });

    testWidgets('only a terminal server snapshot expires the band and locks '
        'Accept', (WidgetTester tester) async {
      await pumpPreview(tester, clientOffersScreenServerExpired);

      expect(find.text('Offer window expired'), findsOneWidget);
      expect(
        find.byKey(const Key('offer-request-closed-banner')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OmdsPrimaryButton>(
              find.byKey(const Key('offer-card-accept-bid-fadi')),
            )
            .isEnabled,
        isFalse,
      );
      // Nothing left to cancel once the request is closed.
      expect(find.byKey(const Key('offer-review-cancel-cta')), findsNothing);
    });

    testWidgets('a closed request locks Accept without an expired band', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientOffersScreenRequestClosed);

      expect(
        find.byKey(const Key('offer-request-closed-banner')),
        findsOneWidget,
      );
      // No deadline in the snapshot and no lifecycle flag → no countdown at all.
      expect(find.byKey(const Key('offer-window-timer')), findsNothing);
      // The CTA stays MOUNTED and inert: the card must not change height while
      // the list settles under the customer's finger.
      expect(
        tester
            .widget<OmdsPrimaryButton>(
              find.byKey(const Key('offer-card-accept-bid-nour')),
            )
            .isEnabled,
        isFalse,
      );
    });

    testWidgets('the ceiling state suppresses a UUID name and promotes the '
        '24 h window', (WidgetTester tester) async {
      await pumpPreview(tester, clientOffersScreenLongestContent);

      // `CountdownFormat` promotes the minutes field instead of letting it
      // overflow — the `1433:18` regression, at the width it broke on.
      expect(find.text('Window: 23:53:18 left'), findsOneWidget);
      expect(find.text(_kLongestName), findsOneWidget);

      // The second card carries the un-enriched row. Scroll it in: at 320x568
      // the ceiling card alone is most of the viewport.
      await tester.scrollUntilVisible(
        find.byKey(const Key('offer-card-bid-uuid')),
        200,
        scrollable: _offerList,
      );
      // SW-08: the raw identifier reaches no pixel of the card, and the avatar
      // initial comes from the RESOLVED name.
      expect(
        find.textContaining('9acb579d'),
        findsNothing,
        reason: 'an un-enriched offer row must never headline a UUID as a name',
      );
      expect(find.text('New Jeeber'), findsOneWidget);
    });
  });
}
