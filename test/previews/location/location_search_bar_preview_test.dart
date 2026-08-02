// Render tests for the LocationSearchBar previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// Four of the six states draw no dropdown at all, and two of those four are the
// SAME widget inputs read two different ways ("no matches" and "you just picked
// this"). "Did something render" is therefore a weak question here: the expected
// strings pin the fixture each preview was wired to, and the group below pins
// what the canvas can only show — where the dropdown pushes the draft card, that
// selecting a suggestion produces a false empty state, and that the row mirrors
// in Arabic while the coordinate fallback does not.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/location/data/location_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/location_search_bar.dart';
import 'package:jeeb_mobile/previews/location/location_search_bar_preview.dart';

import '../preview_test_harness.dart';

/// Top edge of the draft-card stand-in — how far the bar (plus whatever it is
/// showing) pushed the rest of the picker down.
double _cardTop(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(locationSearchBarPreviewCardKey)).dy;

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Searching · nothing to list`, whose indeterminate
  // `LinearProgressIndicator` never lets `pumpAndSettle` return — see the
  // dedicated group below.
  testPreviewsRender(
    'LocationSearchBar',
    const <String, Widget Function()>{
      'Idle · nothing typed': locationSearchBarIdle,
      'Five matches': locationSearchBarResults,
      'No matches': locationSearchBarNoMatches,
      'Just selected · false empty state': locationSearchBarJustSelected,
      'Long address + coordinates only': locationSearchBarLongAndCoordinateOnly,
    },
    // The bar draws nothing of its own in three of these states, and 'No
    // matches' / 'Just selected' draw the SAME line, so the pinned string is the
    // triple that fed it. Without it a preview wired to the wrong fixture would
    // pass here and mislead in the canvas.
    expectedText: const <String, String>{
      'Idle · nothing typed': 'fixture: nothing typed',
      'Five matches': 'fixture: five matches',
      'No matches': 'fixture: no matches',
      'Just selected · false empty state': 'fixture: just selected downtown',
      'Long address + coordinates only': 'fixture: long + coordinate-only',
    },
  );

  // `isSearching` puts an indeterminate `LinearProgressIndicator` on screen, and
  // `pumpAndSettle` — which `pumpPreview` calls — never returns while one is
  // animating. This preview gets the same three assertions the shared suite
  // makes (builds in EN, builds in AR, renders its OWN state) driven by fixed
  // pumps instead.
  group('LocationSearchBar previews · Searching · nothing to list', () {
    Future<void> pumpSearching(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(previewCanvas(locationSearchBarSearching, locale));
      await tester.pump(); // resolve localizations
      await tester.pump(const Duration(milliseconds: 16)); // one bar frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Searching · nothing to list · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpSearching(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Searching · nothing to list renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpSearching(tester);

      expect(find.text('fixture: searching, nothing yet'), findsOneWidget);
      // A 2 pt progress line is the entire feedback: the dropdown stays shut
      // (`showResults` needs results, or a finished search), so there is no
      // empty-state line and no skeleton row while the request is in flight.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('No matching addresses'), findsNothing);
      expect(find.byIcon(Icons.place_outlined), findsNothing);
    });
  });

  group('LocationSearchBar preview specifics', () {
    testWidgets('an empty query draws nothing under the bar', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationSearchBarIdle);

      expect(find.text('Search for a place or address'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      // Not "No matching addresses": the empty-results line is suppressed until
      // the user has typed something, which is the point of the `hasQuery`
      // guard in `build`.
      expect(find.text('No matching addresses'), findsNothing);
      expect(
        _cardTop(tester),
        tester.getBottomLeft(find.byType(OmdsSearchBar)).dy + Spacing.medium,
        reason: 'with no dropdown the draft card sits one gap under the field; '
            'anything larger means the bar reserved height it is not using',
      );
    });

    testWidgets('results push the draft card down instead of overlaying it', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationSearchBarIdle);
      final double closed = _cardTop(tester);

      await pumpPreview(tester, locationSearchBarResults);

      expect(find.text('Downtown, Beirut'), findsOneWidget);
      expect(find.text('Verdun, Beirut'), findsOneWidget);
      expect(
        _cardTop(tester),
        greaterThan(closed),
        reason: 'the dropdown is a Column child, not an overlay: opening it '
            'moves everything below the bar down the screen. If this ever '
            'equals the closed offset the list has started floating and the '
            'screens under it need re-checking',
      );
    });

    testWidgets('a query that matched nothing says so', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationSearchBarNoMatches);

      expect(find.text('No matching addresses'), findsOneWidget);
      expect(find.byIcon(Icons.place_outlined), findsNothing);
    });

    testWidgets('picking a suggestion leaves a FALSE "no matches" line', (
      WidgetTester tester,
    ) async {
      // The static state the cubit lands in after `selectSearchResult`:
      // non-empty query, empty list, not searching — the same triple as a
      // fruitless search. So the bar tells a user who has just chosen an
      // address that there are no matching addresses.
      await pumpPreview(tester, locationSearchBarJustSelected);

      expect(find.text('Downtown, Beirut'), findsOneWidget); // in the field
      expect(
        find.text('No matching addresses'),
        findsOneWidget,
        reason: 'this is the defect, not the fixture: if the bar learns to '
            'tell "you picked this" from "there was nothing", this line goes '
            'and the preview should go with it',
      );
    });

    testWidgets('tapping a result reproduces that state through the callback', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationSearchBarResults);
      expect(find.text('No matching addresses'), findsNothing);

      await tester.tap(find.text('Hamra Street, Beirut'));
      await tester.pumpAndSettle();

      // The host mirrors `LocationPickerCubit.selectSearchResult` exactly:
      // address into the query, list cleared, `isSearching` false.
      expect(find.text('Hamra Street, Beirut'), findsOneWidget); // the field
      expect(find.text('Downtown, Beirut'), findsNothing); // list is gone
      expect(find.text('No matching addresses'), findsOneWidget);
    });

    testWidgets('a result with no address is offered as raw coordinates', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationSearchBarLongAndCoordinateOnly);

      // `address ?? '$latitude, $longitude'` — a pin the reverse geocoder has
      // not resolved is presented to the user as two numbers to choose between.
      expect(find.text('33.8938, 35.5018'), findsOneWidget);
      // The long one is not truncated in the tree, only painted with an
      // ellipsis, so the full string is what a screen reader gets.
      expect(
        find.text(
          'Beirut Souks — Parking Level B2, Weygand Street, Downtown Beirut',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the result row mirrors in Arabic', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationSearchBarResults, locale: const Locale('ar'));

      expect(find.text('ابحث عن مكان أو عنوان'), findsOneWidget);
      expect(
        tester.getCenter(find.byIcon(Icons.place_outlined).first).dx,
        greaterThan(tester.getCenter(find.text('Downtown, Beirut')).dx),
        reason: 'the pin leads the address, so in RTL it must sit at the right '
            'edge; a Row that ignored Directionality would leave it on the left',
      );
    });

    testWidgets('the coordinate fallback reverses in Arabic', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        locationSearchBarLongAndCoordinateOnly,
        locale: const Locale('ar'),
      );

      // '33.8938, 35.5018' carries no `textDirection`, so it inherits the RTL
      // paragraph direction: the two number runs stay LTR internally but are
      // ORDERED right-to-left, and an Arabic reader sees the longitude first.
      final RenderParagraph paragraph =
          tester.renderObject<RenderParagraph>(find.text('33.8938, 35.5018'));
      final List<TextBox> latitude = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 7),
      );
      final List<TextBox> longitude = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 9, extentOffset: 16),
      );

      expect(latitude, isNotEmpty);
      expect(longitude, isNotEmpty);
      expect(
        latitude.first.left,
        greaterThan(longitude.first.left),
        reason: 'the latitude is painted to the RIGHT of the longitude in AR, '
            'i.e. the pair reads reversed. A `textDirection: TextDirection.ltr` '
            'on the fallback Text would pin the order; if this test starts '
            'failing, that fix has landed',
      );
    });

    testWidgets('five results at 200% text swallow the screen below the bar', (
      WidgetTester tester,
    ) async {
      // The canvas box this preview declares — a phone-width slab, not the
      // 800x600 the other tests get, because the question is whether the
      // dropdown fits on a phone.
      tester.view.physicalSize = const Size(390, 460);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPreview(tester, locationSearchBarResults);
      final double cardAtOneX =
          tester.getSize(find.byKey(locationSearchBarPreviewCardKey)).height;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: previewCanvas(locationSearchBarResults, const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();

      // `_ResultsList` is `shrinkWrap: true` + `NeverScrollableScrollPhysics`,
      // so it takes whatever height its rows want and cannot be scrolled to
      // give any of it back. Everything under the bar pays for that.
      expect(
        tester.getSize(find.byKey(locationSearchBarPreviewCardKey)).height,
        lessThan(cardAtOneX / 3),
        reason: 'measured 128 pt of card at 1x and 28 pt at 2x in a 390x460 '
            'box: at 200% five suggestions leave almost nothing under the bar. '
            'Here the draft card is Expanded so it merely shrinks; on '
            'LocationPickerScreen the same Column holds a fixed-height card '
            'and two button rows with nothing flexible to absorb it',
      );
    });

    testWidgets('the field height is fixed and does not grow with text scale', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, locationSearchBarIdle);
      final double hintAtOneX =
          tester.getSize(find.text('Search for a place or address')).height;
      expect(tester.getSize(find.byType(OmdsSearchBar)).height, 48);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: previewCanvas(locationSearchBarIdle, const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.text('Search for a place or address')).height,
        greaterThan(hintAtOneX),
        reason: 'if the hint did not grow, the MediaQuery override never '
            'reached the widget and this test is asserting nothing',
      );
      expect(
        tester.getSize(find.byType(OmdsSearchBar)).height,
        48,
        reason: 'OmdsSearchBar pins its TextField inside '
            'SizedBox(height: UIConstants.textFieldHeight): the box the user '
            'types in is the one part of this bar that ignores their text-size '
            'setting, so at 200% the text is clipped to a 48 pt box',
      );
    });

    testWidgets('the clear button asks the caller to clear TWICE', (
      WidgetTester tester,
    ) async {
      // Built here rather than driven through a preview because the defect is
      // in the callback count, which the preview host (like the cubit) is
      // idempotent about and therefore hides: `OmdsSearchBar._clearSearch`
      // calls `onChanged('')` AND `onClear()`, and `LocationSearchBar` wires
      // `onClear` to `onChanged('')` as well. On the picker screen that is two
      // `searchAddress('')` calls, two emits and two rebuilds per tap.
      final List<String> changes = <String>[];
      final TextEditingController controller =
          TextEditingController(text: 'beirut');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        previewCanvas(
          () => LocationSearchBar(
            controller: controller,
            hintText: 'Search for a place or address',
            query: 'beirut',
            results: const <LocationPoint>[
              LocationPoint(
                latitude: 33.8938,
                longitude: 35.5018,
                address: 'Downtown, Beirut',
              ),
            ],
            isSearching: false,
            onChanged: changes.add,
            onResultSelected: (LocationPoint _) {},
          ),
          const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(changes, <String>['', '']);
    });
  });
}
