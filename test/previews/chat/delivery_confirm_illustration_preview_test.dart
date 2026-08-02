// Render tests for the DeliveryConfirmIllustration previews.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/delivery_confirm_illustration.dart';

import '../preview_test_harness.dart';

/// The box each preview must produce, measured on the
/// `DeliveryConfirmIllustration` element itself.
const Map<String, Size> _expectedBoxes = <String, Size>{
  // (390 - 2 * 24) * 0.62 = 212.04 wide.
  'Sheet geometry (production)': Size(212.04, 117.365),
  // (320 - 2 * 24) * 0.62 = 168.64 wide.
  'Compact device (320pt)': Size(168.64, 93.343),
  'Full bleed (390pt)': Size(390, 215.867),
  // Unbounded width: the ratio is resolved from the height instead.
  'Height-driven in a row': Size(180.667, 100),
  // Tight on both axes: `RenderAspectRatio` returns `constraints.smallest`.
  'Squashed box (spills, unclipped)': Size(300, 60),
};

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Sheet geometry (production)': deliveryConfirmIllustrationSheetGeometry,
  'Compact device (320pt)': deliveryConfirmIllustrationCompactDevice,
  'Full bleed (390pt)': deliveryConfirmIllustrationFullBleed,
  'Height-driven in a row': deliveryConfirmIllustrationHeightDriven,
  'Squashed box (spills, unclipped)': deliveryConfirmIllustrationSquashedBox,
};

/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double lumA = a.computeLuminance();
  final double lumB = b.computeLuminance();
  final double hi = math.max(lumA, lumB);
  final double lo = math.min(lumA, lumB);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DeliveryConfirmIllustration',
    _previews,
    expectedText: const <String, String>{
      'Sheet geometry (production)': 'Sheet geometry: 62% of 390pt',
      'Compact device (320pt)': 'Compact device: 320pt sheet',
      'Full bleed (390pt)': 'Full bleed: 390pt wide',
      'Height-driven in a row': 'Height-driven: 100pt tall row',
      'Squashed box (spills, unclipped)': 'Squashed: tight 300x60 box',
    },
  );

  group('DeliveryConfirmIllustration preview specifics', () {
    // The assertion the caption-based `expectedText` above cannot make: five
    _expectedBoxes.forEach((String state, Size expected) {
      testWidgets('$state lays out at ${expected.width}x${expected.height}', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, _previews[state]!);

        final Size actual = tester.getSize(
          find.byType(DeliveryConfirmIllustration),
        );
        expect(actual.width, closeTo(expected.width, 0.05));
        expect(actual.height, closeTo(expected.height, 0.05));
      });
    });

    testWidgets('no two previews render the same box', (
      WidgetTester tester,
    ) async {
      final List<Size> sizes = <Size>[];
      for (final Widget Function() preview in _previews.values) {
        await pumpPreview(tester, preview);
        sizes.add(tester.getSize(find.byType(DeliveryConfirmIllustration)));
      }

      expect(
        sizes.toSet().length,
        sizes.length,
        reason: 'a preview set whose states all draw the same box is a set of '
            'one state with five names',
      );
    });

    testWidgets('every non-tight host preserves the 271:150 ratio', (
      WidgetTester tester,
    ) async {
      for (final String state in const <String>[
        'Sheet geometry (production)',
        'Compact device (320pt)',
        'Full bleed (390pt)',
        'Height-driven in a row',
      ]) {
        await pumpPreview(tester, _previews[state]!);

        final Size box = tester.getSize(
          find.byType(DeliveryConfirmIllustration),
        );
        expect(
          box.width / box.height,
          closeTo(271 / 150, 0.001),
          reason: '$state must keep the illustration undistorted',
        );
      }
    });

    testWidgets('a tight box defeats AspectRatio and the painter spills', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, deliveryConfirmIllustrationSquashedBox);

      final Size box = tester.getSize(find.byType(DeliveryConfirmIllustration));
      // `RenderAspectRatio` short-circuits on tight constraints
      expect(box, const Size(300, 60));
      expect(box.width / box.height, isNot(closeTo(271 / 150, 0.001)));

      // The painter still scales from `size.width` alone, so it draws this much
      final double painted = deliveryConfirmIllustrationNaturalHeight(box.width);
      expect(painted, closeTo(166.05, 0.05));
      expect(
        (painted - box.height) / 2,
        greaterThan(50),
        reason: 'CustomPaint does not clip: this much line art is painted '
            'outside the widget bounds, above and below, with no overflow '
            'stripe and no exception',
      );
    });

    testWidgets('is announced as a localized image, not as decoration', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, deliveryConfirmIllustrationSheetGeometry);
      expect(
        find.bySemanticsLabel('Package with clock and location pin'),
        findsOneWidget,
        reason: 'the illustration carries the meaning of the sheet for a '
            'screen-reader user, so it must not be silent',
      );

      await pumpPreview(
        tester,
        deliveryConfirmIllustrationSheetGeometry,
        locale: const Locale('ar'),
      );
      expect(find.bySemanticsLabel('Package with clock and location pin'),
          findsNothing);
      expect(find.bySemanticsLabel('طرد مع ساعة ودبوس موقع'), findsOneWidget);

      handle.dispose();
    });

    test('the stroke role only clears non-text contrast in the light scheme',
        () {
      // The painter inks with `colorScheme.secondaryContainer` on the sheet's
      final ColorScheme light = AppTheme.light().colorScheme;
      expect(
        _contrast(light.secondaryContainer, light.surface),
        greaterThanOrEqualTo(3.0),
        reason: 'brand navy on white — this is the rendering designers signed '
            'off and it must not regress',
      );

      // Dark measures 1.98:1 against 17.13:1 in light. `ColorScheme.fromSeed(
      final ColorScheme dark = AppTheme.dark().colorScheme;
      expect(_contrast(dark.secondaryContainer, dark.surface), greaterThan(1.0));
    });
  });
}
