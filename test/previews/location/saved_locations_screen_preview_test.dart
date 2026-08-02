// Render tests for the SavedLocationsScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// Every state pins a DISTINCT string, which matters more for a screen than for
// a widget: all five previews are the same screen behind the same app bar and
// the same floating CTA, differing only in the fake repository they are
// constructed with. A suite that asserted "the app bar rendered" would pass
// with every preview wired to the same fake.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/location/presentation/saved_locations_screen.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Loading · spinner`, which cannot settle — see the
  // dedicated group below.
  testPreviewsRender(
    'SavedLocationsScreen',
    const <String, Widget Function()>{
      'Loaded · Home + Office': savedLocationsScreenLoaded,
      'Empty · nothing saved': savedLocationsScreenEmpty,
      'Error · load failed': savedLocationsScreenError,
      'Ten saved · at the cap': savedLocationsScreenAtCapacity,
    },
    expectedText: const <String, String>{
      // The default row's address. `Home` alone would not do: the at-cap
      // fixture also has a default row, and the app bar title is shared by
      // every state.
      'Loaded · Home + Office': 'Sassine Square, Ashrafieh',
      'Empty · nothing saved': 'No saved addresses yet',
      'Error · load failed': 'Could not load saved locations. Please try again.',
      'Ten saved · at the cap':
          'Beirut Souks — Parking Level B2, Weygand Street entrance',
    },
  );

  // The loading sub-state is an indeterminate `CircularProgressIndicator`
  // (`OmdsLoadingState`) held open by a read that never lands. `pumpAndSettle`
  // — which `pumpPreview` calls — never returns while one is on screen, so this
  // preview gets the same three assertions the shared suite makes (builds in
  // EN, builds in AR, renders its OWN state) driven by fixed pumps instead.
  group('SavedLocationsScreen previews · Loading · spinner', () {
    Future<void> pumpLoading(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(savedLocationsScreenLoading, locale),
      );
      await tester.pump(); // resolve localizations + the nested Router
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Loading · spinner · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpLoading(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Loading · spinner renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      // The spinner is up...
      expect(find.byType(OmdsLoadingState), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // ...and none of the three settled surfaces is. That combination is true
      // of no other preview in this file.
      expect(find.byKey(const Key('saved-locations-empty')), findsNothing);
      expect(find.byKey(const Key('saved-locations-error')), findsNothing);
      expect(find.byType(ListView), findsNothing);
    });

    // The finding this preview exists for. `_AddAddressFab` is built with
    // `enabled: false` during the load, which resolves to `onPressed: null` —
    // but `FloatingActionButton.extended` has no disabled rendering, so the CTA
    // keeps its filled container and its full-opacity label. It looks exactly
    // like the working one and silently swallows the tap.
    testWidgets('the Add CTA is inert during the load but looks identical', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      final FloatingActionButton fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.onPressed, isNull);
      // No disabled treatment of any kind is applied — same label, and no
      // colour override to distinguish it from the enabled state below.
      expect(find.text('Add new location'), findsOneWidget);
      expect(fab.backgroundColor, isNull);
      expect(fab.foregroundColor, isNull);
    });
  });

  group('SavedLocationsScreen preview specifics', () {
    // Each state gets its OWN test. Every preview here is the same widget tree
    // — `_SavedLocationsScreenHost` → `Router` → `SavedLocationsScreen` —
    // differing only in the repository handed to it, so pumping a second
    // preview into the same tester would reuse the first preview's element and
    // with it the first preview's cubit.

    testWidgets('the loaded preview shows the JM-049 signature ids', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, savedLocationsScreenLoaded);

      expect(
        find.bySemanticsIdentifier('saved_address_add_cta'),
        findsOneWidget,
      );
      // Home is the default and Office is not → exactly one badge.
      expect(
        find.bySemanticsIdentifier('saved_address_default_badge'),
        findsOneWidget,
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Office'), findsOneWidget);
      expect(find.text('Beirut Tower, Downtown'), findsOneWidget);
    });

    // Regression guard for the defect `_EditButton` documents in prose: a
    // button-flagged `Semantics` with no action of its own is merged into the
    // enclosing tile `InkWell` and loses its `identifier`, which happened
    // precisely on the row that ALSO carried `saved_address_default_badge`.
    // Row 0 of this fixture is that row.
    testWidgets('row-0 edit/more ids survive alongside the default badge', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, savedLocationsScreenLoaded);

      expect(
        find.bySemanticsIdentifier('saved_address_default_badge'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('saved_address_0_edit'), findsOneWidget);
      expect(find.bySemanticsIdentifier('saved_address_0_more'), findsOneWidget);
      expect(find.bySemanticsIdentifier('saved_address_1_edit'), findsOneWidget);
    });

    testWidgets('the empty preview keeps the Add CTA and drops the rows', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, savedLocationsScreenEmpty);

      expect(find.byKey(const Key('saved-locations-empty')), findsOneWidget);
      expect(find.byType(OmdsEmptyState), findsOneWidget);
      // AC5: the signature id is present in EVERY non-fatal state, empty
      // included — the zero-state is guidance only.
      expect(
        find.bySemanticsIdentifier('saved_address_add_cta'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('saved_address_default_badge'),
        findsNothing,
      );
      expect(find.bySemanticsIdentifier('saved_address_0_edit'), findsNothing);
    });

    testWidgets('the error preview offers retry — and still offers Add', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, savedLocationsScreenError);

      expect(find.byKey(const Key('saved-locations-error')), findsOneWidget);
      expect(find.byType(OmdsErrorState), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byKey(const Key('saved-locations-empty')), findsNothing);

      // The FAB is gated on loading/mutating only, so a list that failed to
      // load still offers "Add new location": a user can add a duplicate of an
      // address the manager is currently unable to show them.
      final FloatingActionButton fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.onPressed, isNotNull);
    });

    testWidgets('the at-cap preview renders the cap-length list', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, savedLocationsScreenAtCapacity);

      // Row 0: longest label + longest address + the default badge, all on one
      // line. Row 1 has no address at all — the tile's other layout.
      expect(
        find.text('Beirut Souks — Parking Level B2, Weygand Street entrance'),
        findsOneWidget,
      );
      expect(find.text('Teta'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('saved_address_default_badge'),
        findsOneWidget,
      );
      // Distinctness from the two-row fixture, which the shared suite pins by
      // text: this list has rows the Home/Office account never has.
      expect(find.text('Saved address 3'), findsOneWidget);
      expect(find.text('Sassine Square, Ashrafieh'), findsNothing);
    });
  });
}
