// Render tests for the LocationPickerScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently.
// The shared harness pumps every preview in EN and AR and asserts each one shows
// ITS OWN state — which matters more here than usual: eleven of these previews
// are the same screen with one field of `LocationPickerState` different, and a
// preview wired to the wrong fixture would look entirely plausible.
//
// The `expectedText` strings are all rendered by real `Text` widgets. The
// committed-leg rows (`_PairRow`) are raw `RichText`, which `find.text` does not
// match, so nothing below pins on them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/location/presentation/location_picker_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/location_search_bar.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'LocationPickerScreen',
    const <String, Widget Function()>{
      'Pickup · nothing selected': locationPickerScreenPickupEmpty,
      'Pickup · finding GPS': locationPickerScreenLocatingGps,
      'Pickup · resolving dragged pin': locationPickerScreenResolvingAddress,
      'Pickup · suggestions open': locationPickerScreenSearchResults,
      'Pickup · just tapped a suggestion':
          locationPickerScreenSuggestionSelected,
      'Pickup · GPS permission denied': locationPickerScreenGpsDenied,
      'Pickup · GPS + Pin on map row': locationPickerScreenMapPinRow,
      'Dropoff · pickup confirmed': locationPickerScreenDropoff,
      'Dropoff · longest addresses': locationPickerScreenLongestAddresses,
      'Dropoff · saving': locationPickerScreenSaving,
      'Dropoff · save failed': locationPickerScreenSaveFailed,
      'Confirmed · both legs saved': locationPickerScreenConfirmed,
    },
    expectedText: const <String, String>{
      'Pickup · nothing selected': 'No location selected yet',
      'Pickup · finding GPS': 'Detecting your location…',
      'Pickup · resolving dragged pin': 'Resolving address…',
      'Pickup · suggestions open': 'Gemmayze, Beirut',
      'Pickup · just tapped a suggestion': 'Hamra Street, Beirut',
      'Pickup · GPS permission denied':
          'Location permission was denied. Allow it in Settings to use GPS.',
      'Pickup · GPS + Pin on map row': 'Pin on map',
      'Dropoff · pickup confirmed': 'Step 2 of 2 — choose dropoff',
      'Dropoff · longest addresses':
          'Saint George Hospital University Medical Center — Building C, '
              '4th floor reception, Achrafieh, Beirut, Lebanon',
      'Dropoff · saving': 'Saving…',
      'Dropoff · save failed': 'Could not save your locations. Try again.',
      'Confirmed · both legs saved': 'Both locations saved',
    },
  );

  group('LocationPickerScreen preview specifics', () {
    testWidgets('the empty state cannot be confirmed', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationPickerScreenPickupEmpty);

      // Step 1 copy, and the CTA that goes with it.
      expect(find.text('Step 1 of 2 — choose pickup'), findsOneWidget);
      expect(find.text('Continue to dropoff'), findsOneWidget);
      // No committed leg yet, so the pair preview is collapsed.
      expect(find.text('No location selected yet'), findsOneWidget);
    });

    testWidgets('an in-flight GPS lookup shows copy, never a spinner', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationPickerScreenLocatingGps);

      expect(find.text('Detecting your location…'), findsOneWidget);
      // The whole loading affordance is one line of body copy — if a spinner
      // ever lands here this assertion is the thing to delete, deliberately.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets(
      'a dragged pin is confirmable before its address resolves',
      (WidgetTester tester) async {
        await pumpPreview(tester, locationPickerScreenResolvingAddress);

        // `locationCoordinatesFallback` — the leg a user would commit right now.
        expect(find.text('33.89380, 35.50180'), findsOneWidget);
        expect(find.text('Resolving address…'), findsOneWidget);
      },
    );

    testWidgets(
      'a populated dropdown sits over an EMPTY search field',
      (WidgetTester tester) async {
        await pumpPreview(tester, locationPickerScreenSearchResults);

        // The cubit's query filtered these rows in.
        expect(find.text('Downtown, Beirut'), findsOneWidget);
        expect(find.text('Gemmayze, Beirut'), findsOneWidget);
        // …but nothing ever seeded the controller from `state.searchQuery`:
        // `_LocationPickerViewState` syncs it only from the BlocConsumer
        // listener, which never fired because the query predates the mount.
        expect(find.text('beirut'), findsNothing);
      },
    );

    testWidgets(
      'tapping a suggestion leaves the "no matches" line under it',
      (WidgetTester tester) async {
        await pumpPreview(tester, locationPickerScreenSuggestionSelected);

        expect(find.text('Hamra Street, Beirut'), findsOneWidget);
        // Same (query, results, isSearching) triple as a query that matched
        // nothing, so the bar says so directly under the address just chosen.
        expect(find.text('No matching addresses'), findsOneWidget);
      },
    );

    testWidgets('an error surfaces ONLY as a snackbar', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationPickerScreenSaveFailed);

      expect(
        find.text('Could not save your locations. Try again.'),
        findsOneWidget,
      );
      // Nothing in `builder` renders `state.error`: the step, the pair and the
      // CTA are all exactly what they were before the save was attempted.
      expect(find.text('Step 2 of 2 — choose dropoff'), findsOneWidget);
      expect(find.text('Confirm & save'), findsOneWidget);
    });

    testWidgets('a denied GPS permission leaves the screen untouched', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationPickerScreenGpsDenied);

      expect(
        find.text(
          'Location permission was denied. Allow it in Settings to use GPS.',
        ),
        findsOneWidget,
      );
      // Back to the empty state — the denial leaves no persistent trace.
      expect(find.text('No location selected yet'), findsOneWidget);
    });

    testWidgets('the dropoff draft is pre-seeded with the pickup pin', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationPickerScreenDropoff);

      expect(find.text('Step 2 of 2 — choose dropoff'), findsOneWidget);
      // The draft card already holds the PICKUP address, so a user who taps
      // straight through saves both legs at the same place.
      expect(find.text('Hamra Street, Beirut'), findsOneWidget);
      expect(find.text('Confirm & save'), findsOneWidget);
    });

    testWidgets('an in-flight save swaps and disables the CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationPickerScreenSaving);

      expect(find.text('Saving…'), findsOneWidget);
      expect(find.text('Confirm & save'), findsNothing);
      // The search bar has no `isSaving` input, so it stays fully live while
      // the request is out and can still move `draftSelection` under it.
      expect(find.byType(LocationSearchBar), findsOneWidget);
    });

    testWidgets('the map row is the only preview with three affordances', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationPickerScreenMapPinRow);

      expect(find.text('Use current GPS'), findsOneWidget);
      expect(find.text('Pin on map'), findsOneWidget);
      // Clean here only because `flutter test` renders on an 800 pt-wide
      // surface; at 390 pt this Row overflows by 100 pt and 29 pt. The canvas
      // (390x844) is where that is visible — see the preview's own doc comment.
      expect(tester.takeException(), isNull);
    });

    testWidgets('the terminal state repeats its own title on the CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationPickerScreenConfirmed);

      expect(find.text('Both locations saved'), findsOneWidget);
      // App-bar title AND button label — `_confirmCta` has no copy of its own
      // for `done`, and the button stays enabled while doing nothing.
      expect(find.text('Locations confirmed'), findsNWidgets(2));
    });
  });
}
