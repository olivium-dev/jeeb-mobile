// Render tests for the SavedLocationsChipRow previews.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/location/cubit/location_picker_cubit.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/saved_locations_chip_row.dart';

import '../preview_test_harness.dart';

/// The row is hidden: no heading, no chips, and the map stand-in flush against
/// the top of the canvas (T-MOB-012 AC3 — "the map is not pushed down").
void _expectRowHidden(WidgetTester tester) {
  expect(tester.takeException(), isNull);
  expect(find.text('Saved locations'), findsNothing);
  expect(find.byType(OmdsChip), findsNothing);
  expect(
    tester.getTopLeft(find.byKey(savedLocationsChipRowPreviewMapKey)).dy,
    0,
  );
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'SavedLocationsChipRow',
    const <String, Widget Function()>{
      'Home + Work': savedLocationsChipRowHomeAndWork,
      'Other · long + unnamed': savedLocationsChipRowOtherLabels,
      'Ten saved · at the cap': savedLocationsChipRowAtCap,
      'Empty · row hidden': savedLocationsChipRowEmpty,
      'Loading · row hidden': savedLocationsChipRowLoading,
      'Fetch failed · row hidden': savedLocationsChipRowFetchFailed,
    },
    // The widget paints nothing in three of these states, so the pinned string
    expectedText: const <String, String>{
      'Home + Work': 'fixture: home + work',
      'Other · long + unnamed': 'fixture: long + unnamed',
      'Ten saved · at the cap': 'fixture: ten at the cap',
      'Empty · row hidden': 'fixture: empty list',
      'Loading · row hidden': 'fixture: fetch never lands',
      'Fetch failed · row hidden': 'fixture: fetch throws',
    },
  );

  group('SavedLocationsChipRow preview specifics', () {
    testWidgets('a loaded chip shows the localized category, not the label', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, savedLocationsChipRowHomeAndWork);

      expect(find.text('Saved locations'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      // The seam seeds this address as `Office`. For the home/work categories
      expect(find.text('Office'), findsNothing);
    });

    testWidgets('an empty label falls back to the Other string', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, savedLocationsChipRowOtherLabels);

      expect(find.text('Other'), findsOneWidget);
      // No maxLines, no ellipsis: the long label renders in full and the chip
      expect(
        find.text('Beirut Souks — Parking Level B2, Weygand Street'),
        findsOneWidget,
      );
    });

    testWidgets('a loaded row pushes the map down', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, savedLocationsChipRowHomeAndWork);

      expect(
        tester.getTopLeft(find.byKey(savedLocationsChipRowPreviewMapKey)).dy,
        greaterThan(0),
        reason: 'with saved locations the shelf occupies the top of the '
            'picker; if this is 0 the chips are not being rendered at all',
      );
    });

    testWidgets('an empty account hides the row entirely (AC3)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, savedLocationsChipRowEmpty);

      _expectRowHidden(tester);
    });

    testWidgets('the pre-load window hides the row', (
      WidgetTester tester,
    ) async {
      // The fetch is fired from `initState` and never lands in this fixture, so
      await pumpPreview(tester, savedLocationsChipRowLoading);

      _expectRowHidden(tester);
    });

    // F31 (inverted): a failed fetch used to shrink to nothing, so it was
    // indistinguishable from "this account has no saved locations".
    testWidgets('a failed fetch says so, with a retry', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, savedLocationsChipRowFetchFailed);

      expect(
        find.bySemanticsIdentifier('saved_locations_chips_error'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('saved_locations_chips_retry_cta'),
        findsOneWidget,
      );
    });

    testWidgets('an EMPTY account still shrinks — nothing to say', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, savedLocationsChipRowEmpty);

      _expectRowHidden(tester);
      expect(
        find.bySemanticsIdentifier('saved_locations_chips_error'),
        findsNothing,
      );
    });

    testWidgets('tapping a chip commits that point to the picker cubit', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, savedLocationsChipRowHomeAndWork);
      final LocationPickerCubit cubit = tester
          .element(find.byType(SavedLocationsChipRow))
          .read<LocationPickerCubit>();
      expect(cubit.state.draftSelection, isNull);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      expect(cubit.state.draftSelection?.latitude, 33.8869);
      expect(cubit.state.draftSelection?.longitude, 35.5131);
      // `address ?? label` — the resolved address, not the chip caption.
      expect(cubit.state.draftSelection?.address, 'Sassine Square, Ashrafieh');
    });

    testWidgets('the shelf starts at the trailing edge in Arabic', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        savedLocationsChipRowAtCap,
        locale: const Locale('ar'),
      );

      final Rect shelf = tester.getRect(find.byType(ListView));
      expect(
        tester.getCenter(find.text('المنزل')).dx,
        greaterThan(shelf.center.dx),
        reason: 'the first saved location must sit at the right edge in RTL; a '
            'horizontal ListView that ignored Directionality would park it on '
            'the left and the user would have to scroll the wrong way',
      );
    });

    testWidgets('every chip tap target is clipped below the 48 pt minimum', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, savedLocationsChipRowHomeAndWork);

      // OmdsChip pads its capsule out to a 48x48 tappable box on purpose
      expect(
        tester.getSize(find.widgetWithText(OmdsChip, 'Home')).height,
        40,
        reason: 'measured 40 pt against the 48 pt OmdsChip asks for; if this '
            'is now 48 the SizedBox has been fixed and the note in the preview '
            'library should go',
      );
      expect(
        tester.getSize(find.widgetWithText(OmdsChip, 'Work')).height,
        40,
      );
    });

    testWidgets('the chip shelf does not grow with text scale', (
      WidgetTester tester,
    ) async {
      // `JeebPreview` renders every state a third time at textScaleFactor 2.0
      await pumpPreview(tester, savedLocationsChipRowHomeAndWork);
      final double shelfAtOneX = tester.getSize(find.byType(ListView)).height;
      final double capsuleAtOneX = tester
          .getSize(
            find.descendant(
              of: find.widgetWithText(OmdsChip, 'Home'),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .height;
      final double titleAtOneX =
          tester.getSize(find.text('Saved locations')).height;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: previewCanvas(
            savedLocationsChipRowHomeAndWork,
            const Locale('en'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.text('Saved locations')).height,
        greaterThan(titleAtOneX),
        reason: 'if the heading did not grow, the MediaQuery override never '
            'reached the widget and this test is asserting nothing',
      );
      expect(
        tester.getSize(find.byType(ListView)).height,
        shelfAtOneX,
        reason: 'the shelf is a hardcoded 40 pt: it is the one part of this '
            'row that does not respond to the user text-size setting',
      );

      final double capsuleAtTwoX = tester
          .getSize(
            find.descendant(
              of: find.widgetWithText(OmdsChip, 'Home'),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .height;
      expect(
        capsuleAtTwoX,
        greaterThan(capsuleAtOneX),
        reason: 'the capsule grows with the label while its shelf does not',
      );
      expect(
        capsuleAtTwoX,
        shelfAtOneX,
        reason: 'measured 34 pt at 1x and a shelf-filling 40 pt at 2x with the '
            'test font: the capsule has already run out of shelf, so a font '
            'with a taller line box than the test one clips instead of '
            'growing',
      );
    });

    testWidgets('the shelf is read once and never re-read', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, savedLocationsChipRowHomeAndWork);
      expect(find.text('Home'), findsOneWidget);

      // Same widget position, a different repository: the fetch lives in
      await pumpPreview(tester, savedLocationsChipRowEmpty);

      expect(
        find.text('fixture: empty list'),
        findsOneWidget,
        reason: 'the empty preview did mount — otherwise the assertion below '
            'proves nothing',
      );
      expect(
        find.text('Home'),
        findsOneWidget,
        reason: 'the shelf still shows the previous repository\'s addresses. '
            'The one read happens in initState and the widget exposes no '
            'refresh seam, so a location saved after first build cannot appear '
            'until the picker is rebuilt from scratch — which is what the '
            'unused `onLocationSaved` callback was meant for',
      );
    });
  });
}
