// Render tests for the JeeberFeedCard previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. The shared suite below does the "does it build
// and show ITS OWN state, in both locales" half; the `preview specifics` group
// does the half the canvas is actually for — geometry at real phone widths.
//
// Three of those specifics are RECORDED DEFECTS, not contracts: they assert the
// card as it renders today, with a reason explaining what it should do instead.
// If one starts failing because the layout was fixed, delete the guard — do not
// "fix" the expectation back.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/jeeber_feed_card.dart';
import 'package:jeeb_mobile/previews/jeeber_request_feed/jeeber_feed_card_preview.dart';

import '../preview_test_harness.dart';

/// The Galaxy S22 logical width — the device this project runs its final
/// on-device check on, and the narrowest mainstream Android.
const Size _s22 = Size(360, 900);

/// A 390 pt phone (iPhone 14 / Pixel 7 class), the width the previews declare.
const Size _phone = Size(390, 900);

/// How many pixels a captured layout error overflowed by, or 0 when [error] is
/// not an overflow at all.
///
/// Read out of the message rather than pinned as a constant: the fact under
/// test is "this content does not fit", and an exact pixel count would break on
/// a font-metric change without meaning anything.
int _overflowPixels(Object? error) {
  if (error == null) return 0;
  final RegExpMatch? match =
      RegExp(r'overflowed by ([\d.]+) pixels').firstMatch('$error');
  if (match == null) return 0;
  return double.parse(match.group(1)!).round();
}

/// Pumps a preview into a real phone box instead of the 800x600 default test
/// surface. The size is the whole point: at 800 pt wide this card has room it
/// never has on a phone, which is why the existing widget suite misses the
/// overflows below.
Future<void> _pumpInBox(
  WidgetTester tester,
  Widget Function() preview, {
  Size box = _phone,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = box;
  addTearDown(tester.view.reset);
  if (textScale != 1.0) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  await tester.pumpWidget(previewCanvas(preview, locale));
  await tester.pump();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'JeeberFeedCard',
    const <String, Widget Function()>{
      'Incoming · full metadata': jeeberFeedCardIncoming,
      'Identity + tier omitted': jeeberFeedCardAnonymous,
      'Offer pending': jeeberFeedCardPending,
      'Accepted · advance action': jeeberFeedCardAccepted,
      'Expired · G3 linger': jeeberFeedCardExpired,
      'Longest content · 360 pt device': jeeberFeedCardLongContent,
    },
    // One string per state that ONLY that state renders: the client name for
    // the two identity readings, and the action affordance for the three
    // lifecycle readings — which is the thing that actually differs between
    // screens 24, 25 and 26.
    expectedText: const <String, String>{
      'Incoming · full metadata': 'Sami Fawaz',
      'Identity + tier omitted': 'Customer',
      'Offer pending': 'Pending',
      'Accepted · advance action': 'Heading to drop off',
      'Expired · G3 linger': 'Expired',
      'Longest content · 360 pt device':
          '2 shawarma + cola from Barbar, extra garlic, no pickles, and a '
              'large fries — call me when you arrive at the building entrance, '
              'third floor, ring twice',
    },
  );

  group('JeeberFeedCard preview specifics', () {
    testWidgets('an identity-less request degrades, it does not blank out', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberFeedCardAnonymous);

      // The localized fallback, never an empty line and never the "?" glyph.
      expect(find.text('Customer'), findsOneWidget);
      expect(find.text('?'), findsNothing);
      final OmdsProfileAvatar avatar = tester.widget<OmdsProfileAvatar>(
        find.byKey(const Key('jeeber-feed-card-avatar')),
      );
      expect(avatar.initial, 'C');
      expect(avatar.profilePicUrl, isNull);

      // An unrated client must not read as a badly rated one, and an unknown
      // tier must not be invented — the jeeber prices off both.
      expect(find.byType(OmdsStarRatingDisplay), findsNothing);
      expect(find.byType(OmdsChip), findsNothing);
    });

    testWidgets('the expired card lingers faded and inert (G3)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, jeeberFeedCardExpired);

      // The status replaces the actions; nothing is left to act on.
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Ignore'), findsNothing);
      expect(find.text('Offer'), findsNothing);
      expect(
        find.bySemanticsIdentifier('jeeber_feed_request_expired_req-expired'),
        findsOneWidget,
      );

      // Faded, not vanished: the request never disappears mid-glance.
      final AnimatedOpacity fade = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byKey(const Key('jeeber-feed-card-req-expired')),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(fade.opacity, lessThan(1.0));
    });

    testWidgets('the longest content clips instead of growing the card', (
      WidgetTester tester,
    ) async {
      await _pumpInBox(tester, jeeberFeedCardLongContent, box: _s22);
      tester.takeException(); // the action-row overflow, asserted separately

      // G1 (sprint-009 P0): a TWO-line preview of the customer's own words,
      // ellipsised — the full text lives on the request detail screen.
      final Text summary = tester.widget<Text>(
        find.byKey(const Key('jeeber-feed-card-summary')),
      );
      expect(summary.maxLines, 2);
      expect(summary.overflow, TextOverflow.ellipsis);

      // The name is one ellipsised line, so it cannot shove the timestamp off
      // the trailing edge of the card.
      final Text name = tester.widget<Text>(
        find.byKey(const Key('jeeber-feed-card-client-name')),
      );
      expect(name.maxLines, 1);
      expect(name.overflow, TextOverflow.ellipsis);

      final Rect card = tester.getRect(find.byType(JeeberFeedCard));
      final Rect stamp = tester.getRect(
        find.byKey(const Key('jeeber-feed-card-timestamp')),
      );
      expect(stamp.right, lessThanOrEqualTo(card.right));
      expect(
        tester.getRect(find.byKey(const Key('jeeber-feed-card-client-name'))
        ).right,
        lessThanOrEqualTo(stamp.left),
      );
    });

    // ----------------------------------------------------------------------
    // Recorded defects. See the file header before "fixing" any of these.
    // ----------------------------------------------------------------------

    testWidgets('RECORDED DEFECT: the Ignore/Offer row overflows in Arabic on '
        'a 360 pt device at DEFAULT text size', (WidgetTester tester) async {
      // English is clean at this width, so nothing about this is visible in a
      // single-locale review — which is why the preview matrix renders AR.
      await _pumpInBox(tester, jeeberFeedCardIncoming, box: _s22);
      expect(tester.takeException(), isNull);

      await _pumpInBox(
        tester,
        jeeberFeedCardIncoming,
        box: _s22,
        locale: const Locale('ar'),
      );
      expect(
        _overflowPixels(tester.takeException()),
        greaterThan(0),
        reason: '_IncomingActions is a Row(mainAxisSize: min) that never wraps, '
            'and the Arabic labels are wider than the English ones: on the '
            '236 pt content column of a 360 pt phone it overflows by ~32 pt, '
            'clipping the trailing edge of the "Offer" button a jeeber has to '
            'tap. It should wrap, shrink or ellipsise instead.',
      );
    });

    testWidgets('RECORDED DEFECT: the Ignore/Offer row overflows at the 200% '
        'text ceiling even on a 390 pt phone', (WidgetTester tester) async {
      await _pumpInBox(tester, jeeberFeedCardIncoming, textScale: 2.0);
      expect(
        _overflowPixels(tester.takeException()),
        greaterThan(0),
        reason: 'the footer Wrap moves the action row onto its own run, but the '
            'row itself does not wrap, so at the accessibility ceiling it '
            'overflows by ~115 pt (EN) — the same ceiling the screen goldens '
            'already assert for other surfaces.',
      );
    });

    testWidgets('RECORDED DEFECT: the footer stacks, and the accepted pill '
        'fills the column instead of hugging its label', (
      WidgetTester tester,
    ) async {
      await _pumpInBox(tester, jeeberFeedCardAccepted);
      expect(tester.takeException(), isNull);

      final Rect footer =
          tester.getRect(find.byKey(const Key('jeeber-feed-card-footer')));
      final Rect chip = tester.getRect(find.byType(OmdsChip));
      final Rect pill = tester
          .getRect(find.byKey(const Key('jeeber-feed-action-req-accepted')));

      expect(
        chip.bottom,
        lessThanOrEqualTo(pill.top),
        reason: '_CardFooter is a Wrap(alignment: spaceBetween), which reads as '
            '"tier at the start, action at the end" on ONE row (Figma '
            '56560:1523). It never happens: the tier chip child measures the '
            'full content width, so it takes a run to itself and the action '
            'area is pushed onto a second run below it.',
      );
      expect(chip.width, closeTo(footer.width, 1.0));

      expect(
        pill.width,
        closeTo(footer.width, 1.0),
        reason: 'the IntrinsicWidth in _AcceptedAction is commented as stopping '
            'this pill from rendering gutter-to-gutter, but it only clamps to '
            'the incoming constraint: "Heading to drop off" has an intrinsic '
            'width of ~268 pt, wider than the 266 pt content column of a 390 pt '
            'phone, so the pill fills the column. It hugs only on the 800 pt '
            'surface test/jeeber_feed_card_test.dart measures it on, and only '
            'with the shorter "Order picked" label.',
      );
    });

    testWidgets('AR mirrors the whole card, not just the text', (
      WidgetTester tester,
    ) async {
      await _pumpInBox(tester, jeeberFeedCardIncoming);
      final Rect card = tester.getRect(find.byType(JeeberFeedCard));
      final Rect avatarEn =
          tester.getRect(find.byKey(const Key('jeeber-feed-card-avatar')));

      await _pumpInBox(
        tester,
        jeeberFeedCardIncoming,
        locale: const Locale('ar'),
      );
      tester.takeException(); // the AR action-row overflow, asserted above
      final Rect avatarAr =
          tester.getRect(find.byKey(const Key('jeeber-feed-card-avatar')));

      // Directionality is genuinely clean here — every inset is symmetric or
      // EdgeInsetsDirectional — so the avatar swaps ends exactly.
      expect(avatarEn.left - card.left, closeTo(card.right - avatarAr.right, 1));
      expect(avatarAr.left, greaterThan(card.center.dx));
    });
  });
}
