// Render tests for the DmOnboardingStepHeader previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`: every preview builds in both
// locales, and each one is pinned to a string only IT renders.
//
// Pinning real copy is possible here — and worth insisting on — because the
// widget's ONLY inputs are two strings. Five previews that all resolved to the
// same ARB pair would be five pictures of one state, and `find.text` on the
// shipped copy is what says they are not.
//
// Below that are the assertions the canvas can only show a human: the
// periwinkle-on-white subtitle, the heading that is not a heading, the
// non-scaling gap, and how much of the step the header eats at the 200% text
// ceiling.
//
// One caveat on the measurements. `flutter test` substitutes the `FlutterTest`
// font, whose glyphs are wider than the shipped Inter, so copy wraps to more
// lines here than on a device and the height numbers are pessimistic. The
// claims that do NOT depend on the font are the colour pairing, the semantics,
// and the 4.0 gap — those are exact.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_step_header.dart';
import 'package:jeeb_mobile/previews/jeeber_onboarding/dm_onboarding_step_header_preview.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Photo step (production copy)': dmOnboardingStepHeaderPhotoStep,
  'Service area (production copy)': dmOnboardingStepHeaderServiceArea,
  'Longest copy (KYC identity)': dmOnboardingStepHeaderLongestCopy,
  'Compact device (320pt)': dmOnboardingStepHeaderCompactDevice,
  'Blank subtitle': dmOnboardingStepHeaderBlankSubtitle,
};

/// WCAG relative-luminance contrast ratio in [1, 21] — the same helper
/// `test/core/theme/color_role_contrast_test.dart` gates the palette with.
double _contrast(Color fg, Color bg) {
  final double l1 = fg.computeLuminance();
  final double l2 = bg.computeLuminance();
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

/// WCAG 2.2 AA minimum for normal-size text.
const double _aaText = 4.5;

final Finder _header = find.byType(DmOnboardingStepHeader);

/// Pumps [preview] into a real device box instead of the 800x600 test surface,
/// optionally at a raised text scale. The previews leave HEIGHT to the canvas
/// box declared in the annotation, so a geometry assertion on the default
/// surface would measure a box no state actually declares.
Future<void> _pumpAt(
  WidgetTester tester,
  Widget Function() preview, {
  required Size size,
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DmOnboardingStepHeader',
    _previews,
    expectedText: const <String, String>{
      'Photo step (production copy)': 'Upload a clear photo for you',
      'Service area (production copy)': 'Select the working area',
      'Longest copy (KYC identity)': 'Upload your national ID',
      'Compact device (320pt)': 'Take a selfie',
      'Blank subtitle': 'Personal Details',
    },
  );

  group('DmOnboardingStepHeader preview copy', () {
    testWidgets('each state renders BOTH shipped ARB lines', (
      WidgetTester tester,
    ) async {
      // `expectedText` pins one line per state; this is the other half — that
      // the subtitle under each title is the one its call site really passes.
      await pumpPreview(tester, dmOnboardingStepHeaderPhotoStep);
      expect(find.text('For more credibility'), findsOneWidget);

      await pumpPreview(tester, dmOnboardingStepHeaderServiceArea);
      expect(
        find.text('Where do you want to offer your services?'),
        findsOneWidget,
      );

      await pumpPreview(tester, dmOnboardingStepHeaderLongestCopy);
      expect(
        find.text(
          'We need a clear photo of both sides. Make sure the text is '
          'legible and the corners are visible.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the copy really localizes — no hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        dmOnboardingStepHeaderPhotoStep,
        locale: const Locale('ar'),
      );

      expect(find.text('ارفع صورة واضحة لك'), findsOneWidget);
      expect(find.text('لمزيد من المصداقية'), findsOneWidget);
      expect(find.text('Upload a clear photo for you'), findsNothing);
    });

    testWidgets('start-aligned content mirrors under RTL', (
      WidgetTester tester,
    ) async {
      // The good-news half of the AR RTL rendering: `CrossAxisAlignment.start`
      // plus a `Text` with no `textAlign` means both lines hug the leading
      // edge in either direction. No hardcoded `EdgeInsets.only` to unpick.
      await _pumpAt(
        tester,
        dmOnboardingStepHeaderServiceArea,
        size: const Size(390, 800),
      );
      final double ltrTitleLeft =
          tester.getRect(find.text('Select the working area')).left;

      await _pumpAt(
        tester,
        dmOnboardingStepHeaderServiceArea,
        size: const Size(390, 800),
        locale: const Locale('ar'),
      );
      final Rect rtlTitle = tester.getRect(find.text('اختر منطقة العمل'));

      // LTR: the title starts at the gutter. RTL: it ENDS at the mirrored one.
      expect(ltrTitleLeft, 24);
      expect(rtlTitle.right, 390 - 24);
    });
  });

  group('DmOnboardingStepHeader preview a11y', () {
    testWidgets(
      'the subtitle is periwinkle on white — 3.76:1, below AA',
      (WidgetTester tester) async {
        // DELETE THIS TEST when the widget migrates the subtitle to
        // `onSurfaceVariant`. It exists to document a defect, so it fails on
        // the fix — deliberately.
        //
        // `test/core/theme/color_role_contrast_test.dart` keeps a guard named
        // "the OLD periwinkle-on-white pairing was genuinely failing": every
        // label role was migrated off `onSecondaryContainer` on a light
        // surface precisely because of this ratio. This widget still does it.
        await pumpPreview(tester, dmOnboardingStepHeaderPhotoStep);

        final ColorScheme scheme = AppTheme.light().colorScheme;
        final Text subtitle =
            tester.widget<Text>(find.text('For more credibility'));

        expect(subtitle.style?.color, scheme.onSecondaryContainer);
        expect(
          _contrast(scheme.onSecondaryContainer, scheme.surface),
          lessThan(_aaText),
          reason: 'If this passes, the palette moved — recheck the subtitle.',
        );

        // What it should have been: the migrated label role, on the same
        // surface, clears AA with room to spare.
        expect(
          _contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThanOrEqualTo(_aaText),
        );

        // The title is fine: navy `primary` on white.
        final Text title =
            tester.widget<Text>(find.text('Upload a clear photo for you'));
        expect(title.style?.color, scheme.primary);
        expect(
          _contrast(scheme.primary, scheme.surface),
          greaterThanOrEqualTo(_aaText),
        );
      },
    );

    testWidgets('the step header is not a heading to a screen reader', (
      WidgetTester tester,
    ) async {
      // Disposed inline rather than in a tearDown: the end-of-test handle
      // verification runs BEFORE tearDowns and fails on a live handle.
      final SemanticsHandle handle = tester.ensureSemantics();

      await pumpPreview(tester, dmOnboardingStepHeaderServiceArea);

      final SemanticsData title = tester
          .getSemantics(find.text('Select the working area'))
          .getSemanticsData();

      expect(title.label, 'Select the working area');
      // The gap. The class is named `StepHeader` and paints a `headlineSmall`
      // in extra-bold navy, but neither `Text` sets `header: true` and no
      // ancestor adds it, so TalkBack/VoiceOver heading navigation skips the
      // only element on the step that names the step.
      expect(title.flagsCollection.isHeader, isFalse);

      handle.dispose();
    });

    testWidgets('a blank subtitle still costs a node and 4pt of space', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingStepHeaderBlankSubtitle);

      final Finder texts =
          find.descendant(of: _header, matching: find.byType(Text));
      expect(texts, findsNWidgets(2));
      expect(find.text(''), findsOneWidget);

      // No `if (subtitle.isEmpty)` branch: the gap and the empty line box are
      // laid out anyway, so the heading sits on top of dead space.
      final double gap = tester.getRect(find.text('')).top -
          tester.getRect(find.text('Personal Details')).bottom;
      expect(gap, 4);

      // And the empty string is not free: it still gets a full line box, so a
      // subtitle-less step pays 4pt + one line of nothing.
      expect(tester.getRect(find.text('')).height, greaterThan(0));
    });
  });

  group('DmOnboardingStepHeader preview geometry', () {
    testWidgets('the 4pt gap does not follow the text scaler', (
      WidgetTester tester,
    ) async {
      const Size box = Size(390, 900);
      const String title = 'Upload your national ID';
      const String subtitle =
          'We need a clear photo of both sides. Make sure the text is '
          'legible and the corners are visible.';

      double gapAt(WidgetTester tester) =>
          tester.getRect(find.text(subtitle)).top -
          tester.getRect(find.text(title)).bottom;

      await _pumpAt(tester, dmOnboardingStepHeaderLongestCopy, size: box);
      expect(gapAt(tester), 4);

      await _pumpAt(
        tester,
        dmOnboardingStepHeaderLongestCopy,
        size: box,
        textScale: 2.0,
      );

      // `Spacing.twoXSmall` is a raw logical 4, so at the accessibility
      // ceiling a 48px headline and a 28px subtitle are still 4pt apart and
      // the two lines read as one clump.
      expect(gapAt(tester), 4);
    });

    testWidgets('at 200% text the header alone eats most of the step', (
      WidgetTester tester,
    ) async {
      const Size box = Size(390, 900);

      await _pumpAt(tester, dmOnboardingStepHeaderLongestCopy, size: box);
      final double atOneX = tester.getSize(_header).height;

      await _pumpAt(
        tester,
        dmOnboardingStepHeaderLongestCopy,
        size: box,
        textScale: 2.0,
      );
      final double atTwoX = tester.getSize(_header).height;

      // Both lines scale and both wrap further, so the growth is
      // super-linear — the header is taller than a 390x844 phone's whole
      // scrollable area above `DmOnboardingStepLayout`'s pinned Continue
      // button before the step draws any content of its own. It scrolls
      // rather than overflowing, which is the only reason this is an
      // ergonomics finding and not a broken screen.
      // Measured here: 148 → 620 (4.2x). Both lines scale AND both wrap
      // further, so the growth is super-linear. The assertions are the
      // font-independent shape of that, not the exact numbers.
      expect(atTwoX, greaterThan(atOneX * 2));
      expect(atTwoX, greaterThan(300));
    });

    testWidgets('the compact device narrows the text column, not the copy', (
      WidgetTester tester,
    ) async {
      await _pumpAt(
        tester,
        dmOnboardingStepHeaderCompactDevice,
        size: const Size(320, 800),
      );

      // 320 minus the two 24pt gutters `DmOnboardingStepLayout` applies.
      expect(tester.getSize(_header).width, 272);
      expect(find.text('Take a selfie'), findsOneWidget);
    });
  });
}
