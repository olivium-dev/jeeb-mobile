// Render tests for the DeliveryEtaBadge previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// Two deviations from that template, both on purpose:
//
//   * Inter is loaded. Half of what this widget can get wrong is geometry — how
//     much of the header row the pill eats and what that does to the caption
//     beside it — and widths measured under the square test font are fiction.
//   * Two states cannot be pinned on the pill's own text. `Past due` and
//     `Arriving now` both render "Arriving now" (that IS the contract for a
//     non-positive ETA), and `Narrow phone` renders the same "120 min" as
//     `Ceiling`. Those two are pinned on their caption — a per-state delivery
//     id — and the behaviour that actually distinguishes them is asserted in
//     the specifics group below.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/delivery_status/presentation/widgets/delivery_eta_badge.dart';

import '../../support/load_test_fonts.dart';
import '../preview_test_harness.dart';

/// The caption of the narrow-phone state — the string under pressure there.
const String _narrowCaption = 'Delivery #NARROW-320';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'In transit · 7 min': deliveryEtaBadgeTypical,
  'Arriving now · 1 min': deliveryEtaBadgeArriving,
  'Threshold · 2 min': deliveryEtaBadgeThreshold,
  'Ceiling · 120 min': deliveryEtaBadgeCeiling,
  'Past due · negative ETA': deliveryEtaBadgePastDue,
  'Narrow phone · 120 min': deliveryEtaBadgeNarrowCeiling,
};

/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double lumA = a.computeLuminance();
  final double lumB = b.computeLuminance();
  final double hi = math.max(lumA, lumB);
  final double lo = math.min(lumA, lumB);
  return (hi + 0.05) / (lo + 0.05);
}

/// The pill itself — `DeliveryEtaBadge.rootKey` is on its [Container].
Rect _pill(WidgetTester tester) =>
    tester.getRect(find.byKey(DeliveryEtaBadge.rootKey));

/// The row the pill shares with the caption.
Rect _row(WidgetTester tester) => tester.getRect(find.byType(Row).first);

RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text));

/// How many lines [text] laid out onto, counted from the glyph boxes.
int _lineCount(WidgetTester tester, String text) {
  final List<TextBox> boxes = _paragraph(tester, text).getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  return boxes.map((TextBox b) => b.top.round()).toSet().length;
}

void main() {
  setUpAll(() async {
    loadPreviewArbs();
    // Geometry, not glyphs, is what half of these states are for — the widths
    // are meaningless under the square test font.
    await loadInterTestFont();
  });

  testPreviewsRender(
    'DeliveryEtaBadge',
    _previews,
    expectedText: const <String, String>{
      // Pinned on the pill's OWN output wherever that output is unique to the
      // state: the value is the entire point of the widget, so binding to
      // anything else would pass on a badge showing the wrong number.
      'In transit · 7 min': '7 min',
      'Arriving now · 1 min': 'Arriving now',
      'Threshold · 2 min': '2 min',
      'Ceiling · 120 min': '120 min',
      // These two repeat a pill above — see the header note. Pinned on their
      // captions; their real contracts are asserted below.
      'Past due · negative ETA': 'Delivery #PAST-DUE-9',
      'Narrow phone · 120 min': _narrowCaption,
    },
  );

  group('DeliveryEtaBadge preview specifics', () {
    testWidgets('"arriving" starts at exactly one minute', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryEtaBadgeArriving);
      expect(find.text('Arriving now'), findsOneWidget);
      expect(find.textContaining('1 min'), findsNothing);

      // The neighbouring value must still be a number. If this ever flips, the
      // `minutes <= 1` comparison was widened and every courier gained a
      // minute of grace they did not earn.
      await pumpPreview(tester, deliveryEtaBadgeThreshold);
      expect(find.text('2 min'), findsOneWidget);
      expect(find.text('Arriving now'), findsNothing);
    });

    testWidgets('a non-positive ETA never surfaces as a negative number', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryEtaBadgePastDue);

      // `DeliverySnapshot.etaMinutes` is an unvalidated `int?` and nothing
      // between the gateway stream and this widget clamps it. `minutes <= 1`
      // is the only thing standing between a past-due delivery and a pill
      // reading "-6 min".
      expect(find.text('Arriving now'), findsOneWidget);
      // Scoped to the pill: the caption ("Delivery #PAST-DUE-9") is allowed its
      // hyphens, the ETA value is not allowed any.
      expect(
        find.descendant(
          of: find.byKey(DeliveryEtaBadge.rootKey),
          matching: find.textContaining('-'),
        ),
        findsNothing,
      );
      expect(find.textContaining('-6'), findsNothing);
    });

    testWidgets('label and value are localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        deliveryEtaBadgeCeiling,
        locale: const Locale('ar'),
      );
      expect(find.text('ETA'), findsNothing);
      expect(find.text('الوصول'), findsOneWidget);
      expect(find.text('120 د'), findsOneWidget);

      await pumpPreview(
        tester,
        deliveryEtaBadgeArriving,
        locale: const Locale('ar'),
      );
      expect(find.text('Arriving now'), findsNothing);
      expect(find.text('يصل الآن'), findsOneWidget);
    });

    testWidgets('the pill mirrors in RTL without help', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryEtaBadgeTypical);
      final Rect ltrPill = _pill(tester);
      final Rect ltrRow = _row(tester);
      // English: caption leading, pill hard against the trailing (right) edge.
      expect(ltrPill.right, closeTo(ltrRow.right, 0.5));

      await pumpPreview(
        tester,
        deliveryEtaBadgeTypical,
        locale: const Locale('ar'),
      );
      final Rect rtlPill = _pill(tester);
      final Rect rtlRow = _row(tester);
      // Arabic: the whole row mirrors, so the pill is hard against the LEFT
      // edge. Nothing in the badge arranges this — its padding is
      // `EdgeInsets.symmetric` and its gaps are `SizedBox`es, so there is no
      // directional inset to get wrong. This asserts that stays true.
      expect(rtlPill.left, closeTo(rtlRow.left, 0.5));
      expect(rtlPill.right, lessThan(ltrPill.right));
    });

    testWidgets('the timer icon is the one part that ignores text scale', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryEtaBadgeTypical);
      final Size iconAt100 = tester.getSize(find.byType(Icon));
      final Size pillAt100 = _pill(tester).size;

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(tester, deliveryEtaBadgeTypical);

      // Both `Text`s honour the scaler and the pill grows with them...
      expect(_pill(tester).size.height, greaterThan(pillAt100.height * 1.3));
      expect(_pill(tester).size.width, greaterThan(pillAt100.width * 1.3));

      // ...but `Icon(size: 16)` does not, because `applyTextScaling` defaults
      // to false and nothing in `AppTheme` registers an `iconTheme` to turn it
      // on. At the 200% ceiling a 16pt glyph sits beside a 28pt value.
      // Asserted as the gap it currently is: if the icon ever starts scaling,
      // this fails and the notes on the previews need deleting, which is the
      // point.
      expect(tester.getSize(find.byType(Icon)), iconAt100);
      expect(iconAt100, const Size(16, 16));
    });

    testWidgets('the badge never yields width — the caption wraps instead', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryEtaBadgeNarrowCeiling);
      final double rowWidth = _row(tester).width;
      expect(rowWidth, closeTo(280, 0.5));
      expect(_lineCount(tester, _narrowCaption), lessThanOrEqualTo(2));

      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPreview(tester, deliveryEtaBadgeNarrowCeiling);

      // The pill is the non-flexible child of the row, so it is laid out first
      // against unbounded width and takes what it wants — three quarters of the
      // narrowest phone the app supports.
      expect(_pill(tester).width, greaterThan(rowWidth * 0.7));

      // The caption pays for all of it. It has no `maxLines`/`overflow` either,
      // so it does not ellipsize — it wraps into a stack of fragments and drags
      // the header several times its own height. This is the failure mode to
      // recognise: not a RenderFlex overflow (there is none — the assertion
      // below is deliberate), but a header that stops reading as one.
      expect(_lineCount(tester, _narrowCaption), greaterThanOrEqualTo(4));
      expect(_row(tester).height, greaterThan(_pill(tester).height * 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the pill paints colorScheme.primaryContainer', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryEtaBadgeTypical);
      final BoxDecoration decoration = tester
          .widget<Container>(find.byKey(DeliveryEtaBadge.rootKey))
          .decoration! as BoxDecoration;

      // Binds the colour finding below to this widget: whatever that role
      // resolves to in a scheme is what the ETA pill wears.
      expect(decoration.color, AppTheme.light().colorScheme.primaryContainer);
    });

    test('the same pill is a different colour family in each scheme', () {
      final ColorScheme light = AppTheme.light().colorScheme;
      final ColorScheme dark = AppTheme.dark().colorScheme;

      // Legibility is not the issue at either end — 13.28:1 and 7.23:1, both
      // well clear of the 4.5:1 WCAG AA asks of the 11pt label.
      expect(
        _contrast(light.onPrimaryContainer, light.primaryContainer),
        greaterThan(4.5),
      );
      expect(
        _contrast(dark.onPrimaryContainer, dark.primaryContainer),
        greaterThan(4.5),
      );

      // Identity is. `AppTheme.light()` overrides `primaryContainer` to the
      // brand ORANGE container (#FFDBD1, hue 13°); `AppTheme.dark()` takes the
      // M3 tone off the NAVY seed (#3C4279, hue 234°). So the ETA pill — one of
      // the few coloured fills on the delivery screen — is orange in light and
      // blue in dark, which only the AR RTL dark rendering of the matrix makes
      // obvious.
      final double hueGap = (HSLColor.fromColor(light.primaryContainer).hue -
              HSLColor.fromColor(dark.primaryContainer).hue)
          .abs();
      expect(
        hueGap,
        greaterThan(90),
        reason: 'if these ever converge, the two schemes finally agree on what '
            'the ETA pill looks like — delete this expectation and the colour '
            'note on the previews',
      );
    });
  });
}
