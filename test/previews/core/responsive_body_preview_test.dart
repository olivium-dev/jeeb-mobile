// Render tests for the ResponsiveBody previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// ResponsiveBody paints nothing, so "did it render" is a weak question here —
// all six previews would pass a render-only check while showing the same
// layout. The suite therefore measures the content column: the expected strings
// pin WHICH viewport each preview simulates, and the group below pins where
// ResponsiveBody actually put the content at that width. Those measurements are
// the widget's whole contract.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/layout/responsive_scaffold.dart';
import 'package:jeeb_mobile/previews/core/responsive_body_preview.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ResponsiveBody',
    const <String, Widget Function()>{
      'Phone 390 · untouched': responsiveBodyPhone,
      'Tablet 700 · padded': responsiveBodyTabletPortrait,
      '839 · widest line the app renders': responsiveBodyJustUnderWide,
      '840 · snaps back to 600': responsiveBodyAtWideBreakpoint,
      'Desktop 1280 · centred at 600': responsiveBodyDesktop,
      'Intrinsic child · shrink-wraps on wide': responsiveBodyIntrinsicChild,
    },
    // Every state names its own viewport, so a preview wired to the wrong
    // width — or six previews accidentally sharing one — fails here rather
    // than looking fine in the canvas.
    expectedText: const <String, String>{
      'Phone 390 · untouched': 'Phone · 390 pt viewport',
      'Tablet 700 · padded': 'Tablet portrait · 700 pt viewport',
      '839 · widest line the app renders':
          '839 pt · one pixel below the wide breakpoint',
      '840 · snaps back to 600': '840 pt · exactly at the wide breakpoint',
      'Desktop 1280 · centred at 600': 'Desktop · 1280 pt viewport',
      'Intrinsic child · shrink-wraps on wide': 'Intrinsic child · 1280 pt',
    },
  );

  group('ResponsiveBody preview specifics', () {
    Future<Rect> contentRect(
      WidgetTester tester,
      Widget Function() preview,
    ) async {
      await pumpPreview(tester, preview);
      return tester.getRect(find.byKey(responsiveBodyPreviewContentKey));
    }

    testWidgets('compact hands the child through untouched — zero gutter', (
      WidgetTester tester,
    ) async {
      final Rect content = await contentRect(tester, responsiveBodyPhone);

      expect(content.left, 0.0, reason: 'no side gutter on phones at all');
      expect(content.width, _phoneWidth);
      expect(find.text('offered 390 pt'), findsOneWidget);
    });

    testWidgets('medium pads by Spacing.large on both sides', (
      WidgetTester tester,
    ) async {
      final Rect content = await contentRect(
        tester,
        responsiveBodyTabletPortrait,
      );

      expect(content.left, 20.0);
      expect(content.width, 660.0, reason: '700 - 2 x Spacing.large');
      expect(find.text('offered 660 pt'), findsOneWidget);
    });

    testWidgets(
      'the content column is WIDER below the wide breakpoint than above it',
      (WidgetTester tester) async {
        // 839 pt: still the medium branch, so only the 20 pt gutters come off.
        final Rect justUnder = await contentRect(
          tester,
          responsiveBodyJustUnderWide,
        );
        expect(justUnder.width, 799.0);
        expect(
          justUnder.width,
          greaterThan(ResponsiveBody.maxContentWidth),
          reason: 'the "hard ceiling on content width for readability" is not '
              'applied below breakpointWide, so the widest line the app ever '
              'renders comes out of the branch meant to prevent it',
        );

        // 840 pt: one pixel wider, and the column loses 199 pt.
        final Rect atWide = await contentRect(
          tester,
          responsiveBodyAtWideBreakpoint,
        );
        expect(atWide.width, ResponsiveBody.maxContentWidth);
        expect(atWide.left, 120.0, reason: '(840 - 600) / 2');
        expect(atWide.width, lessThan(justUnder.width - 190));
      },
    );

    testWidgets('expanded centres a 600 pt column in a 1280 pt viewport', (
      WidgetTester tester,
    ) async {
      final Rect content = await contentRect(tester, responsiveBodyDesktop);

      expect(content.width, ResponsiveBody.maxContentWidth);
      expect(content.left, 340.0, reason: '(1280 - 600) / 2');
      expect(find.text('offered 600 pt'), findsOneWidget);
    });

    testWidgets('expanded centres VERTICALLY too, unlike every other branch', (
      WidgetTester tester,
    ) async {
      final Rect onPhone = await contentRect(tester, responsiveBodyPhone);
      final Rect onDesktop = await contentRect(tester, responsiveBodyDesktop);

      // Compact returns the child untouched, so the body starts at the top of
      // the Scaffold body: 390 x 108 at (0, 0).
      expect(onPhone.top, 0.0, reason: 'compact starts under the app bar');

      // `Center` has no width or height factor, so it takes the full 600 pt of
      // body height and centres the child inside it: 600 x 84 at (340, 258).
      // The same screen body is top-aligned on a phone and floating in the
      // middle of the window on a tablet.
      expect(
        onDesktop.top,
        greaterThan(200.0),
        reason: 'measured at 258 pt of dead space above the content — the '
            'expanded branch is the only one that moves content vertically',
      );
      expect(
        onDesktop.center.dy,
        moreOrLessEquals(300.0, epsilon: 1.0),
        reason: 'centred in the 600 pt test surface',
      );
    });

    testWidgets(
      'a child that does not ask for infinite width shrink-wraps on wide only',
      (WidgetTester tester) async {
        final Rect stretched = await contentRect(tester, responsiveBodyDesktop);
        final Rect intrinsic = await contentRect(
          tester,
          responsiveBodyIntrinsicChild,
        );

        // Same widget, same viewport, same offered 600 pt — the only
        // difference is whether the child asked for `double.infinity`.
        expect(find.text('offered 600 pt'), findsOneWidget);
        expect(stretched.width, ResponsiveBody.maxContentWidth);
        expect(
          intrinsic.width,
          lessThan(stretched.width),
          reason: 'Center passes LOOSE constraints, so an intrinsically sized '
              'child hugs its longest line (435.8 pt here) instead of filling '
              'the column — while the compact branch forces the same child to '
              'the full width. The dartdoc does not mention the difference.',
        );
        expect(
          intrinsic.center.dx,
          moreOrLessEquals(stretched.center.dx, epsilon: 0.5),
        );
      },
    );

    testWidgets('the 200% rendering still fits the canvas box it declares', (
      WidgetTester tester,
    ) async {
      // `JeebPreview` renders every state a third time at textScaleFactor 2.0,
      // and nothing else in this suite exercises that. ResponsiveBody does not
      // scroll or clip, so a body that outgrows the viewport at 200% simply
      // overflows — this is the check that the declared canvas heights are not
      // lying about what fits.
      final Rect atOneX = await contentRect(tester, responsiveBodyPhone);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: previewCanvas(responsiveBodyPhone, const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();
      final Rect atTwoX = tester.getRect(
        find.byKey(responsiveBodyPreviewContentKey),
      );

      expect(
        atTwoX.height,
        greaterThan(atOneX.height),
        reason: 'if these match, the MediaQuery override never reached the '
            'widget and this test is asserting nothing',
      );
      expect(
        atTwoX.width,
        atOneX.width,
        reason: 'text scale must not move a breakpoint — width is decided by '
            'the viewport alone',
      );
      expect(
        atTwoX.height,
        lessThan(_canvasHeight),
        reason: 'measured 216 pt at 200% against the declared $_canvasHeight '
            'pt canvas box, with the test font, which is wider than the real '
            'one — so the canvas rendering has room too',
      );
      expect(tester.takeException(), isNull);
    });
  });
}

/// Mirror the constants the preview library keeps private.
const double _phoneWidth = 390;
const double _canvasHeight = 300;
