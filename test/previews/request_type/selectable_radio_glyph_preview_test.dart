import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/request_type/presentation/request_tier_card.dart';
import 'package:jeeb_mobile/features/request_type/presentation/selectable_radio_glyph.dart';

import '../preview_test_harness.dart';

Finder _glyph({int index = 0}) => find.byType(SelectableRadioGlyph).at(index);

/// The glyph draws itself as two `Container`s inside a `Stack`: the ring (a
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

    testWidgets('the baseline specimens sit on their production fills', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, selectableRadioGlyphUnselected);
      expect(_surroundFill(tester), _scheme(tester).surface);

      await pumpPreview(tester, selectableRadioGlyphSelected);
      expect(_surroundFill(tester), _scheme(tester).primary);
    });

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
      expect(_ringColor(tester), scheme.primary);
      expect(_dotColor(tester), scheme.primary);
    });

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
