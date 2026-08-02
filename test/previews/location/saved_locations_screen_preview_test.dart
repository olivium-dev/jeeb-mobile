// Render tests for the SavedLocationsScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/location/presentation/saved_locations_screen.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Loading · spinner`, which cannot settle — see the
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
      'Loaded · Home + Office': 'Sassine Square, Ashrafieh',
      'Empty · nothing saved': 'No saved addresses yet',
      'Error · load failed': 'Could not load saved locations. Please try again.',
      'Ten saved · at the cap':
          'Beirut Souks — Parking Level B2, Weygand Street entrance',
    },
  );

  // The loading sub-state is an indeterminate `CircularProgressIndicator`
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
      expect(find.byKey(const Key('saved-locations-empty')), findsNothing);
      expect(find.byKey(const Key('saved-locations-error')), findsNothing);
      expect(find.byType(ListView), findsNothing);
    });

    // The finding this preview exists for. `_AddAddressFab` is built with
    testWidgets('the Add CTA is inert during the load but looks identical', (
      WidgetTester tester,
    ) async {
      await pumpLoading(tester);

      final FloatingActionButton fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.onPressed, isNull);
      // No disabled treatment of any kind is applied — same label, and no
      expect(find.text('Add new location'), findsOneWidget);
      expect(fab.backgroundColor, isNull);
      expect(fab.foregroundColor, isNull);
    });
  });

  group('SavedLocationsScreen preview specifics', () {
    // Each state gets its OWN test. Every preview here is the same widget tree

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
      expect(find.text('Saved address 3'), findsOneWidget);
      expect(find.text('Sassine Square, Ashrafieh'), findsNothing);
    });
  });
}
