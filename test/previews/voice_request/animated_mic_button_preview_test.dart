// Render tests for the AnimatedMicButton previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the shared template — see
// `test/previews/preview_test_harness.dart`.
//
// The widget renders no text, so `expectedText` pins each specimen's caption.
// A caption is only half the proof for an icon-only widget, so the specifics
// group below also pins the PROPS each specimen carries: six frozen circles
// are the easiest possible case for a preview file to render one state six
// times and still pass.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/voice_request/presentation/widgets/animated_mic_button.dart';

import '../preview_test_harness.dart';

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'AnimatedMicButton',
    const <String, Widget Function()>{
      'Idle · hold to record': animatedMicButtonIdle,
      'Recording · pulse frozen': animatedMicButtonRecording,
      'Disabled · mic unavailable': animatedMicButtonDisabled,
      'Disabled mid-recording': animatedMicButtonDisabledMidRecording,
      'Compact · 56dp': animatedMicButtonCompact,
      'Halo ceiling · reserved box': animatedMicButtonHaloCeiling,
    },
    expectedText: const <String, String>{
      'Idle · hold to record': 'Idle · hold to record',
      'Recording · pulse frozen': 'Recording · pulse frozen',
      'Disabled · mic unavailable': 'Disabled · mic unavailable',
      'Disabled mid-recording': 'Disabled mid-recording',
      'Compact · 56dp': 'Compact · 56dp',
      'Halo ceiling · reserved box': 'Halo ceiling · reserved box',
    },
  );

  group('AnimatedMicButton preview specifics', () {
    AnimatedMicButton buttonIn(WidgetTester tester) =>
        tester.widget<AnimatedMicButton>(find.byType(AnimatedMicButton));

    const List<Widget Function()> all = <Widget Function()>[
      animatedMicButtonIdle,
      animatedMicButtonRecording,
      animatedMicButtonDisabled,
      animatedMicButtonDisabledMidRecording,
      animatedMicButtonCompact,
      animatedMicButtonHaloCeiling,
    ];

    testWidgets('each specimen shows exactly one button', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in all) {
        await pumpPreview(tester, preview);
        expect(find.byType(AnimatedMicButton), findsOneWidget);
      }
    });

    // The caption is preview chrome — it would keep passing if every specimen
    // built the same button. These are the props the captions claim.
    testWidgets('the specimens differ in the props, not just the caption', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, animatedMicButtonIdle);
      expect(buttonIn(tester).isRecording, isFalse);
      expect(buttonIn(tester).enabled, isTrue);

      await pumpPreview(tester, animatedMicButtonRecording);
      expect(buttonIn(tester).isRecording, isTrue);
      expect(buttonIn(tester).enabled, isTrue);

      await pumpPreview(tester, animatedMicButtonDisabled);
      expect(buttonIn(tester).isRecording, isFalse);
      expect(buttonIn(tester).enabled, isFalse);

      await pumpPreview(tester, animatedMicButtonDisabledMidRecording);
      expect(buttonIn(tester).isRecording, isTrue);
      expect(buttonIn(tester).enabled, isFalse);
    });

    testWidgets('the compact specimen shrinks the only sizing seam', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, animatedMicButtonIdle);
      final double production = buttonIn(tester).diameter;

      await pumpPreview(tester, animatedMicButtonCompact);
      expect(buttonIn(tester).diameter, lessThan(production));
      // Material's minimum tap target — the widget composes a raw
      // GestureDetector, so nothing enforces this for it.
      expect(
        buttonIn(tester).diameter,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
    });

    // The semantics label is the only user-facing string this widget has and
    // the caller supplies it, so a preview that hardcoded English would render
    // an identical-looking canvas while hiding a missing translation.
    testWidgets('semantics labels come from the ambient locale', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, animatedMicButtonIdle);
      expect(
        buttonIn(tester).semanticLabel,
        'Record voice request. Press and hold to record, release to stop.',
      );

      await pumpPreview(
        tester,
        animatedMicButtonIdle,
        locale: const Locale('ar'),
      );
      expect(
        buttonIn(tester).semanticLabel,
        'تسجيل طلب صوتي. اضغط مع الاستمرار للتسجيل، وأفلت للإيقاف.',
      );

      await pumpPreview(
        tester,
        animatedMicButtonDisabled,
        locale: const Locale('ar'),
      );
      expect(buttonIn(tester).semanticLabel, 'الميكروفون غير متاح');
    });

    // The recording specimens are only reviewable because `TickerMode` mutes
    // the repeating pulse — an unmuted `AnimationController.repeat` schedules
    // frames forever and `pumpPreview`'s `pumpAndSettle` never returns. If
    // this test starts timing out, the TickerMode wrapper was deleted.
    testWidgets('the recording specimens settle', (WidgetTester tester) async {
      await pumpPreview(tester, animatedMicButtonRecording);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await pumpPreview(tester, animatedMicButtonDisabledMidRecording);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    // The premise of the halo-ceiling specimen: the widget reserves
    // `diameter × 1.6` but the halo reaches `diameter × 1.6875` at the top of
    // the pulse, so the peak is clamped by the constraints. If the widget is
    // ever fixed — reserve the peak, or cap the tween — this expectation is
    // the thing to update.
    testWidgets('the reserved box is smaller than the peak halo', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, animatedMicButtonIdle);
      final double diameter = buttonIn(tester).diameter;
      final Size reserved = tester.getSize(find.byType(AnimatedMicButton));

      expect(
        reserved.width,
        closeTo(diameter * animatedMicButtonReservedFactor, 0.01),
      );
      expect(reserved.width, closeTo(reserved.height, 0.01));
      expect(
        diameter * animatedMicButtonPeakHaloFactor,
        greaterThan(reserved.width),
      );
    });
  });
}
