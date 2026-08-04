// Render tests for the TrackingNoShowSheet previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/tracking_noshow_sheet.dart';

import '../preview_test_harness.dart';

/// The three CTAs and the sheet container, as Maestro addresses them.
const List<String> _semanticsIds = <String>[
  'tracking_noshow_sheet',
  'tracking_noshow_reassign_cta',
  'tracking_noshow_rebroadcast_cta',
  'tracking_noshow_keep_cta',
];

/// The kit CTA ladder this sheet now draws: `primary` h56, `outline` h50, and
/// `text` with no pill of its own. Was one flat OMDS 48 before the Midnight pass.
const Map<String, double> _kPillHeight = <String, double>{
  'Choose another offer': 56,
  'Send request again': 50,
};

/// The bottom-most CTA — a bare label, so it is measured by its own text box.
const String _kTertiaryCta = 'Keep waiting';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'TrackingNoShowSheet',
    const <String, Widget Function()>{
      'Bare sheet · 390 pt': trackingNoShowSheetDefault,
      'Narrow phone · 320 pt': trackingNoShowSheetNarrowPhone,
      'Gesture-bar inset': trackingNoShowSheetGestureBar,
      'Modal presentation': trackingNoShowSheetInModalRoute,
      'Small phone · modal': trackingNoShowSheetSmallPhone,
    },
    expectedText: const <String, String>{
      // The title, i.e. the question the sheet exists to answer.
      'Bare sheet · 390 pt': 'Jeeber didn’t show up?',
      // The longest CTA label: the first thing 320 pt squeezes.
      'Narrow phone · 320 pt': 'Send request again',
      // The bottom-most CTA: the row the home indicator would otherwise eat.
      'Gesture-bar inset': 'Keep waiting',
      // The body copy — the tallest block, and the one furthest from the
      'Modal presentation': 'You can pick another offer for this request, or '
          'send it out again to nearby Jeebers.',
      // The primary recovery path, still reachable on the smallest phone.
      'Small phone · modal': 'Choose another offer',
    },
  );

  group('TrackingNoShowSheet preview specifics', () {
    testWidgets('bare previews are pinned to a real phone width', (
      WidgetTester tester,
    ) async {
      // The render harness pumps an 800 px viewport and ignores
      await pumpPreview(tester, trackingNoShowSheetDefault);
      expect(tester.getSize(find.byType(TrackingNoShowSheet)).width, 390);

      await pumpPreview(tester, trackingNoShowSheetNarrowPhone);
      expect(tester.getSize(find.byType(TrackingNoShowSheet)).width, 320);
    });

    testWidgets('the CTA pill never grows, whatever the label does', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingNoShowSheetNarrowPhone);

      // JeebCtaButton fixes each variant's height and centres the label in it.
      _kPillHeight.forEach((String label, double expected) {
        final Finder pill = find.ancestor(
          of: find.text(label),
          matching: find.byType(JeebCtaButton),
        );
        expect(pill, findsOneWidget, reason: 'no pill found for "$label"');
        expect(
          tester.getSize(pill).height,
          expected,
          reason: '"$label" must not be allowed to change the pill height',
        );
        expect(
          tester.getSize(find.text(label)).height,
          lessThanOrEqualTo(expected),
          reason: 'a label taller than its pill is a clipped label',
        );
      });
    });

    testWidgets('the CTA ladder descends and spends no accent', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingNoShowSheetDefault);

      final List<JeebCtaVariant> variants = tester
          .widgetList<JeebCtaButton>(find.byType(JeebCtaButton))
          .map((JeebCtaButton b) => b.variant)
          .toList();
      // A recovery sheet is never the screen's budgeted orange act.
      expect(variants, <JeebCtaVariant>[
        JeebCtaVariant.primary,
        JeebCtaVariant.outline,
        JeebCtaVariant.text,
      ]);
    });

    testWidgets('the gesture-bar state really reserves the bottom inset', (
      WidgetTester tester,
    ) async {
      Future<double> paddingBelowLastCta(Widget Function() preview) async {
        await pumpPreview(tester, preview);
        final Rect sheet = tester.getRect(find.byType(TrackingNoShowSheet));
        final Rect pill = tester.getRect(
          find.ancestor(
            of: find.text(_kTertiaryCta),
            matching: find.byType(JeebCtaButton),
          ),
        );
        return sheet.bottom - pill.bottom;
      }

      // jeebPreviewHost wraps every preview in its own SafeArea, which zeroes
      final double bare = await paddingBelowLastCta(trackingNoShowSheetDefault);
      final double withBar =
          await paddingBelowLastCta(trackingNoShowSheetGestureBar);

      expect(
        withBar - bare,
        34,
        reason: 'the tertiary "Keep waiting" CTA would sit under the home '
            'indicator without the sheet\'s SafeArea',
      );
    });

    testWidgets('modal preview goes through the production entry point', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingNoShowSheetInModalRoute);

      // Pushed by TrackingNoShowSheet.show, not hand-placed.
      expect(find.byType(BottomSheet), findsOneWidget);
      // …and anchored to the bottom of its host, under the scrim.
      final Rect sheet = tester.getRect(find.byType(TrackingNoShowSheet));
      final Rect host = tester.getRect(find.byType(Navigator).last);
      expect(sheet.bottom, host.bottom);
    });

    testWidgets('the bare previews carry no bottom-sheet frame', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingNoShowSheetDefault);

      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('the small-phone preview really is a 320 × 568 phone', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingNoShowSheetSmallPhone);

      expect(tester.getSize(find.byType(Navigator).last), const Size(320, 568));
      final Rect sheet = tester.getRect(find.byType(TrackingNoShowSheet));
      final Rect phone = tester.getRect(find.byType(Navigator).last);
      expect(sheet.bottom, phone.bottom);
      // The height ceiling this state exists to show: at DEFAULT text the sheet
      expect(sheet.height, greaterThan(phone.height / 2));
    });

    testWidgets('every CTA the flow depends on keeps its semantics node', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, trackingNoShowSheetInModalRoute);

      for (final String id in _semanticsIds) {
        expect(
          find.bySemanticsIdentifier(id),
          findsOneWidget,
          reason: 'expected an independent semantics node for $id — Maestro '
              'asserts on these identifiers, not on the visible copy',
        );
      }
      handle.dispose();
    });

    testWidgets('show() pops the sheet before it hands over the flow', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, trackingNoShowSheetInModalRoute);
      expect(find.byType(BottomSheet), findsOneWidget);

      await tester.tap(find.text('Choose another offer'));
      await tester.pumpAndSettle();

      // If the sheet survived the tap it would stack under the route the
      expect(find.byType(BottomSheet), findsNothing);
    });
  });
}
