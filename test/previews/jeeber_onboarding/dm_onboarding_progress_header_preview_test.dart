// Render tests for the DmOnboardingProgressHeader previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_state.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_progress_header.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Step 1 · photo': dmOnboardingProgressHeaderStepPhoto,
  'Step 2 · address': dmOnboardingProgressHeaderStepAddress,
  'Step 3 · service area': dmOnboardingProgressHeaderStepServiceArea,
  'Submitting on step 3': dmOnboardingProgressHeaderSubmitting,
  'Submitted · full bar': dmOnboardingProgressHeaderSubmitted,
};

/// The phone the wizard ships on, and the width the previews declare. The
/// shared harness pumps onto the default 800 × 600 surface, so anything
const Size _kPhone = Size(390, 844);

/// `_ProgressBarTrack` pads the bar by `Spacing.xLarge` on each side, so this
/// is the width the painter is handed at [_kPhone].
const double _kTrackWidth = 390 - 2 * Spacing.xLarge;

/// The painter's line sits on the vertical centre of a `barHeight` tall box.
const double _kLineY = DmOnboardingProgressHeader.barHeight / 2;

Finder get _bar => find.descendant(
      of: find.byKey(DmOnboardingProgressHeader.rootKey),
      matching: find.byType(OMDSStepperProgress),
    );

Finder get _barPainter => find.descendant(
      of: find.byKey(DmOnboardingProgressHeader.rootKey),
      matching: find.byType(CustomPaint),
    );

/// Pumps [preview] at [_kPhone] rather than the default test surface.
Future<void> _pumpOnPhone(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(_kPhone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpPreview(tester, preview, locale: locale);
}

/// Pumps [preview] the way the canvas's **200% text** rendering does, and
/// returns the exception the frame reported, if any.
Future<Object?> _pumpAtDoubleText(
  WidgetTester tester,
  Widget Function() preview,
) async {
  await tester.binding.setSurfaceSize(_kPhone);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: previewCanvas(preview, const Locale('en')),
    ),
  );
  await tester.pumpAndSettle();
  return tester.takeException();
}

/// Every `drawLine` the bar recorded, in paint order: the track first, then —
/// only when the fill is non-zero — the progress line.
List<({Offset from, Offset to})> _paintedLines(WidgetTester tester) {
  final List<({Offset from, Offset to})> lines =
      <({Offset from, Offset to})>[];
  expect(
    tester.renderObject(_barPainter),
    paints
      ..everything((Symbol method, List<dynamic> arguments) {
        if (method == #drawLine) {
          lines.add((
            from: arguments[0] as Offset,
            to: arguments[1] as Offset,
          ));
        }
        return true;
      }),
  );
  return lines;
}

/// The screen-reader value the header publishes for the pumped state.
String _semanticsValue(WidgetTester tester) {
  final SemanticsHandle handle = tester.ensureSemantics();
  final String value =
      tester.getSemantics(find.byKey(DmOnboardingProgressHeader.rootKey)).value;
  handle.dispose();
  return value;
}

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DmOnboardingProgressHeader',
    _previews,
    // Captions, not widget output — see the header. Every state names itself,
    expectedText: const <String, String>{
      'Step 1 · photo': 'Step 1 of 3 — bar empty',
      'Step 2 · address': 'Step 2 of 3 — one third',
      'Step 3 · service area': 'Step 3 of 3 — two thirds',
      'Submitting on step 3': 'Submitting — bar unchanged',
      'Submitted · full bar': 'Submitted — bar full',
    },
  );

  group('DmOnboardingProgressHeader preview state', () {
    // The assertion the caption-based `expectedText` above cannot make: five
    const Map<String, int> completedByState = <String, int>{
      'Step 1 · photo': 0,
      'Step 2 · address': 1,
      'Step 3 · service area': 2,
      'Submitting on step 3': 2,
      'Submitted · full bar': 3,
    };

    completedByState.forEach((String state, int completed) {
      testWidgets('$state forwards completedSteps=$completed', (
        WidgetTester tester,
      ) async {
        await pumpPreview(tester, _previews[state]!);

        final OMDSStepperProgress bar = tester.widget<OMDSStepperProgress>(_bar);
        expect(bar.completedSteps, completed);
        expect(bar.totalSteps, DmOnboardingState.totalSteps);
        expect(bar.height, DmOnboardingProgressHeader.barHeight);
      });
    });

    const Map<String, String> valueByState = <String, String>{
      'Step 1 · photo': 'Step 1 of 3',
      'Step 2 · address': 'Step 2 of 3',
      'Step 3 · service area': 'Step 3 of 3',
      'Submitting on step 3': 'Step 3 of 3',
      'Submitted · full bar': 'Step 3 of 3',
    };

    valueByState.forEach((String state, String value) {
      testWidgets('$state announces "$value"', (WidgetTester tester) async {
        await pumpPreview(tester, _previews[state]!);

        expect(_semanticsValue(tester), value);
        // The value is a11y-only by design (Figma) — it must never become
        expect(find.text(value), findsNothing);
      });
    });

    testWidgets('the value is localized, not hardcoded English', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        dmOnboardingProgressHeaderStepServiceArea,
        locale: const Locale('ar'),
      );

      // Latin digits are correct here: the generated accessor interpolates
      expect(_semanticsValue(tester), 'الخطوة 3 من 3');
    });
  });

  group('DmOnboardingProgressHeader preview geometry', () {
    testWidgets('step 1 paints the track and NO fill at all', (
      WidgetTester tester,
    ) async {
      await _pumpOnPhone(tester, dmOnboardingProgressHeaderStepPhoto);

      // `completedSteps` is `step.index`, so the first step is 0/3 and
      expect(tester.renderObject(_barPainter),
          paintsExactlyCountTimes(#drawLine, 1));

      final List<({Offset from, Offset to})> lines = _paintedLines(tester);
      expect(lines, hasLength(1));
      expect(lines.single.from, const Offset(0, _kLineY));
      expect(lines.single.to, const Offset(_kTrackWidth, _kLineY));
    });

    const Map<String, double> fillByState = <String, double>{
      'Step 2 · address': 1 / 3,
      'Step 3 · service area': 2 / 3,
      'Submitted · full bar': 1,
    };

    fillByState.forEach((String state, double fraction) {
      testWidgets('$state fills the track to ${(fraction * 100).round()}%', (
        WidgetTester tester,
      ) async {
        await _pumpOnPhone(tester, _previews[state]!);

        final List<({Offset from, Offset to})> lines = _paintedLines(tester);
        expect(lines, hasLength(2), reason: 'track, then fill');
        expect(lines.last.to.dx, closeTo(_kTrackWidth * fraction, 0.01));
      });
    });

    testWidgets('an in-flight submit does not move the bar', (
      WidgetTester tester,
    ) async {
      // The contract behind the deliberately identical-looking preview: the
      await _pumpOnPhone(tester, dmOnboardingProgressHeaderSubmitting);
      final double submitting = _paintedLines(tester).last.to.dx;

      await _pumpOnPhone(tester, dmOnboardingProgressHeaderStepServiceArea);
      final double idle = _paintedLines(tester).last.to.dx;

      expect(submitting, idle);
    });

    testWidgets('the header survives the 200% text ceiling', (
      WidgetTester tester,
    ) async {
      // The bar carries no text of its own, so the accessibility ceiling should
      expect(await _pumpAtDoubleText(tester, dmOnboardingProgressHeaderSubmitted),
          isNull);
    });

    testWidgets('the declared canvas box fits the content at 200% text', (
      WidgetTester tester,
    ) async {
      // The previews declare `Size(390, 128)`. A box too small clips the canvas
      expect(
        await _pumpAtDoubleText(tester, dmOnboardingProgressHeaderSubmitting),
        isNull,
      );

      final double rendered = tester
          .getSize(
            find
                .ancestor(
                  of: find.byKey(DmOnboardingProgressHeader.rootKey),
                  matching: find.byType(Column),
                )
                .first,
          )
          .height;
      expect(rendered, lessThanOrEqualTo(128));
    });
  });

  // FINDING, and the reason these previews were worth writing.
  group('DmOnboardingProgressHeader RTL mirroring', () {
    testWidgets('the padding DOES mirror', (WidgetTester tester) async {
      // The control. Without it, "the fill does not mirror" could be read as
      await _pumpOnPhone(tester, dmOnboardingProgressHeaderStepAddress);
      final Rect ltr = tester.getRect(_bar);

      await _pumpOnPhone(
        tester,
        dmOnboardingProgressHeaderStepAddress,
        locale: const Locale('ar'),
      );
      final Rect rtl = tester.getRect(_bar);

      // Symmetric insets, so the track occupies the same band either way —
      expect(ltr, rtl);
      expect(ltr.width, _kTrackWidth);
    });

    testWidgets('the FILL does not mirror', (WidgetTester tester) async {
      await _pumpOnPhone(
        tester,
        dmOnboardingProgressHeaderStepAddress,
        locale: const Locale('ar'),
      );

      final List<({Offset from, Offset to})> lines = _paintedLines(tester);
      expect(lines, hasLength(2));

      // Under RTL the filled third should hug the RIGHT edge of the track
      final ({Offset from, Offset to}) fill = lines.last;
      expect(fill.from.dx, 0);
      expect(fill.to.dx, closeTo(_kTrackWidth / 3, 0.01));
      expect(
        fill.from.dx,
        isNot(closeTo(_kTrackWidth, 0.01)),
        reason: 'a mirrored fill would start at the trailing (right) edge',
      );
    });
  });
}
