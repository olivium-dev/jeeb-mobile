// Render tests for the CaptureMapViewport previews.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/capture_map_viewport.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Capture screen (production, full bleed)': captureMapViewportCaptureScreen,
  'Address form band (production, 160pt)': captureMapViewportAddressFormBand,
  'Square thumbnail (160pt)': captureMapViewportThumbnail,
  'Short strip 96pt (breaks at 200%)': captureMapViewportShortStrip,
  'Unbounded height (collapses)': captureMapViewportUnboundedHeight,
};

/// The box each preview must produce, measured on the [CaptureMapViewport]
/// element itself.
const Map<String, Size> _expectedBoxes = <String, Size>{
  'Capture screen (production, full bleed)': Size(390, 500),
  // `Sizes.eightXLarge * 2`, as `_PinPreview` sizes it.
  'Address form band (production, 160pt)': Size(390, 160),
  'Square thumbnail (160pt)': Size(160, 160),
  'Short strip 96pt (breaks at 200%)': Size(390, 96),
  // NOT the 200 pt viewport it was given: `Container` shrink-wraps unbounded
  'Unbounded height (collapses)': Size(390, 88),
};

/// The intrinsic height of the content column: icon + gap + one line of
/// `bodyMedium`. Mirrored here because it is what the collapse in the scrolling
const double _contentHeightAtOneX = 56 + 12 + 20;

/// Height of the viewport the scrolling preview puts around the widget.
const double _scrollViewportHeight = 200;

/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double lumA = a.computeLuminance();
  final double lumB = b.computeLuminance();
  final double hi = math.max(lumA, lumB);
  final double lo = math.min(lumA, lumB);
  return (hi + 0.05) / (lo + 0.05);
}

/// Pumps [preview] the way the canvas's **200% text** rendering does.
/// Returns the exception the frame reported, if any — an overflowing
Future<Object?> pumpAtDoubleText(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
  return tester.takeException();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'CaptureMapViewport',
    _previews,
    // Captions, not widget output — see the header. Every state names its own
    expectedText: const <String, String>{
      'Capture screen (production, full bleed)':
          'Capture screen: 390x500 map area',
      'Address form band (production, 160pt)':
          'Address form: 160pt clipped band',
      'Square thumbnail (160pt)': 'Thumbnail: 160x160 square',
      'Short strip 96pt (breaks at 200%)': 'Short strip: 390x96 slot',
      'Unbounded height (collapses)': 'Unbounded: inside a scroll view',
    },
  );

  group('CaptureMapViewport preview specifics', () {
    // The assertion the caption-based `expectedText` above cannot make: five
    _expectedBoxes.forEach((String state, Size expected) {
      testWidgets('$state lays out at ${expected.width}x${expected.height}', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, _previews[state]!);

        expect(tester.getSize(find.byType(CaptureMapViewport)), expected);
      });
    });

    testWidgets('no two previews render the same box', (
      WidgetTester tester,
    ) async {
      final List<Size> sizes = <Size>[];
      for (final Widget Function() preview in _previews.values) {
        await pumpPreview(tester, preview);
        sizes.add(tester.getSize(find.byType(CaptureMapViewport)));
      }

      expect(
        sizes.toSet().length,
        sizes.length,
        reason: 'a preview set whose states all draw the same box is a set of '
            'one state with five names',
      );
    });

    testWidgets('the label is localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, captureMapViewportCaptureScreen);
      expect(find.text('Map preview'), findsOneWidget);

      await pumpPreview(
        tester,
        captureMapViewportCaptureScreen,
        locale: const Locale('ar'),
      );
      expect(find.text('Map preview'), findsNothing);
      expect(find.text('معاينة الخريطة'), findsOneWidget);
    });

    testWidgets('unbounded height collapses the band to its content', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, captureMapViewportUnboundedHeight);

      final Size box = tester.getSize(find.byType(CaptureMapViewport));
      expect(
        box.height,
        _contentHeightAtOneX,
        reason: '`Container` with an alignment and no size shrink-wraps '
            'unbounded constraints, so the map band becomes an 88 pt strip',
      );
      expect(
        box.height,
        lessThan(_scrollViewportHeight),
        reason: 'the scroll viewport offered 200 pt and the widget took 88 — '
            'a caller that omits the SizedBox `_PinPreview` supplies gets a '
            'tinted strip, silently, with no exception to notice it by',
      );
      // Width is still filled: only the unbounded axis collapses.
      expect(box.width, 390);
    });

    testWidgets('the full-bleed capture-screen area survives 200% text', (
      WidgetTester tester,
    ) async {
      expect(
        await pumpAtDoubleText(tester, captureMapViewportCaptureScreen),
        isNull,
      );
    });

    testWidgets('the 160 pt address-form band survives 200% text', (
      WidgetTester tester,
    ) async {
      // 88 pt of content at 1x, 108 pt at 200% (only the label scales; the
      expect(
        await pumpAtDoubleText(tester, captureMapViewportAddressFormBand),
        isNull,
      );
    });

    testWidgets('the 96 pt strip fits at 1x and overflows at 200%', (
      WidgetTester tester,
    ) async {
      // Half one: nothing looks wrong at 1x. 88 pt of content, 8 pt spare.
      await pumpPreview(tester, captureMapViewportShortStrip);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(CaptureMapViewport)).height, 96);

      // Half two: the label doubles to 40 pt and the column needs 108.
      final Object? overflow = await pumpAtDoubleText(
        tester,
        captureMapViewportShortStrip,
      );
      expect(
        overflow,
        isFlutterError,
        reason: 'the widget has no minimum height, no clip and no scroll, so '
            'a host that fits at 1x can still overflow at the 200% ceiling',
      );
      expect('$overflow', contains('overflowed by 12 pixels'));
    });

    testWidgets('a narrow host overflows at 200% in English', (
      WidgetTester tester,
    ) async {
      // 160 pt wide: the label wraps to three lines (120 pt), so the column
      final Object? overflow = await pumpAtDoubleText(
        tester,
        captureMapViewportThumbnail,
      );

      expect(overflow, isFlutterError);
      expect('$overflow', contains('overflowed by 28 pixels'));
    });

    testWidgets('a narrow host overflows at 200% in Arabic too', (
      WidgetTester tester,
    ) async {
      // The shorter Arabic string does not rescue it: same 28 pt. Worth its own
      final Object? overflow = await pumpAtDoubleText(
        tester,
        captureMapViewportThumbnail,
        locale: const Locale('ar'),
      );

      expect(overflow, isFlutterError);
      expect('$overflow', contains('overflowed by 28 pixels'));
    });

    test('the icon ink misses WCAG 1.4.11 on its own background in light', () {
      // The widget paints `surfaceContainerHighest` and then inks the icon with
      final ColorScheme light = AppTheme.light().colorScheme;
      final Color lightIcon = Color.alphaBlend(
        light.onSurfaceVariant.withValues(alpha: 0.60),
        light.surfaceContainerHighest,
      );

      // Measured 2.88:1 (#938080 on #E5E1E5). Asserted loosely on purpose:
      expect(
        _contrast(lightIcon, light.surfaceContainerHighest),
        greaterThan(1.0),
      );

      // The label is not the problem — this one IS a regression guard.
      expect(
        _contrast(light.onSurfaceVariant, light.surfaceContainerHighest),
        greaterThanOrEqualTo(4.5),
        reason: 'measured 7.23:1; the label must stay legible on the '
            'placeholder fill',
      );

      // Dark passes the icon (3.67:1), so this is a light-scheme bug.
      final ColorScheme dark = AppTheme.dark().colorScheme;
      final Color darkIcon = Color.alphaBlend(
        dark.onSurfaceVariant.withValues(alpha: 0.60),
        dark.surfaceContainerHighest,
      );
      expect(
        _contrast(darkIcon, dark.surfaceContainerHighest),
        greaterThanOrEqualTo(3.0),
      );
    });

    test('the placeholder fill barely separates from the Scaffold surface', () {
      // 1.29:1 in light, 1.50:1 in dark. Harmless on the capture screen (the
      for (final ColorScheme scheme in <ColorScheme>[
        AppTheme.light().colorScheme,
        AppTheme.dark().colorScheme,
      ]) {
        expect(
          _contrast(scheme.surfaceContainerHighest, scheme.surface),
          lessThan(3.0),
        );
      }
    });
  });
}
