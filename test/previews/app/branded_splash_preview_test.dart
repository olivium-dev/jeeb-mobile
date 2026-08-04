// Render tests for the BrandedSplash previews.

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
      expect(
        await bottomGap(brandedSplashNotchedPhone),
        moreOrLessEquals(Spacing.fourXLarge + 34, epsilon: 0.5),
      );
    });

    testWidgets('the wordmark sits above true centre, and the notch moves it', (
      WidgetTester tester,
    ) async {
      // `_SplashBody`'s dartdoc claims the wordmark is "optically centered
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
      final Rect frame = await frameRect(tester, brandedSplashLandscape);
      final Rect logo = tester.getRect(find.byType(SvgPicture));
      final Rect tagline = tester.getRect(find.text('Delivery App'));

      final double safeHeight = frame.height - 21; // home indicator
      final double fixed = logo.height + tagline.height + Spacing.fourXLarge;

      // Measured: 372 pt safe height against 152.5 pt of fixed children
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

    // L12, FIXED: the pair this test used to document as a defect is gone —
    // `_SplashTagline` now inks `onSecondaryContainer`.
    test('the tagline pair clears AA in the one Midnight scheme', () {
      final ColorScheme scheme = AppTheme.midnight().colorScheme;
      expect(
        _contrast(scheme.onSecondaryContainer, scheme.secondaryContainer),
        greaterThanOrEqualTo(4.5),
      );

      // Discrimination: the reverted ink is what measured 1.17 : 1.
      expect(
        _contrast(scheme.onSecondary, scheme.secondaryContainer),
        lessThan(1.5),
      );

      // Both factories are Midnight (§1), so neither can regress separately.
      expect(AppTheme.light().colorScheme.onSecondaryContainer,
          scheme.onSecondaryContainer);
      expect(AppTheme.dark().colorScheme.onSecondaryContainer,
          scheme.onSecondaryContainer);
    });
  });
}
