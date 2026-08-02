// Render tests for the CaptureLocationPin previews.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/capture_location_pin.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Capture screen (production, full bleed)': captureLocationPinCaptureScreen,
  'Anchor: tip vs the chosen point': captureLocationPinAnchorCrosshair,
  'Address form band (production, 160pt)': captureLocationPinAddressFormBand,
  'Compact 48pt band (head clipped)': captureLocationPinCompactBand,
  'Inline in a Column (overdraws its neighbour)':
      captureLocationPinInlineOverdraw,
};

/// The four states that centre the pin in a host of their own. The fifth
/// (inline) has no centred host by design — that is its finding.
const Map<String, Size> _centredHosts = <String, Size>{
  'Capture screen (production, full bleed)': Size(390, 500),
  'Anchor: tip vs the chosen point': Size(390, 200),
  // `Sizes.eightXLarge * 2`, as `_PinPreview` sizes it.
  'Address form band (production, 160pt)': Size(390, 160),
  'Compact 48pt band (head clipped)': Size(390, 48),
};

/// Half the icon's own 40 pt box plus the 20 pt lift: how far above the anchor
/// the widget paints, and therefore the host margin it silently requires.
const double _paintAboveAnchor = Sizes.threeXLarge / 2 + Sizes.large;

/// The pin's layout box, untransformed — the space it claims from its parent.
Rect _box(WidgetTester tester) =>
    tester.getRect(find.byType(CaptureLocationPin));

/// Where the glyph is actually PAINTED. `getRect` walks the ancestor paint
/// transforms, so this includes the `Transform.translate` lift that [_box] does
Rect _glyph(WidgetTester tester) =>
    tester.getRect(find.byIcon(Icons.location_on));

/// The box the preview centres the pin in.
Rect _host(WidgetTester tester) => tester.getRect(find.byKey(captureLocationPinHostKey));

/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double lumA = a.computeLuminance();
  final double lumB = b.computeLuminance();
  final double hi = math.max(lumA, lumB);
  final double lo = math.min(lumA, lumB);
  return (hi + 0.05) / (lo + 0.05);
}

/// Pumps [preview] the way the canvas's **200% text** rendering does.
Future<void> _pumpAtDoubleText(
  WidgetTester tester,
  Widget Function() preview,
) async {
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: previewCanvas(preview, const Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'CaptureLocationPin',
    _previews,
    // Captions, not widget output — see the header. Every state names its own
    expectedText: const <String, String>{
      'Capture screen (production, full bleed)':
          'Capture screen: pin centred on a 390x500 map area',
      'Anchor: tip vs the chosen point':
          'Anchor study: crosshair marks the returned coordinate',
      'Address form band (production, 160pt)':
          'Address form: 160pt clipped band',
      'Compact 48pt band (head clipped)':
          'Compact band: 390x48 clipped thumbnail',
      'Inline in a Column (overdraws its neighbour)':
          'Inline column: pin paints 20pt above its own box',
    },
  );

  group('CaptureLocationPin anchor geometry', () {
    testWidgets('the glyph is painted 20 pt above the box it lays out in', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, captureLocationPinCaptureScreen);

      final Rect box = _box(tester);
      final Rect glyph = _glyph(tester);

      // The widget claims exactly the icon's box and nothing for the lift.
      expect(box.size, const Size(Sizes.threeXLarge, Sizes.threeXLarge));
      expect(glyph.size, box.size);
      expect(
        box.top - glyph.top,
        closeTo(Sizes.large, 0.01),
        reason: 'Transform.translate(0, -Sizes.large) paints outside the box',
      );
      expect(
        glyph.bottom,
        closeTo(box.center.dy, 0.01),
        reason: 'the icon BOX bottom — which the widget doc calls the tip — '
            'lands on the centre of the space the widget was given',
      );
    });

    // The assertion the caption-based `expectedText` above cannot make: five
    _centredHosts.forEach((String state, Size expected) {
      testWidgets('$state hosts the pin in ${expected.width}x'
          '${expected.height} and anchors on its centre', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, _previews[state]!);

        final Rect host = _host(tester);
        final Rect glyph = _glyph(tester);

        expect(host.size, expected);
        expect(glyph.center.dx, closeTo(host.center.dx, 0.01));
        expect(
          glyph.bottom,
          closeTo(host.center.dy, 0.01),
          reason: 'every host state must anchor on the coordinate the CTA '
              'returns, whatever its size',
        );
      });
    });

    testWidgets('no two states host the pin in the same box', (
      WidgetTester tester,
    ) async {
      final List<Size> sizes = <Size>[];
      for (final String state in _centredHosts.keys) {
        await pumpPreview(tester, _previews[state]!);
        sizes.add(_host(tester).size);
      }

      expect(
        sizes.toSet().length,
        sizes.length,
        reason: 'a preview set whose states all draw the same box is a set of '
            'one state with several names',
      );
    });

    testWidgets('nothing mirrors in Arabic: the pin lands on the same pixel', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, captureLocationPinCaptureScreen);
      final Offset en = _glyph(tester).center - _host(tester).center;

      await pumpPreview(
        tester,
        captureLocationPinCaptureScreen,
        locale: const Locale('ar'),
      );
      final Offset ar = _glyph(tester).center - _host(tester).center;

      expect(
        Directionality.of(tester.element(find.byType(CaptureLocationPin))),
        TextDirection.rtl,
      );
      // The only offset in the widget is vertical, so this is the correct
      expect(ar.dx, closeTo(en.dx, 0.01));
      expect(ar.dy, closeTo(en.dy, 0.01));
    });

    testWidgets('the pin does not scale with text, so the anchor holds at 200%',
        (WidgetTester tester) async {
      await pumpPreview(tester, captureLocationPinAnchorCrosshair);
      final Rect at1x = _glyph(tester);
      final Offset anchor1x = at1x.bottomCenter - _host(tester).center;

      await _pumpAtDoubleText(tester, captureLocationPinAnchorCrosshair);
      final Rect at2x = _glyph(tester);
      final Offset anchor2x = at2x.bottomCenter - _host(tester).center;

      // `Icon.applyTextScaling` is unset here and defaults to false, so the
      expect(at2x.size, at1x.size);
      expect(anchor2x.dx, closeTo(anchor1x.dx, 0.01));
      expect(anchor2x.dy, closeTo(anchor1x.dy, 0.01));
    });
  });

  // What the two failing hosts expose. Both are paint-outside-the-box problems,
  group('CaptureLocationPin host requirements', () {
    testWidgets('the 160 pt address-form band clears the clip by 40 pt', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, captureLocationPinAddressFormBand);

      final Rect host = _host(tester);
      final Rect glyph = _glyph(tester);

      expect(
        glyph.top - host.top,
        closeTo(_paintAboveAnchor, 0.01),
        reason: 'the anchor is at 80 pt and the pin paints 40 pt above it, so '
            'an 80 pt band is the smallest centred host that shows a whole '
            'pin — this one has double that and 40 pt of margin',
      );
      expect(glyph.top, greaterThan(host.top));
    });

    testWidgets('a 48 pt band silently clips 16 pt off the pin head', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, captureLocationPinCompactBand);

      final Rect host = _host(tester);
      final Rect glyph = _glyph(tester);

      expect(
        host.top - glyph.top,
        closeTo(_paintAboveAnchor - host.height / 2, 0.01),
        reason: '16 pt of glyph is outside the ClipRRect and simply gone',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'the pin\'s own 40 pt layout box fits inside 48, so nothing '
            'overflows and nothing warns — only the picture is wrong',
      );
    });

    testWidgets('inline in a Column, the pin paints over the row above it', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, captureLocationPinInlineOverdraw);

      final Rect row = tester.getRect(find.byKey(captureLocationPinRowAboveKey));
      final Rect box = _box(tester);
      final Rect glyph = _glyph(tester);

      // The layout box is a good citizen: it starts exactly where the row above
      expect(box.top, closeTo(row.bottom, 0.01));
      expect(
        row.bottom - glyph.top,
        closeTo(Sizes.large, 0.01),
        reason: '20 pt of glyph is drawn inside the neighbour above it',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'no RenderFlex overflow: the box fits, the paint does not, and '
            'the framework only reports the former',
      );
    });
  });

  group('CaptureLocationPin ink and semantics', () {
    testWidgets('the glyph is colorScheme.error over one shadow(colorScheme)',
        (WidgetTester tester) async {
      await pumpPreview(tester, captureLocationPinCaptureScreen);

      final Icon icon = tester.widget<Icon>(find.byIcon(Icons.location_on));
      final ColorScheme light = AppTheme.light().colorScheme;

      expect(icon.size, Sizes.threeXLarge);
      expect(icon.color, light.error);
      expect(
        icon.applyTextScaling,
        isNull,
        reason: 'unset, so the 40 pt is fixed — see the anchor test above',
      );
      expect(icon.shadows, hasLength(1));
      expect(
        icon.shadows!.single.color,
        light.shadow.withValues(alpha: UIConstants.opacityLow),
      );
    });

    testWidgets('IgnorePointer does not cost the pin its accessibility node', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(tester, captureLocationPinCaptureScreen);

      // `IgnorePointer.ignoringSemantics` is deprecated and unset here, so the
      final Finder pin = find.bySemanticsIdentifier('capture_location_pin');
      expect(pin, findsOneWidget);

      final SemanticsNode node = tester.getSemantics(pin);
      expect(node.label, 'Selected location pin');
      expect(node.flagsCollection.isImage, isTrue);
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
        reason: 'the overlay must never intercept a map gesture',
      );

      handle.dispose();
    });

    testWidgets('the semantic label is localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpPreview(
        tester,
        captureLocationPinCaptureScreen,
        locale: const Locale('ar'),
      );

      expect(
        tester
            .getSemantics(find.bySemanticsIdentifier('capture_location_pin'))
            .label,
        'دبوس الموقع المحدد',
      );
      expect(find.bySemanticsLabel('Selected location pin'), findsNothing);

      handle.dispose();
    });

    test('the pin ink clears WCAG 1.4.11 on the map fill in both schemes', () {
      // The pin is a graphical object carrying meaning, so 1.4.11 asks 3:1.
      for (final ColorScheme scheme in <ColorScheme>[
        AppTheme.light().colorScheme,
        AppTheme.dark().colorScheme,
      ]) {
        expect(
          _contrast(scheme.error, scheme.surfaceContainerHighest),
          greaterThanOrEqualTo(3.0),
        );
      }
    });

    test('the lift shadow is black in both schemes, so it only reads in light',
        () {
      final ColorScheme light = AppTheme.light().colorScheme;
      final ColorScheme dark = AppTheme.dark().colorScheme;

      // `colorScheme.shadow` is #000000 in BOTH schemes — M3 does not tone it
      expect(light.shadow, dark.shadow);

      final double lightHalo = _contrast(
        Color.alphaBlend(
          light.shadow.withValues(alpha: UIConstants.opacityLow),
          light.surfaceContainerHighest,
        ),
        light.surfaceContainerHighest,
      );
      final double darkHalo = _contrast(
        Color.alphaBlend(
          dark.shadow.withValues(alpha: UIConstants.opacityLow),
          dark.surfaceContainerHighest,
        ),
        dark.surfaceContainerHighest,
      );

      // 2.59:1 in light, 1.31:1 in dark. The halo is the only thing that lifts
      expect(lightHalo, greaterThan(2.0));
      expect(darkHalo, lessThan(1.5));
      expect(lightHalo, greaterThan(darkHalo));
    });
  });
}
