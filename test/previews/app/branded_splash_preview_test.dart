// Render tests for the BrandedSplash previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// BrandedSplash renders the SAME two things — one wordmark, one tagline — in
// every state, so "did it render" is a weak question here: all five previews
// would pass a render-only check while showing identical layouts. The suite
// therefore does two extra jobs. The expected strings pin WHICH window each
// preview simulates (the caption `_DeviceFrame` paints), and the group below
// measures where the splash actually put the wordmark and the tagline inside
// that window. Those measurements are the only contract this widget has.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/app/branded_splash.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';

import '../preview_test_harness.dart';

/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double lumA = a.computeLuminance();
  final double lumB = b.computeLuminance();
  final double hi = math.max(lumA, lumB);
  final double lo = math.min(lumA, lumB);
  return (hi + 0.05) / (lo + 0.05);
}

/// Mirror the frames the preview library keeps private, so a preview silently
/// rewired to a different device fails here.
const Size _figmaFrame = Size(440, 956);
const Size _compactFrame = Size(360, 640);
const Size _notchedFrame = Size(393, 852);
const Size _landscapeFrame = Size(852, 393);
const Size _tabletFrame = Size(834, 1194);

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'BrandedSplash',
    const <String, Widget Function()>{
      'Figma frame 440 × 956': brandedSplashFigmaFrame,
      'Compact 360 × 640': brandedSplashCompactPhone,
      'Notched 393 × 852 · inset 59/34': brandedSplashNotchedPhone,
      'Landscape 852 × 393': brandedSplashLandscape,
      'Tablet 834 × 1194': brandedSplashTablet,
    },
    // Every state names its own window. The widget itself shows the same two
    // elements in all five, so without this a preview wired to the wrong frame
    // — or five previews accidentally sharing one — would pass unnoticed.
    expectedText: const <String, String>{
      'Figma frame 440 × 956': 'Figma frame · 440 × 956 · no insets',
      'Compact 360 × 640': 'Compact phone · 360 × 640 · no insets',
      'Notched 393 × 852 · inset 59/34':
          'Notched phone · 393 × 852 · inset 59/34',
      'Landscape 852 × 393': 'Landscape · 852 × 393 · inset 59/59/21',
      'Tablet 834 × 1194': 'Tablet portrait · 834 × 1194 · no insets',
    },
  );

  group('BrandedSplash preview specifics', () {
    Future<Rect> frameRect(
      WidgetTester tester,
      Widget Function() preview,
    ) async {
      await pumpPreview(tester, preview);
      return tester.getRect(find.byType(BrandedSplash));
    }

    testWidgets('each preview simulates its own window, not the 800 × 600 host',
        (WidgetTester tester) async {
      // If `_DeviceFrame` ever stopped pinning the MediaQuery/SizedBox, every
      // state would collapse onto the test surface and the rest of this group
      // would be asserting nothing.
      expect((await frameRect(tester, brandedSplashFigmaFrame)).size,
          _figmaFrame);
      expect((await frameRect(tester, brandedSplashCompactPhone)).size,
          _compactFrame);
      expect((await frameRect(tester, brandedSplashNotchedPhone)).size,
          _notchedFrame);
      expect((await frameRect(tester, brandedSplashLandscape)).size,
          _landscapeFrame);
      expect((await frameRect(tester, brandedSplashTablet)).size, _tabletFrame);
    });

    testWidgets('the wordmark is a fixed 200 pt at every frame width', (
      WidgetTester tester,
    ) async {
      Future<Size> logo(Widget Function() preview) async {
        await pumpPreview(tester, preview);
        return tester.getSize(find.byType(SvgPicture));
      }

      final Size onCompact = await logo(brandedSplashCompactPhone);
      final Size onFigma = await logo(brandedSplashFigmaFrame);
      final Size onTablet = await logo(brandedSplashTablet);

      // The SVG really is drawn, not a zero-height placeholder: height comes
      // from the asset's intrinsic 182 : 73.2418 viewBox.
      expect(
        onFigma.height,
        moreOrLessEquals(
          Sizes.twoHundredLarge * 73.2418 / 182,
          epsilon: 0.5,
        ),
        reason: 'a 0 pt height would mean the asset never decoded and every '
            'geometry assertion below is measuring a placeholder',
      );

      // `Sizes.twoHundredLarge` is an absolute token, not a fraction of the
      // frame, so the brand mark's share of the screen swings by a factor of
      // 2.3 across the device range the app supports.
      expect(onCompact.width, Sizes.twoHundredLarge);
      expect(onFigma.width, Sizes.twoHundredLarge);
      expect(onTablet.width, Sizes.twoHundredLarge);

      expect(
        onFigma.width / _figmaFrame.width,
        moreOrLessEquals(0.455, epsilon: 0.005),
        reason: 'the proportion the _SplashLogo dartdoc describes, true only '
            'at the 440 pt Figma frame',
      );
      expect(
        onCompact.width / _compactFrame.width,
        moreOrLessEquals(0.556, epsilon: 0.005),
        reason: '55.6 % of a 360 pt phone against the ≈41 % Figma proportion '
            'the dartdoc cites',
      );
      expect(
        onTablet.width / _tabletFrame.width,
        moreOrLessEquals(0.240, epsilon: 0.005),
        reason: 'and 24.0 % of an 834 pt tablet — a little over half the '
            'specified proportion',
      );
    });

    testWidgets('the 48 pt tagline margin stacks on top of the home indicator',
        (WidgetTester tester) async {
      Future<double> bottomGap(Widget Function() preview) async {
        final Rect frame = await frameRect(tester, preview);
        final Rect tagline = tester.getRect(find.text('Delivery App'));
        return frame.bottom - tagline.bottom;
      }

      // No system chrome: the designed margin, exactly.
      expect(
        await bottomGap(brandedSplashFigmaFrame),
        moreOrLessEquals(Spacing.fourXLarge, epsilon: 0.5),
      );

      // `SafeArea` measures the margin from the top of the home indicator, so
      // the gap to the physical bottom edge is 34 + 48. The same composition is
      // 48 pt off the edge on one device and 82 pt off it on another.
      expect(
        await bottomGap(brandedSplashNotchedPhone),
        moreOrLessEquals(Spacing.fourXLarge + 34, epsilon: 0.5),
      );
    });

    testWidgets('the wordmark sits above true centre, and the notch moves it', (
      WidgetTester tester,
    ) async {
      // `_SplashBody`'s dartdoc claims the wordmark is "optically centered
      // (slightly above true centre via asymmetric Spacer weights)". The 10 : 9
      // weights are applied to the SAFE box, not to the frame, so the amount of
      // "slightly" depends on the device's insets.
      Future<double> aboveCentre(Widget Function() preview) async {
        final Rect frame = await frameRect(tester, preview);
        final Rect logo = tester.getRect(find.byType(SvgPicture));
        return frame.center.dy - logo.center.dy;
      }

      final double onFigma = await aboveCentre(brandedSplashFigmaFrame);
      final double onNotched = await aboveCentre(brandedSplashNotchedPhone);

      // The documented behaviour: above true centre on both.
      expect(onFigma, greaterThan(0));
      expect(onNotched, greaterThan(0));

      // But by half as much. Measured 14.9 pt of lift on the 440 x 956 Figma
      // frame against 7.5 pt on a 393 x 852 notched phone: the lift is a
      // by-product of the frame's spare height and of how the insets split,
      // not a fixed optical offset. A device whose bottom inset exceeded its
      // top one would push the wordmark BELOW true centre.
      expect(
        onFigma - onNotched,
        greaterThan(5),
        reason: 'measured 14.85 - 7.54 = 7.3 pt of drift between two ordinary '
            'phones — pinned so a change to the 10 : 9 Spacer weights or to '
            'the SafeArea shows up here',
      );
    });

    testWidgets('landscape is the state with the least vertical slack', (
      WidgetTester tester,
    ) async {
      // `_SplashBody` is a non-scrolling Column: the wordmark, the tagline and
      // the 48 pt SizedBox are fixed, and only the two Spacers can give. This
      // pins how much give is left in the shortest frame — it is what the 200 %
      // text rendering has to spend before the Column hard-overflows.
      final Rect frame = await frameRect(tester, brandedSplashLandscape);
      final Rect logo = tester.getRect(find.byType(SvgPicture));
      final Rect tagline = tester.getRect(find.text('Delivery App'));

      final double safeHeight = frame.height - 21; // home indicator
      final double fixed = logo.height + tagline.height + Spacing.fourXLarge;

      // Measured: 372 pt safe height against 152.5 pt of fixed children
      // (80.5 wordmark + 24 tagline + 48 margin), so 219.5 pt of Spacer give.
      expect(
        safeHeight - fixed,
        greaterThan(150),
        reason: 'measured 219.5 pt of give in the shortest frame; the 200 % '
            'rendering spends 24 pt of it (see the next test), so the Column '
            'has room — this is the check that stays true if the fixed '
            'children ever grow',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the shortest frame survives the 200 % text rendering', (
      WidgetTester tester,
    ) async {
      // `JeebPreview` renders every state a third time at textScaleFactor 2.0
      // and nothing else in this suite exercises it. `_SplashBody` neither
      // scrolls nor clips, so a tagline that outgrows the remaining slack would
      // simply be a RenderFlex overflow — on the splash, the very first frame
      // the user sees.
      await pumpPreview(tester, brandedSplashLandscape);
      final Rect atOneX = tester.getRect(find.text('Delivery App'));

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: previewCanvas(brandedSplashLandscape, const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();
      final Rect atTwoX = tester.getRect(find.text('Delivery App'));

      // Measured: the tagline goes 24 pt -> 48 pt, i.e. the fixed children grow
      // to 176.5 pt inside a 372 pt safe box. The splash is one of the few
      // screens with slack to spare at the accessibility ceiling, and this
      // records by how much.
      expect(
        atTwoX.height,
        greaterThan(atOneX.height),
        reason: 'if these match, the MediaQuery override never reached the '
            'widget and this test is asserting nothing',
      );
      expect(
        atTwoX.height,
        moreOrLessEquals(48, epsilon: 1),
        reason: 'still one line — measured 385.8 pt wide against the 734 pt of '
            'safe width this frame offers',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the tagline has no side gutter — it wraps against the glass', (
      WidgetTester tester,
    ) async {
      // `_SplashTagline` is a bare `Text` directly inside `_SplashBody`'s
      // Column, with no Padding and no width constraint, so its line box is
      // the full safe width of the device.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: previewCanvas(brandedSplashCompactPhone, const Locale('en')),
        ),
      );
      await tester.pumpAndSettle();

      final Rect frame = tester.getRect(find.byType(BrandedSplash));
      final Rect tagline = tester.getRect(find.text('Delivery App'));

      // Measured 360 x 96 at left = 0: the line box takes the whole 360 pt
      // frame with ZERO horizontal gutter, and wraps to two lines. This
      // device has no side insets, so `SafeArea` contributes nothing and the
      // glyphs run to the display edge.
      //
      // The two-line wrap is a test-font artifact — flutter_test renders every
      // glyph as a square of the font size, so 'Delivery App' needs 384 pt at
      // 32 px where Inter needs roughly half that, and the real app keeps one
      // line here. The zero gutter is NOT an artifact: it is structural, and
      // it is what any longer string (a new locale, a reworded tagline) would
      // wrap against.
      expect(tagline.left, frame.left, reason: 'no left gutter at all');
      expect(tagline.right, frame.right, reason: 'no right gutter at all');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the tagline never renders as raw English in Arabic', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        brandedSplashFigmaFrame,
        locale: const Locale('ar'),
      );

      expect(find.text('تطبيق التوصيل'), findsOneWidget);
      expect(find.text('Delivery App'), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(BrandedSplash))),
        TextDirection.rtl,
      );
    });

    test('the tagline colour pair only survives in the light scheme', () {
      // `_SplashTagline` inks with `colorScheme.onSecondary` on the
      // `colorScheme.secondaryContainer` fill `BrandedSplash` paints. That is
      // not an M3 pair — the M3 partner of `secondaryContainer` is
      // `onSecondaryContainer` — so nothing derives the two together.
      final ColorScheme light = AppTheme.light().colorScheme;
      expect(
        _contrast(light.onSecondary, light.secondaryContainer),
        greaterThanOrEqualTo(4.5),
        reason: 'measured 17.13 : 1 — white on brand navy, the rendering '
            'designers signed off, and it must not regress',
      );

      // Dark measures 1.40 : 1. `ColorScheme.fromSeed(_jeebNavy, dark)` puts
      // `onSecondary` at a dark tone and `secondaryContainer` at a nearby dark
      // tone, so the only string on the splash all but disappears. This is not
      // hypothetical: `jeeb_bootstrap.dart:190-192` hosts BrandedSplash with
      // `themeMode: ThemeMode.system`, so it IS the first frame every
      // dark-mode user sees. Asserted loosely on purpose — pinning 1.40 would
      // make fixing the palette a test failure, and asserting 4.5 fails today.
      final ColorScheme dark = AppTheme.dark().colorScheme;
      expect(_contrast(dark.onSecondary, dark.secondaryContainer),
          greaterThan(1.0));
      expect(
        _contrast(dark.onSecondary, dark.secondaryContainer),
        lessThan(3.0),
        reason: 'documents the defect the AR RTL dark rendering shows; delete '
            'this expectation when the pair is fixed',
      );

      // The M3-correct partner for the same fill measures 7.23 : 1, so the fix
      // is a one-word role change rather than a palette change.
      expect(
        _contrast(dark.onSecondaryContainer, dark.secondaryContainer),
        greaterThanOrEqualTo(4.5),
      );
    });
  });
}
