// Render tests for the RequestTierCard previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently.
//
// All five previews are the SAME widget told apart only by `selected` and by
// which tier's copy it carries, so every state pins a string that appears in NO
// other state — the speed line, which is unique per tier and per fixture. A
// suite that pinned the shared chrome would pass on the wrong card.
//
// The last group is not preview hygiene. It is what these previews exposed:
// periwinkle description text that misses AA on the UNSELECTED card only, a
// tier radio that announces itself as a button while supporting no semantics
// action at all, and a leading glyph + radio that stay 20/24 dp while the copy
// beside them doubles.

import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/request_type/presentation/request_tier_card.dart';
import 'package:jeeb_mobile/features/request_type/presentation/selectable_radio_glyph.dart';
import 'package:jeeb_mobile/previews/request_type/request_tier_card_preview.dart';

import '../preview_test_harness.dart';

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the preview. The speed line is the discriminator — it is unique
/// per tier, where "Selected"/the tier icon are not.
const String _standardSpeed = 'Delivered later today at a balanced rate.';
const String _flashSpeed = 'Delivered in less than 1 hour.';
const String _onTheWaySpeed = 'Matched with someone already heading there.';
const String _onTheWaySpeedAr = 'يُطابَق مع شخص متجه إلى هناك بالفعل.';
const String _onTheWayTitleAr = 'على الطريق';
// U+2013 EN DASH between the two Latin numerals — the bidi case the Eco
// preview exists for.
const String _ecoSpeed = 'Delivered within 24–48 hours.';
const String _ecoSpeedAr = 'يُوصَّل خلال 24–48 ساعة.';

/// Fixture copy from the wrap-ceiling preview.
const String _longTitle = 'Scheduled Overnight Freight';
const String _longSpeed =
    'Collected after 8 PM and delivered before the shops open tomorrow morning.';

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
            of: find.byType(RequestTierCard),
            matching: find.byType(Material),
          )
          .first,
    );

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(RequestTierCard))).colorScheme;

/// Pumps a preview into a phone-WIDTH box, the way the canvas renders it.
///
/// The width is the point: the card is measured inside the tier list's page
/// padding, so at 390 dp it is the production 350 dp and its copy wraps where
/// the app wraps it. On the default 800 dp test surface nothing wraps at all.
/// The height is deliberately generous — this card grows instead of clipping
/// (in the app it is a `ListView` child), so a short box would only produce a
/// render-overflow exception that says nothing about the widget.
Future<void> _pumpAtPhoneWidth(
  WidgetTester tester,
  Widget Function() preview, {
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 1400);
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
    'RequestTierCard',
    const <String, Widget Function()>{
      'Unselected · Standard': requestTierCardUnselected,
      'Selected · Flash': requestTierCardSelected,
      'Longest shipping copy · On-the-Way': requestTierCardLongestShippingCopy,
      'Selected · Eco (digit range)': requestTierCardDigitRange,
      'Longest plausible copy · unreleased tier': requestTierCardLongCopy,
    },
    expectedText: const <String, String>{
      'Unselected · Standard': _standardSpeed,
      'Selected · Flash': _flashSpeed,
      'Longest shipping copy · On-the-Way': _onTheWaySpeed,
      'Selected · Eco (digit range)': _ecoSpeed,
      'Longest plausible copy · unreleased tier': _longSpeed,
    },
  );

  group('RequestTierCard preview specifics', () {
    testWidgets('selected paints the navy fill and fills the radio dot', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, requestTierCardSelected);

      final ColorScheme scheme = _scheme(tester);
      expect(_cardMaterial(tester).color, scheme.primary);
      expect(
        tester.widget<SelectableRadioGlyph>(
          find.byType(SelectableRadioGlyph),
        ).selected,
        isTrue,
      );
      // Selected ink is `onPrimary` on BOTH the title and the two description
      // lines — the card inverts wholesale, it does not tint.
      expect(tester.widget<Text>(find.text(_flashSpeed)).style?.color,
          scheme.onPrimary);
      expect(tester.widget<Text>(find.text('Flash')).style?.color,
          scheme.onPrimary);
    });

    testWidgets('unselected paints the white surface and an empty ring', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, requestTierCardUnselected);

      final ColorScheme scheme = _scheme(tester);
      expect(_cardMaterial(tester).color, scheme.surface);
      expect(
        tester.widget<SelectableRadioGlyph>(
          find.byType(SelectableRadioGlyph),
        ).selected,
        isFalse,
      );
      expect(tester.widget<Text>(find.text(_standardSpeed)).style?.color,
          scheme.onSecondaryContainer);
    });

    testWidgets('every state carries the create-flow radio id and its checked '
        'state', (WidgetTester tester) async {
      await _pumpAtPhoneWidth(tester, requestTierCardUnselected);
      // 63_W1_TEST_PLAN §2.2 — the i18n-safe id the Maestro create flow taps.
      final Finder standard =
          find.bySemanticsIdentifier('request_type_standard_radio');
      expect(standard, findsOneWidget);
      expect(
        tester.getSemantics(standard).flagsCollection.isChecked,
        CheckedState.isFalse,
      );

      await _pumpAtPhoneWidth(tester, requestTierCardSelected);
      final Finder flash =
          find.bySemanticsIdentifier('request_type_flash_radio');
      expect(
        tester.getSemantics(flash).flagsCollection.isChecked,
        CheckedState.isTrue,
      );
    });

    testWidgets('the AR reading mirrors: Arabic copy, glyph on the left', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(
        tester,
        requestTierCardLongestShippingCopy,
        locale: const Locale('ar'),
      );

      expect(find.text(_onTheWaySpeedAr), findsOneWidget);
      expect(find.text(_onTheWaySpeed), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(RequestTierCard))),
        TextDirection.rtl,
      );
      // `EdgeInsetsDirectional` + a mirrored `Row`: the radio must land on the
      // LEADING-opposite (left) side and the tier glyph right of its title.
      expect(
        tester.getRect(find.byType(SelectableRadioGlyph)).right,
        lessThan(tester.getRect(find.text(_onTheWaySpeedAr)).left),
      );
      expect(
        tester.getRect(find.byIcon(Icons.handshake_outlined)).left,
        greaterThan(tester.getRect(find.text(_onTheWayTitleAr)).right),
      );
    });

    testWidgets('the Eco digit range survives the RTL run unreordered', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(
        tester,
        requestTierCardDigitRange,
        locale: const Locale('ar'),
      );

      // "24–48", not "48–24": the numerals are one LTR run inside the Arabic
      // sentence, and reversing them would change the quoted window.
      expect(find.text(_ecoSpeedAr), findsOneWidget);
      expect(find.textContaining('24–48'), findsOneWidget);
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
        (requestTierCardUnselected, 370),
        (requestTierCardSelected, 370),
        (requestTierCardDigitRange, 370),
        (requestTierCardLongestShippingCopy, 440),
        (requestTierCardLongCopy, 720),
      ];

      for (final (Widget Function() preview, double box) in declared) {
        await _pumpAtPhoneWidth(tester, preview, textScale: 2.0);
        // + the vertical page inset the preview mounts the card in.
        final double needed =
            tester.getRect(find.byType(RequestTierCard)).height +
                Spacing.small * 2;
        expect(needed, lessThanOrEqualTo(box), reason: 'needs $needed dp');
      }
    });

    testWidgets('a long title wraps against the glyph instead of truncating', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, requestTierCardLongCopy);

      expect(find.text(_longTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      // The `Flexible` title is the only constrained Text here, and it has no
      // `maxLines`/`overflow`, so it grows the card rather than ellipsizing.
      expect(
        tester.getRect(find.byType(RequestTierCard)).height,
        greaterThan(100),
      );
    });
  });

  // The defects the previews exposed, held as assertions so they cannot regress
  // unnoticed — and so that FIXING them fails this file loudly rather than
  // leaving a stale claim behind.
  group('RequestTierCard defects', () {
    /// WCAG 1.4.3 for text below 18 pt / 14 pt bold. The description pair is
    /// `bodySmall` (12 sp), so it is held to this floor.
    const double aaSmallTextFloor = 4.5;

    testWidgets('UNSELECTED description text misses AA on white (3.76:1)', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, requestTierCardUnselected);

      final Color fill = _cardMaterial(tester).color!;
      final Color ink = tester.widget<Text>(find.text(_standardSpeed)).style!
          .color!;
      final double ratio = _contrastRatio(ink, fill);

      expect(fill, const Color(0xFFFFFFFF));
      expect(ink, const Color(0xFF777FC0), reason: 'Figma periwinkle');
      expect(
        ratio,
        lessThan(aaSmallTextFloor),
        reason: 'measured ${ratio.toStringAsFixed(2)}:1 — `onSecondaryContainer`'
            ' (#777FC0) on a white card, at bodySmall (12 sp). Both description '
            'lines of an unselected tier are below AA; the price/speed a '
            'customer compares tiers on is the least legible text on the card.',
      );
      expect(ratio, greaterThan(3.0));
    });

    testWidgets('SELECTED description text is fine — the defect is the '
        'unselected pair only', (WidgetTester tester) async {
      await _pumpAtPhoneWidth(tester, requestTierCardSelected);

      final Color ink =
          tester.widget<Text>(find.text(_flashSpeed)).style!.color!;
      expect(
        _contrastRatio(ink, _cardMaterial(tester).color!),
        greaterThan(aaSmallTextFloor),
        reason: 'white on #0B1351 — so four of the five cards on the screen '
            'are the illegible ones, and the fifth is not',
      );
    });

    testWidgets('announces as a button but exposes NO tap action', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, requestTierCardUnselected);

      final SemanticsData data = tester
          .getSemantics(
            find.bySemanticsIdentifier('request_type_standard_radio'),
          )
          .getSemanticsData();

      // The outer `Semantics` claims button + checkbox semantics, then
      // `ExcludeSemantics` drops the `InkWell` beneath it — and with it the only
      // `SemanticsAction.tap` in the subtree. The node ends up with ZERO
      // actions.
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(
        data.actions,
        0,
        reason: 'a control announced as a checkable button that supports no '
            'action at all: a sighted tap still works (ExcludeSemantics is not '
            'IgnorePointer, so hit testing is untouched), but activation from '
            'the semantics tree has to fall back to the platform synthesising '
            'a touch at the node centre — Flutter never dispatches a tap',
      );
      // The same gap, from the caller's side: nothing can drive this card
      // through the accessibility API.
      expect(
        () => tester.semantics.tap(
          find.semantics.byPredicate(
            (SemanticsNode n) => n.identifier == 'request_type_standard_radio',
          ),
        ),
        throwsStateError,
      );
    });

    testWidgets('the announced label doubles the sentence period', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, requestTierCardUnselected);

      // `requestTypeTierSemanticLabel` is "{title}. {speed}. {value}." but the
      // ARB speed/value strings already end in a full stop, so every tier is
      // announced with ".." mid-sentence. Composition lives in the ARB and in
      // `_TierEntry`, not in this widget — the preview is just where it became
      // visible.
      expect(
        tester
            .getSemantics(
              find.bySemanticsIdentifier('request_type_standard_radio'),
            )
            .label,
        contains('balanced rate.. Mid price'),
      );
    });

    testWidgets('neither the tier glyph nor the radio grows with the text', (
      WidgetTester tester,
    ) async {
      await _pumpAtPhoneWidth(tester, requestTierCardUnselected);
      final double copyAt100 = tester.getRect(find.text(_standardSpeed)).height;

      await _pumpAtPhoneWidth(
        tester,
        requestTierCardUnselected,
        textScale: 2.0,
      );
      final double copyAt200 = tester.getRect(find.text(_standardSpeed)).height;

      expect(copyAt200, greaterThan(copyAt100 * 1.9));
      expect(
        tester.getSize(find.byIcon(Icons.balance_outlined)),
        const Size(Sizes.large, Sizes.large),
        reason: '`Icon(size: Sizes.large)` is a raw dp constant, so at the 200% '
            'accessibility ceiling the tier glyph stays 20 dp beside copy that '
            'has doubled',
      );
      expect(
        tester.getSize(find.byType(SelectableRadioGlyph)),
        const Size(Sizes.xLarge, Sizes.xLarge),
        reason: '`SizedBox.square(Sizes.xLarge)` — the only mark that says '
            'which tier is chosen never scales either',
      );
    });
  });
}
