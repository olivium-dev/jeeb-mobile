// Render tests for the ClientHomeEmptyView previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/home_client/presentation/widgets/client_home_empty_view.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Requests slot · 390': clientHomeEmptyViewRequestsSlot,
  'Compact phone · 320': clientHomeEmptyViewCompactPhone,
  '200% text · 390': clientHomeEmptyViewLargeText,
  '200% text · 320': clientHomeEmptyViewCompactLargeText,
  'CTA not wired': clientHomeEmptyViewUnwiredCta,
};

/// The width and slot height each preview pins into the tree.
/// Not copied from a run: they are the arithmetic the preview library
const Map<String, Size> _pinnedFrames = <String, Size>{
  'Requests slot · 390': Size(390, 547),
  'Compact phone · 320': Size(320, 332),
  '200% text · 390': Size(390, 547),
  '200% text · 320': Size(320, 332),
  'CTA not wired': Size(390, 547),
};

/// The empty view's own laid-out height per state — the thing the slot is
/// being asked to hold. Doubling the text scale nearly doubles it while the
const Map<String, double> _contentHeights = <String, double>{
  'Requests slot · 390': 452,
  'Compact phone · 320': 452,
  '200% text · 390': 720,
  '200% text · 320': 760,
  'CTA not wired': 452,
};

Rect _slot(WidgetTester tester) =>
    tester.getRect(find.byType(SingleChildScrollView));

Rect _cta(WidgetTester tester) => tester.getRect(find.byType(OmdsPrimaryButton));

/// The CTA's own label. Measured through its render object so the height it
/// WANTS can be compared with the height the pill gives it.
RenderBox _ctaLabel(WidgetTester tester) => tester.renderObject<RenderBox>(
      find.descendant(
        of: find.byType(OmdsPrimaryButton),
        matching: find.byType(Text),
      ),
    );

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ClientHomeEmptyView',
    _previews,
    expectedText: const <String, String>{
      'Requests slot · 390': 'Requests slot: 390 x 547',
      'Compact phone · 320': 'Compact phone: 320 x 332',
      '200% text · 390': '200% text: 390 x 547',
      '200% text · 320': '200% text: 320 x 332',
      'CTA not wired': 'CTA not wired: onNewOrder null',
    },
  );

  group('ClientHomeEmptyView preview frames', () {
    // The assertion the caption-based `expectedText` above cannot make: five
    _pinnedFrames.forEach((String state, Size frame) {
      testWidgets('$state pins a ${frame.width}x${frame.height} slot', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, _previews[state]!);

        // The render harness pumps an 800 pt surface: a state that left its
        expect(tester.getSize(find.byType(ClientHomeEmptyView)).width,
            frame.width);
        expect(_slot(tester).size, Size(frame.width, frame.height));
        expect(
          tester.getSize(find.byType(ClientHomeEmptyView)).height,
          _contentHeights[state],
          reason: 'the content height is what the slot has to hold',
        );
      });
    });

    testWidgets('the 200% previews really render at 2x under test', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientHomeEmptyViewRequestsSlot);
      final double normal = tester.getSize(find.text('What do you need?')).height;

      await pumpPreview(tester, clientHomeEmptyViewLargeText);
      final double scaled = tester.getSize(find.text('What do you need?')).height;

      expect(scaled, greaterThan(normal * 1.5));
    });

    testWidgets('the illustration is a fixed 200 pt in every state', (
      WidgetTester tester,
    ) async {
      // `Sizes.twoHundredLarge` is an absolute token: it does not shrink on a
      for (final Widget Function() preview in _previews.values) {
        await pumpPreview(tester, preview);
        expect(tester.getSize(find.byType(Image)), const Size(200, 200));
      }
    });
  });

  group('ClientHomeEmptyView preview specifics', () {
    testWidgets('the production slot keeps the whole CTA above the fold', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientHomeEmptyViewRequestsSlot);

      final Rect slot = _slot(tester);
      final Rect cta = _cta(tester);
      expect(
        cta.bottom,
        lessThan(slot.bottom),
        reason: 'the signed-off geometry is the one state where the user can '
            'see what to do without scrolling',
      );
      expect(slot.bottom - cta.bottom, greaterThan(90));
    });

    // DOCUMENTED DEFECT, not a desired behaviour. The empty state's only
    testWidgets('DEFECT: at 320 pt the CTA is below the fold at 1x text', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientHomeEmptyViewCompactPhone);

      final Rect slot = _slot(tester);
      expect(_cta(tester).top, greaterThan(slot.bottom));

      // The 390 pt slot is not merely taller — it is the difference between
      await pumpPreview(tester, clientHomeEmptyViewRequestsSlot);
      expect(_cta(tester).top, lessThan(_slot(tester).bottom));
    });

    // DOCUMENTED DEFECT. `OmdsPrimaryButton` hard-codes
    testWidgets('DEFECT: the CTA pill stays 48 pt while its label needs more', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, clientHomeEmptyViewRequestsSlot);
      final RenderBox label1x = _ctaLabel(tester);
      expect(_cta(tester).height, 48);
      expect(
        label1x.getMaxIntrinsicHeight(label1x.size.width),
        lessThanOrEqualTo(48),
        reason: 'at default text size the label still fits its pill',
      );

      await pumpPreview(tester, clientHomeEmptyViewLargeText);
      final RenderBox label2x = _ctaLabel(tester);
      expect(
        _cta(tester).height,
        48,
        reason: 'the pill — and with it the 48 pt tap target — is unchanged at '
            'the 200% accessibility ceiling',
      );
      expect(
        label2x.size.height,
        48,
        reason: 'the label is squeezed into the pill it was given…',
      );
      expect(
        label2x.getMaxIntrinsicHeight(label2x.size.width),
        greaterThan(48),
        reason: '…while the height it actually needs is more, so the CTA text '
            'is painted outside the button',
      );
    });

    // DOCUMENTED DEFECT. `_NewOrderButton` passes `onTap: () =>
    testWidgets('DEFECT: an unwired CTA still reads as a live button', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, clientHomeEmptyViewUnwiredCta);

      final OmdsPrimaryButton button = tester.widget<OmdsPrimaryButton>(
        find.byType(OmdsPrimaryButton),
      );
      expect(button.isEnabled, isTrue);
      expect(
        find.bySemanticsIdentifier('_request_empty_state_new_order_button'),
        findsOneWidget,
        reason: 'a screen reader is told there is a button here',
      );

      // The tap is absorbed and nothing happens — no navigation, no error, no
      await tester.tap(find.byType(OmdsPrimaryButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('the wired and unwired CTAs are pixel-identical', (
      WidgetTester tester,
    ) async {
      // Which is the point of the state above: nothing on screen distinguishes
      await pumpPreview(tester, clientHomeEmptyViewRequestsSlot);
      final Rect wired = _cta(tester);

      await pumpPreview(tester, clientHomeEmptyViewUnwiredCta);
      expect(_cta(tester), wired);
    });

    testWidgets('every state renders the same copy, in both locales', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in _previews.values) {
        await pumpPreview(tester, preview);
        expect(find.text('What do you need?'), findsOneWidget);
        expect(
          find.text('No pending requests — broadcast a new one to get offers.'),
          findsOneWidget,
        );
        expect(find.text('Create your first request'), findsOneWidget);

        await pumpPreview(tester, preview, locale: const Locale('ar'));
        expect(find.text('ماذا تحتاج؟'), findsOneWidget);
        expect(
          find.text('لا توجد طلبات معلّقة — أنشئ طلبًا جديدًا لتلقّي العروض.'),
          findsOneWidget,
        );
        expect(find.text('أنشئ أول طلب لك'), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.byType(ClientHomeEmptyView))),
          TextDirection.rtl,
        );
      }
    });
  });
}
