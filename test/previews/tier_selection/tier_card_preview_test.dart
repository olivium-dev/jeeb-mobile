// Render tests for the TierCard previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently.
//
// All five previews are the SAME widget told apart only by `selected`, by
// whether a recommended pill is passed, and by which tier's copy it carries —
// so every state pins a string that appears in NO other state (the tier footer,
// or the SLA line for the one tier that has none). A suite that pinned the
// shared chrome would pass on the wrong card.
//
// The last group is not preview hygiene. It is what these previews exposed: a
// recommended badge that is invisible on the one card it can appear on, a
// card boundary at 1.21:1, three `TextOverflow.ellipsis` declarations that can
// never fire, and meta glyphs that stay 16 dp while their labels double.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/tier_selection/presentation/tier_card.dart';

import '../preview_test_harness.dart';

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the preview. The footer is the discriminator — it is unique per
/// tier, where "Recommended" and the price pattern are not.
const String _standardFooter = 'Most coverage, lower cost';
const String _expressFooter = 'Best balance of speed and reach';
const String _flashFooter = 'Hyper-local, fastest';
const String _slaNone = 'No SLA';
const String _recommended = 'Recommended';

/// The same strings in Arabic — the AR rendering has to be the shipping copy,
/// not English in an RTL box.
const String _flashNameAr = 'سريع';
const String _flashFooterAr = 'أسرع توصيل قريب';
const String _recommendedAr = 'موصى به';

/// Fixture copy from the wrap-ceiling preview.
const String _longName = 'Temperature-controlled overnight freight';
const String _longDescription =
    'Collected after the shops close and delivered before they open the next '
    'morning, with a signed cold-chain log.';
const String _longVehicle = 'Refrigerated van with a two-person crew';

/// WCAG 2.x contrast ratio between two opaque colours.
double _contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// The card's own [Material], i.e. the one carrying the fill under review.
Material _cardMaterial(WidgetTester tester) => tester.widget<Material>(
      find
          .descendant(
            of: find.byType(TierCard),
            matching: find.byType(Material),
          )
          .first,
    );

/// The padded [Container] the card draws its border on. It is the outermost
/// `Container` in the subtree, so it precedes the badge pill in a pre-order
/// walk.
BoxDecoration _cardDecoration(WidgetTester tester) => tester
    .widget<Container>(
      find
          .descendant(
            of: find.byType(TierCard),
            matching: find.byType(Container),
          )
          .first,
    )
    .decoration! as BoxDecoration;

/// The recommended pill's own [Container], found through the text it wraps.
BoxDecoration _badgeDecoration(WidgetTester tester, String label) => tester
    .widget<Container>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Container))
          .first,
    )
    .decoration! as BoxDecoration;

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(TierCard))).colorScheme;

/// Pumps a preview into a phone-WIDTH box, the way the canvas renders it.
///
/// The width is the point: in the app the card is measured inside the tier
/// list's horizontal padding, so at 390 dp it gets its production 350 dp and
/// its copy wraps where the app wraps it. On the default 800 dp test surface
/// nothing wraps at all. The height is deliberately generous — this card grows
/// instead of clipping (it is a `ListView` child), so a short box would only
/// produce a render-overflow exception that says nothing about the widget.
Future<void> _pumpAtPhoneWidth(
  WidgetTester tester,
  Widget Function() preview, {
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 1600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'TierCard',
    const <String, Widget Function()>{
      'Unselected · Standard': tierCardUnselected,
      'Selected · Express': tierCardSelected,
      'Recommended + selected · Flash': tierCardRecommendedSelected,
      'No SLA · On-the-way': tierCardNoSla,
      'Longest plausible copy · unreleased tier': tierCardLongCopy,
    },
    expectedText: const <String, String>{
      'Unselected · Standard': _standardFooter,
      'Selected · Express': _expressFooter,
      'Recommended + selected · Flash': _flashFooter,
      'No SLA · On-the-way': _slaNone,
      'Longest plausible copy · unreleased tier': _longDescription,
    },
  );

  group('TierCard preview specifics', () {
    testWidgets('selected paints the container fill, a 2 dp primary border and '
        'the check', (WidgetTester tester) async {
      await _pumpAtPhoneWidth(tester, tierCardSelected);

      final ColorScheme scheme = _scheme(tester);
      expect(_cardMaterial(tester).color, scheme.primaryContainer);
      final Border border = _cardDecoration(tester).border! as Border;
      expect(border.top.color, scheme.primary);
      expect(border.top.width, 2);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      // The card inverts wholesale: title AND price take `onPrimaryContainer`.
      expect(
        tester.widget<Text>(find.text('Express')).style?.color,
        scheme.onPrimaryContainer,
      );
    });

    testWidgets('unselected paints the low surface, a 1 dp hairline and no '
        'check', (WidgetTester tester) async {
      await _pumpAtPhoneWidth(tester, tierCardUnselected);

      final ColorScheme scheme = _scheme(tester);
      expect(_cardMaterial(tester).color, scheme.surfaceContainerLow);
      final Border border = _cardDecoration(tester).border! as Border;
      expect(border.top.color, scheme.outlineVariant);
      expect(border.top.width, 1);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.text(_recommended), findsNothing);
      // The description is the one string that is NOT `onSurface` — it is the
      // muted role, and only on the unselected card.
      expect(
        tester.widget<Text>(find.text(_standardFooter)).style?.color,
        scheme.onSurfaceVariant,
      );
    });

    testWidgets('every state carries the tier-selection card identifier', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, tierCardUnselected);
      expect(
        find.bySemanticsIdentifier('tier_selection_card_standard'),
        findsOneWidget,
      );

      // `TierSelectionScreen.cardKey` derives the slug from `TierId.name`, so
      // the on-the-way card is the one camelCase id in an otherwise snake_case
      // set. Pinned so a preview cannot quietly "tidy" it out of sync with QA.
      await _pumpAtPhoneWidth(tester, tierCardNoSla);
      expect(
        find.bySemanticsIdentifier('tier_selection_card_onTheWay'),
        findsOneWidget,
      );
    });

    testWidgets('the selected card announces its selected hint; the '
        'unselected one does not', (WidgetTester tester) async {
      await _pumpAtPhoneWidth(tester, tierCardSelected);
      expect(
        tester
            .getSemantics(find.bySemanticsIdentifier(
              'tier_selection_card_express',
            ))
            .hint,
        'Selected',
      );

      await _pumpAtPhoneWidth(tester, tierCardUnselected);
      expect(
        tester
            .getSemantics(find.bySemanticsIdentifier(
              'tier_selection_card_standard',
            ))
            .hint,
        isEmpty,
      );
    });

    testWidgets('the AR reading mirrors: Arabic copy, check on the left', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(
        tester,
        tierCardRecommendedSelected,
        locale: const Locale('ar'),
      );

      expect(find.text(_flashFooterAr), findsOneWidget);
      expect(find.text(_flashFooter), findsNothing);
      expect(find.text(_recommendedAr), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.byType(TierCard))),
        TextDirection.rtl,
      );
      // The header `Row` mirrors: title on the trailing-opposite (right) edge,
      // then the pill, then the check on the far left.
      expect(
        tester.getRect(find.byIcon(Icons.check_circle_rounded)).right,
        lessThan(tester.getRect(find.text(_recommendedAr)).left),
      );
      expect(
        tester.getRect(find.text(_recommendedAr)).right,
        lessThan(tester.getRect(find.text(_flashNameAr)).right),
      );
      // …and so does the meta row: glyph on the right of its label.
      expect(
        tester.getRect(find.byIcon(Icons.schedule_rounded)).left,
        greaterThan(tester.getRect(find.text(_flashFooterAr)).left),
      );
    });

    testWidgets('the LBP price band keeps its symbol placement in Arabic', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(
        tester,
        tierCardNoSla,
        locale: const Locale('ar'),
      );

      // `MoneyFormat` wraps each token in U+2066…U+2069, so the code stays left
      // of its digits inside an RTL paragraph. Without the isolate this reads
      // "30,000.00 LBP" on the wrong side. Spelled as escapes: the raw code
      // points would reorder this source file in a reviewer's editor.
      expect(
        find.textContaining('\u2066LBP 30,000.00\u2069'),
        findsOneWidget,
      );
      expect(find.textContaining('\u2066LBP 55,000.00\u2069'), findsOneWidget);
    });

    testWidgets('every declared canvas box still clears its 200% rendering', (
      WidgetTester tester,
    ) async {
      // The height each preview declares in `@JeebPreview(size:)`. The canvas
      // gives all three renderings of a state the SAME box and the 200% one is
      // the tallest, so this is the number that decides whether a reviewer sees
      // the widget or a stripe of overflow paint. If it fails, raise the box in
      // the preview — do not shrink the state.
      final List<(Widget Function(), double)> declared =
          <(Widget Function(), double)>[
        (tierCardUnselected, 600),
        (tierCardSelected, 600),
        (tierCardRecommendedSelected, 600),
        (tierCardNoSla, 600),
        (tierCardLongCopy, 960),
      ];

      for (final (Widget Function() preview, double box) in declared) {
        await _pumpAtPhoneWidth(tester, preview, textScale: 2.0);
        // + the vertical list inset the preview mounts the card in.
        final double needed =
            tester.getRect(find.byType(TierCard)).height + Spacing.small * 2;
        expect(needed, lessThanOrEqualTo(box), reason: 'needs $needed dp');
      }
    });
  });

  // The defects the previews exposed, held as assertions so they cannot regress
  // unnoticed — and so that FIXING them fails this file loudly rather than
  // leaving a stale claim behind.
  group('TierCard defects', () {
    /// WCAG 1.4.11: a boundary that identifies a UI component needs 3:1.
    const double aaNonTextFloor = 3.0;

    testWidgets('the recommended pill is INVISIBLE on the selected card', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, tierCardRecommendedSelected);

      final ColorScheme scheme = _scheme(tester);
      final Color cardFill = _cardMaterial(tester).color!;
      final Color pillFill = _badgeDecoration(tester, _recommended).color!;

      // `AppTheme` maps BOTH `primaryContainer` and `tertiaryContainer` to the
      // same #FFDBD1 tone pair, so the pill paints its fill onto an identical
      // fill and its `onTertiaryContainer` ink onto text already drawn in
      // `onPrimaryContainer`. Nothing distinguishes the badge from the header.
      expect(cardFill, scheme.primaryContainer);
      expect(pillFill, scheme.tertiaryContainer);
      expect(
        pillFill,
        cardFill,
        reason: 'the endorsement disappears on the one card it can appear on: '
            'Flash is the only tier the catalog flags recommended, and the '
            'customer tapping that recommendation is what turns the card '
            'primaryContainer',
      );
      expect(_contrastRatio(pillFill, cardFill), 1.0);
      expect(
        tester.widget<Text>(find.text(_recommended)).style?.color,
        scheme.onPrimaryContainer,
        reason: 'onTertiaryContainer == onPrimaryContainer, so even the ink '
            'does not separate the pill from the title beside it',
      );
    });

    testWidgets('…and comes back in the dark scheme, so it is a light-palette '
        'collision, not a layout bug', (WidgetTester tester) async {
      // `previewCanvas` carries both real themes and leaves `themeMode` at
      // `system`, so flipping the ambient brightness is what the canvas's
      // "AR RTL dark" rendering does.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.dark),
          child: previewCanvas(tierCardRecommendedSelected, const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();

      final ColorScheme scheme = _scheme(tester);
      expect(scheme.brightness, Brightness.dark);
      expect(scheme.tertiaryContainer, isNot(scheme.primaryContainer));
      expect(
        _badgeDecoration(tester, _recommended).color,
        isNot(_cardMaterial(tester).color),
      );
    });

    testWidgets('an unselected card is a 1.21:1 hairline on the page', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, tierCardUnselected);

      final ColorScheme scheme = _scheme(tester);
      final Color fill = _cardMaterial(tester).color!;
      final Border border = _cardDecoration(tester).border! as Border;
      final double fillRatio = _contrastRatio(fill, scheme.surface);
      final double borderRatio = _contrastRatio(border.top.color, fill);

      expect(fill, const Color(0xFFFAF8FA));
      expect(border.top.color, const Color(0xFFE5E1E5));
      expect(
        borderRatio,
        lessThan(aaNonTextFloor),
        reason: 'measured ${borderRatio.toStringAsFixed(2)}:1 — `outlineVariant`'
            ' at 1 dp is the ONLY thing marking where one tappable tier ends '
            'and the next begins, since the fill is only '
            '${fillRatio.toStringAsFixed(2)}:1 against the white page behind '
            'it. The selected card is fine (2 dp of `primary`); it is the four '
            'a customer has not chosen yet that have no visible edge.',
      );
      expect(fillRatio, lessThan(1.1));
    });

    testWidgets('no `TextOverflow.ellipsis` in this card can ever fire', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, tierCardLongCopy);

      // All three constrained Texts declare `ellipsis` and none declares
      // `maxLines`, so against the unbounded height a `ListView` child is
      // measured with they WRAP. Every string is fully present and every one is
      // more than one line tall.
      for (final String copy in const <String>[_longName, _longVehicle]) {
        final Text text = tester.widget<Text>(find.text(copy));
        expect(text.overflow, TextOverflow.ellipsis);
        expect(text.maxLines, isNull);
        expect(find.text(copy), findsOneWidget);
      }
      final double nameHeight = tester.getRect(find.text(_longName)).height;
      final double lineHeight =
          tester.getRect(find.text(_longVehicle)).height / 2;
      expect(
        nameHeight,
        greaterThan(lineHeight * 1.5),
        reason: 'the title wrapped to a second line under the badge instead of '
            'truncating beside it — the `ellipsis` on it, on the vehicle label '
            'and on the SLA label is dead code, and the card grows without '
            'bound on ops-authored copy',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('neither meta glyph nor the check grows with the text', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, tierCardRecommendedSelected);
      final double copyAt100 = tester.getRect(find.text(_flashFooter)).height;

      await _pumpAtPhoneWidth(
        tester,
        tierCardRecommendedSelected,
        textScale: 2.0,
      );

      expect(
        tester.getRect(find.text(_flashFooter)).height,
        greaterThan(copyAt100 * 1.9),
      );
      expect(
        tester.getSize(find.byIcon(Icons.schedule_rounded)),
        const Size(Sizes.medium, Sizes.medium),
        reason: '`Icon(size: Sizes.medium)` is a raw dp constant, so at the '
            '200% accessibility ceiling the SLA glyph stays 16 dp beside a '
            'label that has doubled',
      );
      expect(
        tester.getSize(find.byIcon(Icons.check_circle_rounded)),
        const Size(Sizes.large, Sizes.large),
        reason: 'the check is the only mark that survives a colour-blind '
            'reading of which tier is chosen, and it never scales either',
      );
    });
  });
}
