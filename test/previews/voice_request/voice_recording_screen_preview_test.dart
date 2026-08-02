// Render tests for the VoiceRecordingScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/voice_request/presentation/voice_recording_screen.dart';

import '../preview_test_harness.dart';

/// The box every preview in this file declares
/// (`_voiceRecordingScreenPhoneBox`). The shared harness pumps at the
const Size _phoneBox = Size(390, 844);

/// Pumps a scripted preview to its designed state and returns any overflows.
/// Two things are load-bearing:
Future<List<String>> _pumpScripted(
  WidgetTester tester,
  Widget Function() preview, {
  Locale locale = const Locale('en'),
  Size box = _phoneBox,
  double textScale = 1.0,
}) async {
  await tester.binding.setSurfaceSize(box);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final List<String> seen = <String>[];
  final void Function(FlutterErrorDetails)? previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    seen.add(details.exceptionAsString());
  };

  await tester.pumpWidget(previewCanvas(preview, locale));
  // Six turns is comfortably more than the longest script needs (`send` is the
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  // Long enough for the cap state's snackbar to animate in.
  await tester.pump(const Duration(milliseconds: 300));
  FlutterError.onError = previous;

  return seen
      .where((String s) => s.contains('overflowed'))
      .toList(growable: false);
}

void main() {
  setUpAll(loadPreviewArbs);

  // The four states reached without `stopRecording`, so `pumpAndSettle` is
  testPreviewsRender(
    'VoiceRecordingScreen',
    const <String, Widget Function()>{
      'Idle · nothing recorded': voiceRecordingScreenIdle,
      'Recording · waveform bar': voiceRecordingScreenRecording,
      'Blocked · mic permission denied': voiceRecordingScreenPermissionDenied,
      'Blocked · recorder unavailable': voiceRecordingScreenRecorderUnavailable,
    },
    expectedText: const <String, String>{
      // The mic's own caption. Not the `00:00` timer, which the two blocked
      'Idle · nothing recorded': 'Hold to record',
      // 7s is this preview's alone, and the recording surface is the only one
      'Recording · waveform bar': '00:07 recorded',
      // The two blocked surfaces are near-identical by design; the title is the
      'Blocked · mic permission denied': 'Microphone access needed',
      'Blocked · recorder unavailable': 'Microphone unavailable',
    },
  );

  group('VoiceRecordingScreen previews · scripted past stopRecording', () {
    // Each of these asserts the SURFACE, not just the clock. Before this suite

    testWidgets('Recorded · ready to submit renders the review surface', (
      WidgetTester tester,
    ) async {
      await _pumpScripted(tester, voiceRecordingScreenRecorded);

      expect(find.text('Review your recording'), findsOneWidget);
      expect(find.text('00:03 recorded'), findsOneWidget);
      // Playback and the two-action row — none of which the recording surface
      expect(find.text('Play'), findsOneWidget);
      expect(find.text('Record again'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
      // The recording surface's own affordance is gone.
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('Sending · upload in flight renders the in-flight surface', (
      WidgetTester tester,
    ) async {
      await _pumpScripted(tester, voiceRecordingScreenSending);

      expect(find.text('Review your recording'), findsOneWidget);
      expect(find.text('00:12 recorded'), findsOneWidget);
      // Held open by a repository read that never lands.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The review actions are replaced by the loading button.
      expect(find.text('Submit'), findsNothing);
      expect(find.text('Record again'), findsNothing);
    });

    testWidgets('Sent · broadcasting renders the confirmation', (
      WidgetTester tester,
    ) async {
      await _pumpScripted(tester, voiceRecordingScreenSent);

      expect(find.text('Sent'), findsOneWidget);
      expect(
        find.text(
          "Your voice request was received. We'll find a Jeeber for you "
          'shortly.',
        ),
        findsOneWidget,
      );
      expect(find.text('Looking for Jeebers…'), findsOneWidget);
      expect(find.text('Record another'), findsOneWidget);
    });

    testWidgets('Upload failed · network renders the retained-clip error', (
      WidgetTester tester,
    ) async {
      await _pumpScripted(tester, voiceRecordingScreenUploadFailed);

      expect(find.text("Couldn't submit your recording"), findsOneWidget);
      expect(
        find.text(
          "Couldn't reach the server. Check your connection and try again.",
        ),
        findsOneWidget,
      );
      // The clip is RETAINED — this is a recoverable surface, not a snackbar
      expect(find.text('00:25 recorded'), findsOneWidget);
      expect(find.text('Retry upload & submit'), findsOneWidget);
      expect(find.text('Record again'), findsOneWidget);
    });

    testWidgets('Ceiling · 60 second cap renders review + snackbar together', (
      WidgetTester tester,
    ) async {
      await _pumpScripted(tester, voiceRecordingScreenDurationCeiling);

      // The persistent half: the cubit auto-finalised the clip at the cap
      expect(find.text('Review your recording'), findsOneWidget);
      // `01:00` is the only two-field timer this screen can render.
      expect(find.text('01:00 recorded'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
      // The transient half, and the only reason the user knows why recording
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('Recording stopped — 60 second maximum.'),
        findsOneWidget,
      );
    });

    // Arabic, for the five states the shared harness cannot reach. Pinned on
    testWidgets('the scripted states reach their own surface in AR too', (
      WidgetTester tester,
    ) async {
      await _pumpScripted(
        tester,
        voiceRecordingScreenSent,
        locale: const Locale('ar'),
      );

      // `sent` is the one surface with no timer at all, so finding no
      expect(find.textContaining('00:'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('VoiceRecordingScreen preview specifics', () {
    // Each state gets its OWN test: every preview here is the same widget tree

    // The finding. The screen passes `text: l10n.voiceRecordingSending`
    testWidgets('KNOWN DEFECT: the in-flight button renders no label at all', (
      WidgetTester tester,
    ) async {
      await _pumpScripted(tester, voiceRecordingScreenSending);

      expect(find.text('Sending…'), findsNothing);
      // Not a failed render — the screen is very much on the sending phase, it
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // The finding. `voiceRecordingTimerLabel` is past-tense copy
    testWidgets('the timer reads past-tense while the clip is still uploading',
        (WidgetTester tester) async {
      await _pumpScripted(tester, voiceRecordingScreenSending);

      expect(find.text('00:12 recorded'), findsOneWidget);
    });

    // The finding. `_TimerLabel` sits OUTSIDE the `_PrimarySurface` switch, so
    testWidgets('a blocked mic still renders a 00:00 timer above the error', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, voiceRecordingScreenPermissionDenied);

      expect(find.text('Microphone access needed'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      // The recoverable surface Sprint-6 Stream-B put in place of the old
      expect(find.text('Try again'), findsOneWidget);
    });

    // The same defect on the other side: a failed upload strands the clip's
    testWidgets('a failed upload strands the clip duration above the error', (
      WidgetTester tester,
    ) async {
      await _pumpScripted(tester, voiceRecordingScreenUploadFailed);

      expect(find.text("Couldn't submit your recording"), findsOneWidget);
      expect(find.text('00:25 recorded'), findsOneWidget);
    });

    // The finding. `_TimerLabel` returns `SizedBox.shrink()` on `sent`, so the
    testWidgets('the sent confirmation drops the duration entirely', (
      WidgetTester tester,
    ) async {
      await _pumpScripted(tester, voiceRecordingScreenSent);

      expect(find.text('Sent'), findsOneWidget);
      // 3s is what the default script records, and it is nowhere on screen.
      expect(find.text('00:03 recorded'), findsNothing);
      expect(find.textContaining('recorded'), findsNothing);
    });

    // The two blocking pre-conditions are near-identical surfaces. This pins
    testWidgets('the two blocked states differ only in their copy', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, voiceRecordingScreenRecorderUnavailable);

      expect(find.text('Microphone unavailable'), findsOneWidget);
      expect(
        find.text("The microphone isn't available right now."),
        findsOneWidget,
      );
      // Not the permission wording.
      expect(find.text('Microphone access needed'), findsNothing);
      // Same recovery affordance as the permission card.
      expect(find.text('Try again'), findsOneWidget);
    });

    // The recording surface prints the elapsed time THREE times — the waveform
    testWidgets('the recording surface prints the elapsed time three times', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, voiceRecordingScreenRecording);

      // The display clock and the bar's own timer are both bare `00:07`.
      expect(find.text('00:07'), findsNWidgets(2));
      // Plus the labelled one.
      expect(find.text('00:07 recorded'), findsOneWidget);
    });

    // The idle surface is the screen's empty state, and the point of previewing
    testWidgets('the idle surface documents neither the cap nor the floor', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, voiceRecordingScreenIdle);

      expect(find.text('Hold to record'), findsOneWidget);
      expect(
        find.text('Press and hold the mic. Release to stop.'),
        findsOneWidget,
      );
      expect(find.textContaining('60'), findsNothing);
      expect(find.textContaining('second'), findsNothing);
    });
  });

  group('VoiceRecordingScreen previews · at the declared canvas box', () {
    // KNOWN DEFECT, and the reason the declared box matters. The review
    for (final ({String name, Widget Function() preview}) state in <({
      String name,
      Widget Function() preview
    })>[
      (name: 'Recorded · ready to submit', preview: voiceRecordingScreenRecorded),
      (
        name: 'Upload failed · network',
        preview: voiceRecordingScreenUploadFailed
      ),
    ]) {
      testWidgets(
        'KNOWN DEFECT: ${state.name} overflows the review row at 390 pt',
        (WidgetTester tester) async {
          final List<String> en =
              await _pumpScripted(tester, state.preview);

          expect(
            en,
            isNotEmpty,
            reason: 'the two-action row does not fit a 390 pt phone in English',
          );
          expect(en.every((String s) => s.contains('on the right')), isTrue);
        },
      );
    }

    testWidgets('KNOWN DEFECT: the review row is far worse in AR', (
      WidgetTester tester,
    ) async {
      final List<String> ar = await _pumpScripted(
        tester,
        voiceRecordingScreenRecorded,
        locale: const Locale('ar'),
      );

      expect(ar, isNotEmpty);
      // 69 px in AR against 14 px in EN — the Arabic labels are longer, and the
      expect(ar.first, contains('69 pixels'));
    });

    // The control that makes the two tests above a fact about the PHONE box and
    testWidgets('the same state is clean at the harness default width', (
      WidgetTester tester,
    ) async {
      final List<String> wide = await _pumpScripted(
        tester,
        voiceRecordingScreenRecorded,
        box: const Size(800, 600),
      );

      expect(wide, isEmpty);
    });
  });
}
