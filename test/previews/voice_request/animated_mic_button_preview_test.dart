// Render tests for the AnimatedMicButton previews.

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
      expect(
        buttonIn(tester).diameter,
        greaterThanOrEqualTo(kMinInteractiveDimension),
      );
    });

    // The semantics label is the only user-facing string this widget has and
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
    testWidgets('the recording specimens settle', (WidgetTester tester) async {
      await pumpPreview(tester, animatedMicButtonRecording);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await pumpPreview(tester, animatedMicButtonDisabledMidRecording);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    // The premise of the halo-ceiling specimen: the widget reserves
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
