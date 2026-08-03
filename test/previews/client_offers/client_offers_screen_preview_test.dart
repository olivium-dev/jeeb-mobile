// Render tests for the ClientOffersScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/client_offers/presentation/client_offers_screen.dart';

import '../../support/load_test_fonts.dart';
import '../preview_test_harness.dart';

/// The longest-content preview's Jeeber. Declared here rather than imported so a
/// preview quietly rewired to a short fixture fails instead of silently losing
const String _kLongestName = 'Alexander Bartholomew Montgomery the Third';

/// The scrollable inside the offers list, for the states whose evidence sits
/// below the fold: the render surface is 800x600, so a preview asking for a
Finder get _offerList => find.descendant(
  of: find.byKey(const Key('offer-list')),
  matching: find.byType(Scrollable),
);

/// Pumps [preview] with framework errors intercepted rather than recorded.
/// `tester.takeException()` cannot be used to inspect them: once a second error
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
      'Fresh window · three bids': 'Karim Nassar',
      // A read that came back with nothing while the window is still open.
      'Empty · no bids yet': 'Waiting for offers',
      // The classified network branch of the COLD failure.
      'Load failed · network': 'Check your connection, then retry.',
      // …and the generic LOAD-phase fallback, which only the inline banner
      'Refresh failed · list kept': "Couldn't load offers. Retry.",
      // The frozen local countdown — NOT "Offer window expired".
      'Window elapsed locally · offers still live': 'Window: 0:00 left',
      // The lock banner is shared with the server-expired state, so this pins
      'Request closed': 'Nour Haddad',
      // Only a terminal server snapshot renders this band.
      'Server-expired · terminal': 'Offer window expired',
    },
  );

  // The ceiling state, on the one frame narrow enough for the missing Arabic
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
      expect(find.byKey(const Key('offer-list')), findsNothing);
      expect(find.byKey(const Key('offer-empty-state')), findsNothing);
      expect(find.byKey(const Key('offer-load-error')), findsNothing);
      expect(find.byKey(const Key('offer-window-timer')), findsNothing);
      // …and nothing to tap. The whole body is replaced for as long as the read
      expect(find.byKey(const Key('offer-review-cancel-cta')), findsNothing);
    });
  });

  group('ClientOffersScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester
    testWidgets('the phone previews pin a 390 pt frame, not the canvas width', (
      WidgetTester tester,
    ) async {
      // The harness pumps an 800 pt surface: a preview that left its width to
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
      await tester.scrollUntilVisible(
        find.byKey(const Key('offer-review-cancel-cta')),
        200,
        scrollable: _offerList,
      );
      expect(find.byKey(const Key('offer-card-bid-rana')), findsOneWidget);
      // The unrated bid shows the honest cold-start line, not a fabricated
      expect(find.text('No ratings yet'), findsOneWidget);
      // Free pre-accept cancel (D69) is offered while the request is open.
      expect(find.byKey(const Key('offer-review-cancel-cta')), findsOneWidget);
    });

    // The empty/failed pair. A failed read leaves `offers` empty too, so a body
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
      expect(find.byKey(const Key('offer-card-bid-layal')), findsOneWidget);
      expect(find.byKey(const Key('offer-load-error')), findsNothing);
    });

    // The locally-elapsed / server-expired pair — one boolean apart, and the
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
      expect(find.text('Window: 23:53:18 left'), findsOneWidget);
      expect(find.text(_kLongestName), findsOneWidget);

      // The second card carries the un-enriched row. Scroll it in: at 320x568
      await tester.scrollUntilVisible(
        find.byKey(const Key('offer-card-bid-uuid')),
        200,
        scrollable: _offerList,
      );
      // SW-08: the raw identifier reaches no pixel of the card, and the avatar
      expect(
        find.textContaining('9acb579d'),
        findsNothing,
        reason: 'an un-enriched offer row must never headline a UUID as a name',
      );
      expect(find.text('New Jeeber'), findsOneWidget);
    });
  });
}
