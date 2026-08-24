// Render tests for the BrandedSplash previews.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/app/branded_splash.dart';

import '../preview_test_harness.dart';

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

    testWidgets(
      'each preview simulates its own window, not the 800 × 600 host',
      (WidgetTester tester) async {
        // If `_DeviceFrame` ever stopped pinning the MediaQuery/SizedBox, every
        expect(
          (await frameRect(tester, brandedSplashFigmaFrame)).size,
          _figmaFrame,
        );
        expect(
          (await frameRect(tester, brandedSplashCompactPhone)).size,
          _compactFrame,
        );
        expect(
          (await frameRect(tester, brandedSplashNotchedPhone)).size,
          _notchedFrame,
        );
        expect(
          (await frameRect(tester, brandedSplashLandscape)).size,
          _landscapeFrame,
        );
        expect(
          (await frameRect(tester, brandedSplashTablet)).size,
          _tabletFrame,
        );
      },
    );

    testWidgets('the wordmark follows its responsive 42% width clamp', (
      WidgetTester tester,
    ) async {
      Future<double> logoWidth(Widget Function() preview) async {
        await pumpPreview(tester, preview);
        return tester.getSize(find.byType(SvgPicture)).width;
      }

      expect(await logoWidth(brandedSplashCompactPhone), 152);
      expect(await logoWidth(brandedSplashFigmaFrame), 184);
      expect(await logoWidth(brandedSplashTablet), 184);
    });

    testWidgets('the wordmark stays centered in each safe viewport', (
      WidgetTester tester,
    ) async {
      Future<double> centreOffset(Widget Function() preview) async {
        final Rect frame = await frameRect(tester, preview);
        final Rect logo = tester.getRect(find.byType(SvgPicture));
        return logo.center.dy - frame.center.dy;
      }

      expect(
        await centreOffset(brandedSplashFigmaFrame),
        moreOrLessEquals(0, epsilon: 0.5),
      );
      expect(
        await centreOffset(brandedSplashNotchedPhone),
        moreOrLessEquals(12.5, epsilon: 0.5),
      );
      expect(
        await centreOffset(brandedSplashLandscape),
        moreOrLessEquals(-10.5, epsilon: 0.5),
      );
    });

    testWidgets('locale direction changes without adding splash copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        brandedSplashFigmaFrame,
        locale: const Locale('ar'),
      );

      expect(find.text('تطبيق التوصيل'), findsNothing);
      expect(find.text('Delivery App'), findsNothing);
      expect(
        Directionality.of(tester.element(find.byType(BrandedSplash))),
        TextDirection.rtl,
      );
    });
  });
}
