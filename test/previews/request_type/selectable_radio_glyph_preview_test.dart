// Render tests for the SelectableRadioGlyph previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the shared template — see
// `test/previews/preview_test_harness.dart`.
//
// The glyph renders no text, so `expectedText` pins each specimen's caption.
// That is not a formality here: six 24dp circles are the easiest possible case
// for a preview file to render the same state six times and still pass. The
// specifics below therefore also pin, per specimen, that the GLYPH differs —
// dot present or absent, ring colour, surround fill — because a caption is
// preview chrome and a copy-paste slip would leave it correct while every
// sample stayed on `selected: false`.
//
// Those specifics pin each specimen's PREMISE, never the defect it exists to
// show. Deriving the ring colour from the ambient surface instead of from
// `selected` alone — the fix the two `on surface` specimens argue for — must
// not turn this file red; the assertions below are written against the call
// each specimen makes, not against the colour that call produces on the wrong
// fill.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/request_type/presentation/request_tier_card.dart';
import 'package:jeeb_mobile/features/request_type/presentation/selectable_radio_glyph.dart';

import '../preview_test_harness.dart';

Finder _glyph({int index = 0}) => find.byType(SelectableRadioGlyph).at(index);

/// The glyph draws itself as two `Container`s inside a `Stack`: the ring (a
/// bordered circle, no fill) and — only when selected — the dot (a filled
/// circle, no border). Reading their decorations is the only way to tell one
/// specimen from another, since none of them renders text.
List<BoxDecoration> _parts(WidgetTester tester, {int index = 0}) => tester
    .widgetList<Container>(
      find.descendant(
        of: _glyph(index: index),
        matching: find.byType(Container),
      ),
    )
    .map((Container c) => c.decoration! as BoxDecoration)
    .toList();

BoxDecoration _ring(WidgetTester tester, {int index = 0}) => _parts(
  tester,
  index: index,
).singleWhere((BoxDecoration d) => d.border != null);

Color _ringColor(WidgetTester tester, {int index = 0}) =>
    (_ring(tester, index: index).border! as Border).top.color;

/// `null` when this specimen's glyph is unselected — the dot is simply absent
/// from the `Stack`, not painted transparent.
Color? _dotColor(WidgetTester tester, {int index = 0}) {
  final List<BoxDecoration> filled = _parts(
    tester,
    index: index,
  ).where((BoxDecoration d) => d.color != null).toList();
  return filled.isEmpty ? null : filled.single.color;
}

SelectableRadioGlyph _widget(WidgetTester tester, {int index = 0}) =>
    tester.widget<SelectableRadioGlyph>(_glyph(index: index));

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(_glyph())).colorScheme;

/// The fill of the card-shaped surround each specimen draws the glyph on. This
/// is what decides whether the glyph is visible, so it is half of every
/// specimen's premise.
Color? _surroundFill(WidgetTester tester, {int index = 0}) {
  final Container card = tester.widget<Container>(
    find
        .ancestor(
          of: _glyph(index: index),
          matching: find.byType(Container),
        )
        .first,
  );
  return (card.decoration! as BoxDecoration).color;
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'SelectableRadioGlyph',
    const <String, Widget Function()>{
      'Unselected on its card': selectableRadioGlyphUnselected,
      'Selected on its navy card': selectableRadioGlyphSelected,
      'Selected on surface · vanishes': selectableRadioGlyphSelectedOnSurface,
      'Selected on surface · ring override': selectableRadioGlyphRingOverride,
      'Both states, real fills': selectableRadioGlyphBothStates,
      'In a real tier card': selectableRadioGlyphInTierCard,
    },
    expectedText: const <String, String>{
      'Unselected on its card': 'Unselected on its card',
      'Selected on its navy card': 'Selected on its navy card',
      'Selected on surface · vanishes': 'Selected on surface · vanishes',
      'Selected on surface · ring override':
          'Selected on surface · ring override',
      'Both states, real fills': 'Both states, real fills',
      'In a real tier card': 'In a real tier card',
    },
  );

  group('SelectableRadioGlyph preview specifics', () {
    // The captions differ by construction; the glyphs are what could silently
    // be identical. This is the assertion `expectedText` cannot make.
    testWidgets('each specimen shows the selection state its caption names', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, selectableRadioGlyphUnselected);
      expect(_widget(tester).selected, isFalse);
      expect(_dotColor(tester), isNull);

      for (final Widget Function() preview in <Widget Function()>[
        selectableRadioGlyphSelected,
        selectableRadioGlyphSelectedOnSurface,
        selectableRadioGlyphRingOverride,
      ]) {
        await pumpPreview(tester, preview);
        expect(_widget(tester).selected, isTrue);
        expect(_dotColor(tester), isNotNull);
      }

      await pumpPreview(tester, selectableRadioGlyphInTierCard);
      expect(_widget(tester).selected, isFalse);
      expect(_dotColor(tester), isNull);
    });

    // Design geometry: a 24dp square holding a 2dp ring and a 12dp dot, none of
    // them scaled. The specimens are only readable as specimens if that holds.
    testWidgets('the glyph is 24dp with a 2dp ring and a 12dp dot', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, selectableRadioGlyphSelected);

      expect(tester.getSize(_glyph()), const Size(Sizes.xLarge, Sizes.xLarge));
      expect((_ring(tester).border! as Border).top.width, Sizes.threeXSmall);
      expect(_ring(tester).shape, BoxShape.circle);

      final Finder dot = find.descendant(
        of: _glyph(),
        matching: find.byWidgetPredicate(
          (Widget w) =>
              w is Container && (w.decoration as BoxDecoration?)?.color != null,
        ),
      );
      expect(tester.getSize(dot), const Size(Spacing.small, Spacing.small));
    });

    // The class doc's claim — the glyph is drawn "purely from `colorScheme`
    // roles", no literals — and the reason the two `on surface` specimens are
    // about a role pairing rather than about a hardcoded colour.
    testWidgets('the default colours are colorScheme roles, not literals', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, selectableRadioGlyphUnselected);
      expect(_widget(tester).ring, isNull);
      expect(_ringColor(tester), _scheme(tester).primary);

      await pumpPreview(tester, selectableRadioGlyphSelected);
      expect(_widget(tester).ring, isNull);
      expect(_ringColor(tester), _scheme(tester).onPrimary);
      expect(_dotColor(tester), _scheme(tester).onPrimary);
    });

    // Each state on the fill it claims: the baseline pair sits on the two fills
    // production uses, so "selected" and "navy card" are not just words in the
    // caption.
    testWidgets('the baseline specimens sit on their production fills', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, selectableRadioGlyphUnselected);
      expect(_surroundFill(tester), _scheme(tester).surface);

      await pumpPreview(tester, selectableRadioGlyphSelected);
      expect(_surroundFill(tester), _scheme(tester).primary);
    });

    // The premise of the whole argument: the vanishing specimen and its control
    // are the SAME call on the SAME fill, differing by one argument. If they
    // ever drift apart in fill or in `selected`, the comparison the canvas
    // invites is no longer valid and the pair proves nothing.
    testWidgets('the vanishing specimen and its control differ only in ring', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, selectableRadioGlyphSelectedOnSurface);
      final ColorScheme scheme = _scheme(tester);
      expect(_surroundFill(tester), scheme.surface);
      expect(_widget(tester).selected, isTrue);
      expect(_widget(tester).ring, isNull);

      await pumpPreview(tester, selectableRadioGlyphRingOverride);
      expect(_surroundFill(tester), scheme.surface);
      expect(_widget(tester).selected, isTrue);
      expect(_widget(tester).ring, scheme.primary);
      // The override reaches BOTH parts, which is why one argument is enough.
      expect(_ringColor(tester), scheme.primary);
      expect(_dotColor(tester), scheme.primary);
    });

    // A radio is only judgeable next to its sibling; if this specimen lost one
    // glyph — or rendered the same state twice — the canvas would still look
    // plausible.
    testWidgets('the pair specimen shows both states on both fills', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, selectableRadioGlyphBothStates);

      expect(find.byType(SelectableRadioGlyph), findsNWidgets(2));
      final ColorScheme scheme = _scheme(tester);

      expect(_widget(tester).selected, isFalse);
      expect(_dotColor(tester), isNull);
      expect(_surroundFill(tester), scheme.surface);

      expect(_widget(tester, index: 1).selected, isTrue);
      expect(_dotColor(tester, index: 1), isNotNull);
      expect(_surroundFill(tester, index: 1), scheme.primary);
    });

    // The in-situ specimen only carries meaning if the copy beside the glyph is
    // the real localized string — an English placeholder would make the AR
    // rendering a lie about the proportions a real Arabic user sees.
    testWidgets('the tier-card specimen mounts a real, localized card', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, selectableRadioGlyphInTierCard);
      expect(find.byType(RequestTierCard), findsOneWidget);
      expect(find.text('Flash'), findsOneWidget);

      await pumpPreview(
        tester,
        selectableRadioGlyphInTierCard,
        locale: const Locale('ar'),
      );
      expect(find.text('Flash'), findsNothing);
      expect(find.text('فوري'), findsOneWidget);
    });

    // The point of the in-situ specimen: the glyph is built from fixed tokens
    // and opts into no text scaling, so at the 200% accessibility ceiling the
    // copy doubles and the glyph does not move at all.
    testWidgets('the glyph does not grow with text scale, but the copy does', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPreview(tester, selectableRadioGlyphInTierCard);
      final Size glyphAt1x = tester.getSize(_glyph());
      final double titleAt1x = tester.getSize(find.text('Flash')).height;

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(tester, selectableRadioGlyphInTierCard);

      expect(
        tester.getSize(find.text('Flash')).height,
        greaterThan(titleAt1x * 1.5),
      );
      expect(tester.getSize(_glyph()), glyphAt1x);
      expect(glyphAt1x, const Size(Sizes.xLarge, Sizes.xLarge));
    });

    // RTL moves the glyph within its host row (asserted in the
    // ClientLocationOptionCard preview test); the glyph itself is a concentric
    // circle with no directional padding, so it must be identical mirrored.
    // Anything else would mean a stray `EdgeInsets.only` had crept in.
    testWidgets('the glyph itself is unchanged under RTL', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, selectableRadioGlyphSelected);
      final Size ltr = tester.getSize(_glyph());
      final Color ltrRing = _ringColor(tester);

      await pumpPreview(
        tester,
        selectableRadioGlyphSelected,
        locale: const Locale('ar'),
      );
      expect(Directionality.of(tester.element(_glyph())), TextDirection.rtl);
      expect(tester.getSize(_glyph()), ltr);
      expect(_ringColor(tester), ltrRing);
      expect(_dotColor(tester), ltrRing);
    });
  });
}
