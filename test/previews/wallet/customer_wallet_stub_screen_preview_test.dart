// Render tests for the CustomerWalletStubScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// CustomerWalletStubScreen renders the SAME six strings in every state — it has
// no data axis at all — so "did it render" is a weak question here: all six
// previews would pass a render-only check while showing identical content. The
// suite therefore does two extra jobs. The expected strings pin WHICH window
// each preview simulates (the caption the fixture host paints), and the group
// below measures what the screen actually did inside that window. Those
// measurements are the only contract this screen has.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/devtool/catalog/fixtures/customer_wallet_stub_screen_fixtures.dart';
import 'package:jeeb_mobile/features/wallet/presentation/customer_wallet_stub_screen.dart';

import '../preview_test_harness.dart';

/// Mirror the frames the fixture declares, so a preview quietly rewired to a
/// different window fails here instead of looking plausible in the canvas.
const Size _phoneFrame = Size(390, 844);
const Size _compactFrame = Size(320, 568);
const Size _notchedFrame = Size(393, 852);

/// The home indicator the notched windows simulate.
const double _notchedBottomInset = 34;

/// `Spacing.xLarge` — the ListView's own bottom padding, and the only thing
/// between the CTA and the display edge.
const double _listBottomPadding = 24;

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'CustomerWalletStubScreen',
    const <String, Widget Function()>{
      'Phone 390 × 844': customerWalletStubScreenPhone,
      'Compact 320 × 568': customerWalletStubScreenCompact,
      'Notched 393 × 852 · inset 59/34': customerWalletStubScreenNotched,
      'Phone · 200% text': customerWalletStubScreenLargeText,
      'Compact · 200% text': customerWalletStubScreenCompactLargeText,
      'Notched · 200% text': customerWalletStubScreenNotchedLargeText,
    },
    // Every state names its own window. The screen shows the same headline,
    // the same paragraph and the same card in all six, so without this a
    // preview wired to the wrong window — or six previews accidentally sharing
    // one — would pass unnoticed.
    expectedText: const <String, String>{
      'Phone 390 × 844': 'Phone · 390 × 844 · 100% text',
      'Compact 320 × 568': 'Compact · 320 × 568 · 100% text',
      'Notched 393 × 852 · inset 59/34': 'Notched · 393 × 852 · inset 59/34',
      'Phone · 200% text': 'Phone · 390 × 844 · 200% text',
      'Compact · 200% text': 'Compact · 320 × 568 · 200% text',
      'Notched · 200% text': 'Notched · 393 × 852 · inset 59/34 · 200% text',
    },
  );

  group('CustomerWalletStubScreen preview specifics', () {
    Future<Rect> frameRect(
      WidgetTester tester,
      Widget Function() preview, {
      Locale locale = const Locale('en'),
    }) async {
      await pumpPreview(tester, preview, locale: locale);
      return tester.getRect(find.byType(CustomerWalletStubScreen));
    }

    ScrollableState bodyScrollable(WidgetTester tester) =>
        tester.state(find.byType(Scrollable).last);

    testWidgets('each preview simulates its own window, not the 800 × 600 host',
        (WidgetTester tester) async {
      // If the fixture ever stopped pinning the MediaQuery/SizedBox, every
      // state would collapse onto the test surface and the rest of this group
      // would be asserting nothing.
      expect((await frameRect(tester, customerWalletStubScreenPhone)).size,
          _phoneFrame);
      expect((await frameRect(tester, customerWalletStubScreenCompact)).size,
          _compactFrame);
      expect((await frameRect(tester, customerWalletStubScreenNotched)).size,
          _notchedFrame);
      expect((await frameRect(tester, customerWalletStubScreenLargeText)).size,
          _phoneFrame);
      expect(
          (await frameRect(tester, customerWalletStubScreenCompactLargeText))
              .size,
          _compactFrame);
      expect(
          (await frameRect(tester, customerWalletStubScreenNotchedLargeText))
              .size,
          _notchedFrame);
    });

    testWidgets('the 200% windows really are scaled and the rest are not', (
      WidgetTester tester,
    ) async {
      // `CustomerWalletStubScreenWindow.textScale` is nullable on purpose: a
      // window that pinned 1.0 would overwrite the `matrix: true` 200% card and
      // label a 100% rendering "EN 200% text". This pins both halves of that.
      Future<double> scale(Widget Function() preview) async {
        await pumpPreview(tester, preview);
        return MediaQuery.textScalerOf(
          tester.element(find.byType(CustomerWalletStubScreen)),
        ).scale(10);
      }

      expect(await scale(customerWalletStubScreenPhone), 10);
      expect(await scale(customerWalletStubScreenCompact), 10);
      expect(await scale(customerWalletStubScreenNotched), 10);
      expect(await scale(customerWalletStubScreenLargeText), 20);
      expect(await scale(customerWalletStubScreenCompactLargeText), 20);
      expect(await scale(customerWalletStubScreenNotchedLargeText), 20);
    });

    testWidgets('on a 390 × 844 phone the whole screen fits and does not scroll',
        (WidgetTester tester) async {
      // The reference reading, and the reason nothing below was noticed: in the
      // one window everybody reviews, this screen is exactly as simple as it
      // looks.
      final Rect frame = await frameRect(tester, customerWalletStubScreenPhone);

      expect(bodyScrollable(tester).position.maxScrollExtent, 0);

      final Rect cta = tester.getRect(find.byType(OmdsPrimaryButton));
      expect(cta.bottom - frame.top, moreOrLessEquals(644, epsilon: 1));
      expect(
        find.bySemanticsIdentifier('customer_wallet_stub_done'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('customer_wallet_stub'), findsOneWidget);
    });

    testWidgets('below the fold the CTA is not built, and not in semantics', (
      WidgetTester tester,
    ) async {
      // The screen's only action lives inside the ListView rather than pinned
      // to the bottom of the Scaffold. A ListView stops building past the
      // viewport + cache extent, so on the smallest supported phone — and on
      // ANY phone at 200% text — `customer_wallet_stub_done` is missing from
      // the widget tree AND from the semantics tree until the user scrolls.
      // That id is what this screen's dartdoc publishes as the QA target.
      for (final Widget Function() preview in <Widget Function()>[
        customerWalletStubScreenCompact,
        customerWalletStubScreenLargeText,
        customerWalletStubScreenCompactLargeText,
      ]) {
        await pumpPreview(tester, preview);

        expect(bodyScrollable(tester).position.maxScrollExtent, greaterThan(0));
        expect(find.byType(OmdsPrimaryButton), findsNothing);
        expect(
          find.bySemanticsIdentifier('customer_wallet_stub_done'),
          findsNothing,
        );
        // The screen root and the way out are both still there — the user is
        // not trapped, they just cannot see the button the copy points at.
        expect(
          find.bySemanticsIdentifier('customer_wallet_stub'),
          findsOneWidget,
        );
        expect(find.byType(OMDSAppBar), findsOneWidget);
      }
    });

    testWidgets('at 200% the phone has three screenfuls of scroll', (
      WidgetTester tester,
    ) async {
      // Pinned loosely on purpose. The absolute number is inflated by the test
      // font (every glyph is a square of the font size, so English measures
      // about twice as wide as Inter renders it); the ORDER of it is not, and
      // it is what makes the CTA unreachable on arrival.
      await pumpPreview(tester, customerWalletStubScreenLargeText);
      final ScrollPosition atPhone = bodyScrollable(tester).position;
      expect(atPhone.maxScrollExtent, greaterThan(atPhone.viewportDimension));

      await pumpPreview(tester, customerWalletStubScreenCompactLargeText);
      final ScrollPosition atCompact = bodyScrollable(tester).position;
      expect(
        atCompact.maxScrollExtent,
        greaterThan(2 * atCompact.viewportDimension),
      );
    });

    testWidgets('the body runs under the home indicator', (
      WidgetTester tester,
    ) async {
      // `app_router.dart` mounts this screen as a bare top-level GoRoute — no
      // ShellRoute, no SafeArea — and `Scaffold` does not SafeArea its body, so
      // the scroll viewport ends at the physical bottom edge of the display.
      final Rect frame = await frameRect(
        tester,
        customerWalletStubScreenNotchedLargeText,
      );
      expect(
        tester.getRect(find.byType(Scrollable).last).bottom,
        frame.bottom,
        reason: 'the viewport stops short of the display edge only if someone '
            'added a bottom SafeArea — in which case delete the rest of this '
            'test, it is fixed',
      );

      // Scrolled to the end, the CTA comes to rest on the ListView's own 24 pt
      // bottom padding. The home indicator claims 34.
      final ScrollableState scrollable = bodyScrollable(tester);
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();

      final Rect cta = tester.getRect(find.byType(OmdsPrimaryButton));
      expect(
        frame.bottom - cta.bottom,
        moreOrLessEquals(_listBottomPadding, epsilon: 0.5),
      );
      expect(
        frame.bottom - cta.bottom,
        lessThan(_notchedBottomInset),
        reason: 'measured 24 pt of clearance against a 34 pt home indicator: '
            'the last 10 pt of the dismiss button sits under the system '
            'gesture bar. Font-independent — it is 24 < 34.',
      );
    });

    testWidgets('the same is true in Arabic', (WidgetTester tester) async {
      // The bottom padding is `EdgeInsetsDirectional`, so it does not mirror
      // vertically and the defect is locale-independent. Asserted rather than
      // assumed, because "it is only an English problem" is the usual first
      // guess.
      final Rect frame = await frameRect(
        tester,
        customerWalletStubScreenNotchedLargeText,
        locale: const Locale('ar'),
      );
      final ScrollableState scrollable = bodyScrollable(tester);
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(
        frame.bottom - tester.getRect(find.byType(OmdsPrimaryButton)).bottom,
        moreOrLessEquals(_listBottomPadding, epsilon: 0.5),
      );
    });

    // The screen is reached by a stack-REPLACING `goNamed('customer-wallet')`,
    // so `canPop()` is false and both the app-bar back button and the CTA take
    // the `context.go('/')` fallback. An unguarded pop here would leave the
    // Navigator with no pages — the black contentless surface
    // `OMDSAppBar._buildBackButton` documents at length.
    //
    // Each exit gets its OWN test. Pumping a second preview into the same
    // tester reuses the first preview's element, and with it the fixture host's
    // State — the router would still be sitting on the page the previous tap
    // navigated to.
    Future<void> exitVia(WidgetTester tester, Finder target) async {
      await pumpPreview(tester, customerWalletStubScreenPhone);
      expect(find.byType(CustomerWalletStubScreen), findsOneWidget);

      // The 390 × 844 frame is taller than the 800 × 600 test surface, so the
      // target has to be scrolled into the hit-testable area first.
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerWalletStubScreen), findsNothing);
      expect(
        find.text(customerWalletStubScreenShellStandInLabel),
        findsOneWidget,
      );
    }

    testWidgets('the Got it CTA lands on a page, not an empty Navigator', (
      WidgetTester tester,
    ) async {
      await exitVia(
        tester,
        find.bySemanticsIdentifier('customer_wallet_stub_done'),
      );
    });

    testWidgets('the app-bar back button lands on the same page', (
      WidgetTester tester,
    ) async {
      await exitVia(tester, find.byIcon(Icons.arrow_back));
    });

    testWidgets('Arabic is localized and mirrored, not raw English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        customerWalletStubScreenPhone,
        locale: const Locale('ar'),
      );

      expect(find.text('تدفع نقداً'), findsOneWidget);
      expect(find.text('الدفع عند التوصيل'), findsOneWidget);
      expect(find.text('You pay in cash'), findsNothing);
      expect(
        Directionality.of(
          tester.element(find.byType(CustomerWalletStubScreen)),
        ),
        TextDirection.rtl,
      );
    });
  });
}
