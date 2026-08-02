// Render tests for the InactivityWarningBanner previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. See `test/previews/preview_test_harness.dart`.
//
// InactivityWarningBanner has no data state — its three strings are fixed — so
// its previews differ only in the CONTEXT they place it in. That makes the
// `expectedText` pins load-bearing: without a string only one preview can
// produce, a suite over five renderings of the same card would pass no matter
// which one it actually built. Each composed state is pinned by its own
// greeting name, or by its own accepted-order fixture, which no other renders.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/inactivity_warning_banner.dart';

import '../preview_test_harness.dart';

const String _bannerTitle = 'Still there?';
const String _bannerBody =
    "You'll be taken offline in about 30 minutes if you stay idle. "
    'Tap below to keep receiving requests.';
const String _bannerCta = "I'm still here";
const String _longCounterpart = 'Abdulrahman Al-Muhandis Al-Trabulsi';

const List<Widget Function()> _allPreviews = <Widget Function()>[
  inactivityWarningBannerAlone,
  inactivityWarningBannerSmallPhone,
  inactivityWarningBannerOnlineDashboard,
  inactivityWarningBannerUnderActiveDeliveries,
  inactivityWarningBannerShortViewport,
];

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'InactivityWarningBanner',
    const <String, Widget Function()>{
      'Banner alone': inactivityWarningBannerAlone,
      'Small phone 320dp': inactivityWarningBannerSmallPhone,
      'Online dashboard': inactivityWarningBannerOnlineDashboard,
      'Under active deliveries': inactivityWarningBannerUnderActiveDeliveries,
      'Short viewport 260dp': inactivityWarningBannerShortViewport,
    },
    expectedText: const <String, String>{
      // The bare card has no content but its own copy.
      'Banner alone': _bannerBody,
      // Every composed state is pinned by a string ONLY that state renders:
      // its own greeting name, or its own accepted-order fixture.
      'Small phone 320dp': 'Hello, Nadia',
      'Online dashboard': 'Hello, Sami',
      'Under active deliveries': 'Kamal Hajj',
      'Short viewport 260dp': 'Hello, Layla',
    },
  );

  group('InactivityWarningBanner preview specifics', () {
    testWidgets('every preview really raises the banner and its CTA', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in _allPreviews) {
        await pumpPreview(tester, preview);

        expect(find.byKey(InactivityWarningBanner.rootKey), findsOneWidget);
        expect(find.byKey(InactivityWarningBanner.ctaKey), findsOneWidget);
        expect(find.text(_bannerTitle), findsOneWidget);
      }
    });

    testWidgets('the CTA is hit-testable in the composed dashboard', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, inactivityWarningBannerOnlineDashboard);

      await tester.tap(find.byKey(InactivityWarningBanner.ctaKey));
      await tester.pumpAndSettle();

      // The preview's `onExtend` is inert, so the banner stays up — what is
      // asserted here is that the CTA can be reached at all, i.e. nothing
      // stacked above it in the column intercepts the tap.
      expect(tester.takeException(), isNull);
      expect(find.byKey(InactivityWarningBanner.rootKey), findsOneWidget);
    });

    testWidgets('the banner is localized, never hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        inactivityWarningBannerAlone,
        locale: const Locale('ar'),
      );

      expect(find.text(_bannerTitle), findsNothing);
      expect(find.text(_bannerCta), findsNothing);
      expect(find.text('هل ما زلت موجودًا؟'), findsOneWidget);
      expect(find.text('ما زلت هنا'), findsOneWidget);
    });

    testWidgets('the CTA spans the full card width, so centerEnd is inert', (
      WidgetTester tester,
    ) async {
      Future<void> expectFullWidthCta(Locale locale) async {
        await pumpPreview(tester, inactivityWarningBannerAlone, locale: locale);
        final Rect card = tester.getRect(
          find.byKey(InactivityWarningBanner.rootKey),
        );
        final Rect cta = tester.getRect(
          find.byKey(InactivityWarningBanner.ctaKey),
        );

        // `_BannerCta` wraps the button in
        // `Align(alignment: AlignmentDirectional.centerEnd)`, which reads as
        // "pin the pill to the trailing edge". It does nothing:
        // `OmdsPrimaryButton.width` defaults to full width, so the pill fills
        // the card's content box and sits dead centre in BOTH directions.
        // Recorded here so the intent/behaviour gap is not rediscovered — if
        // the button ever becomes intrinsically sized, this test fails and the
        // real mirroring assertion (trailing in EN, leading in AR) replaces it.
        expect(cta.center.dx, closeTo(card.center.dx, 0.5));
        // Everything the pill does not occupy is the card's own 16 dp margin,
        // 16 dp padding and 1 dp border on each side.
        expect(cta.width, closeTo(card.width - 2 * 33, 1.0));
      }

      await expectFullWidthCta(const Locale('en'));
      await expectFullWidthCta(const Locale('ar'));
    });

    testWidgets('active-delivery work is disclosed ABOVE the warning', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, inactivityWarningBannerUnderActiveDeliveries);

      final double workTop = tester.getTopLeft(find.text('Kamal Hajj')).dy;
      final double bannerTop = tester
          .getTopLeft(find.byKey(InactivityWarningBanner.rootKey))
          .dy;
      expect(workTop, lessThan(bannerTop));

      // The over-long second name degrades by ellipsis, not by pushing the
      // "Open chat" button off the row.
      expect(
        tester.widget<Text>(find.text(_longCounterpart)).overflow,
        TextOverflow.ellipsis,
      );
    });

    testWidgets('in a 260dp slot the CTA is below the fold, not clipped', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, inactivityWarningBannerShortViewport);

      final Rect slot = tester.getRect(find.byType(SingleChildScrollView));
      final Rect cta = tester.getRect(
        find.byKey(InactivityWarningBanner.ctaKey),
      );

      // Correct degradation: the column scrolls, so nothing throws and the
      // card is laid out in full. Worth pinning that the CTA lands entirely
      // OUTSIDE the visible slot at ordinary text scale — a Jeeber has to
      // scroll a screen that gives no hint there is more below it.
      expect(tester.takeException(), isNull);
      expect(slot.height, closeTo(260, 0.5));
      expect(cta.top, greaterThan(slot.bottom));
    });

    testWidgets('at 200% text the card grows but its CTA pill cannot', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      // The 200% rendering is one third of the preview matrix, and nothing
      // else in CI asserts it for this widget.
      await pumpPreview(tester, inactivityWarningBannerAlone);
      expect(tester.takeException(), isNull);

      // Title and body wrap and push the card taller — the good case.
      final Rect card = tester.getRect(
        find.byKey(InactivityWarningBanner.rootKey),
      );
      expect(card.height, greaterThan(300));

      // The CTA cannot: `OmdsPrimaryButton` pins its height to
      // `Sizes.fourXLarge` (48 dp) whatever the text scale, so the label is
      // clamped rather than wrapped and its second line is painted nowhere.
      // A clamped paragraph raises no overflow error, which is exactly why
      // this needs an explicit assertion instead of `takeException`.
      final RenderBox label = tester.renderObject<RenderBox>(
        find.text(_bannerCta),
      );
      expect(
        label.getMaxIntrinsicHeight(label.size.width),
        greaterThan(label.size.height),
        reason: 'CTA label is being clipped by the fixed-height pill at 200% '
            'text. If OmdsPrimaryButton learns to grow with text scale, delete '
            'this expectation.',
      );
    });
  });
}
