// Render tests for the VoiceRecordingScreen previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand.
//
// Every state pins a DISTINCT string, and on this screen that has to mean a
// distinct SURFACE. All nine previews are the same widget behind the same app
// bar, differing only in how far a script has driven the cubit down its own
// lifecycle (`startRecording` → tick → `stopRecording` → `send`), and the
// timer label survives almost every phase — so a suite pinned on "00:12
// recorded" passes while the screen is still showing the press-and-hold
// waveform. Each state below is pinned on copy that only its own surface
// renders, with the clip length as a second, corroborating signal.
//
// ## Why the scripted states are not in the shared harness
//
// [testPreviewsRender] drives every preview with `pumpAndSettle`, which is
// enough for the four states reached WITHOUT `stopRecording` — idle, recording
// and the two blocked pre-conditions. It is not enough for the other five.
//
// `VoiceRecordingCubit.stopRecording` awaits `_stopRecordTicker()`, which
// awaits `StreamSubscription.cancel()` on the injected ticker. Under
// `AutomatedTestWidgetsFlutterBinding` that future does not complete no matter
// how far the fake clock is advanced — it is not a timer, so `pump()` cannot
// fire it, and it is not a microtask the binding flushes either. Verified
// against every `StreamController` shape (broadcast, single-subscription,
// `sync: true`, explicit `onCancel`) and against `Stream.multi`: all behave the
// same. The preview's detached script therefore parks inside `stopRecording`
// forever, and the screen stays on the recording surface.
//
// [_pumpScripted] drives those five through `tester.runAsync`, where timers and
// subscription cancellations are REAL, which is the documented escape hatch for
// exactly this. Nothing about the previews is adjusted to suit the test: this is
// a property of the fake-async binding, and the canvas — which runs a real event
// loop — reaches these states without help.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/voice_request/presentation/voice_recording_screen.dart';

import '../preview_test_harness.dart';

/// The box every preview in this file declares
/// (`_voiceRecordingScreenPhoneBox`). The shared harness pumps at the
/// `flutter_test` default of 800x600 instead — which is both shorter and much
/// WIDER than any phone, and the width is why the review-row overflow below
/// went unnoticed.
const Size _phoneBox = Size(390, 844);

/// Pumps a scripted preview to its designed state and returns any overflows.
///
/// Two things are load-bearing:
///
///  * the pump happens INSIDE `runAsync`, so the detached script's
///    `stopRecording` → `subscription.cancel()` can actually complete (see the
///    header), and
///  * `FlutterError.onError` is intercepted rather than left to
///    `takeException`, because the review surface overflows at 390 pt and a
///    pending exception would fail every state test for a reason each of them
///    is not about.
/// The widget tree is pumped on the FAKE clock and only the script's own awaits
/// are drained on the real one — alternating, because the two are interleaved:
///
///  * `pump(10ms)` advances the fake clock, which is what fires the
///    `Future.delayed(Duration.zero)` the seeding fixtures put between the tick
///    and the stop, and what drives every widget animation; while
///  * `runAsync` gives the real event loop a turn, which is the only thing that
///    completes the `subscription.cancel()` inside `stopRecording`.
///
/// Doing the `pumpWidget` itself inside `runAsync` also reaches these states,
/// but then `ScaffoldMessenger` starts its snackbar animation against the real
/// clock and the cap state's snackbar never lands in the tree. Pumping the tree
/// on the fake clock throughout is what keeps both halves of that state
/// observable.
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
  // deepest at four awaits); bounded rather than `pumpAndSettle` because the
  // cap state's snackbar is a live animation that would never settle.
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
  // enough. The other five are driven below — see the header.
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
      // states render too.
      'Idle · nothing recorded': 'Hold to record',
      // 7s is this preview's alone, and the recording surface is the only one
      // carrying the screen-level `Cancel`.
      'Recording · waveform bar': '00:07 recorded',
      // The two blocked surfaces are near-identical by design; the title is the
      // one line separating "grant us access" from "close your other app".
      'Blocked · mic permission denied': 'Microphone access needed',
      'Blocked · recorder unavailable': 'Microphone unavailable',
    },
  );

  group('VoiceRecordingScreen previews · scripted past stopRecording', () {
    // Each of these asserts the SURFACE, not just the clock. Before this suite
    // existed all five rendered the press-and-hold waveform in tests while
    // claiming to be the review / sending / sent / error states, and a pin on
    // the timer string passed anyway.

    testWidgets('Recorded · ready to submit renders the review surface', (
      WidgetTester tester,
    ) async {
      await _pumpScripted(tester, voiceRecordingScreenRecorded);

      expect(find.text('Review your recording'), findsOneWidget);
      expect(find.text('00:03 recorded'), findsOneWidget);
      // Playback and the two-action row — none of which the recording surface
      // has, and all of which this preview exists to show.
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
      // that drops the recording on the floor.
      expect(find.text('00:25 recorded'), findsOneWidget);
      expect(find.text('Retry upload & submit'), findsOneWidget);
      expect(find.text('Record again'), findsOneWidget);
    });

    testWidgets('Ceiling · 60 second cap renders review + snackbar together', (
      WidgetTester tester,
    ) async {
      await _pumpScripted(tester, voiceRecordingScreenDurationCeiling);

      // The persistent half: the cubit auto-finalised the clip at the cap
      // WITHOUT the user releasing, so the review surface is up and the clip
      // survived at exactly the cap.
      expect(find.text('Review your recording'), findsOneWidget);
      // `01:00` is the only two-field timer this screen can render.
      expect(find.text('01:00 recorded'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
      // The transient half, and the only reason the user knows why recording
      // stopped by itself.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('Recording stopped — 60 second maximum.'),
        findsOneWidget,
      );
    });

    // Arabic, for the five states the shared harness cannot reach. Pinned on
    // the clip lengths, which are locale-invariant, plus the phase-defining
    // widget where there is one.
    testWidgets('the scripted states reach their own surface in AR too', (
      WidgetTester tester,
    ) async {
      await _pumpScripted(
        tester,
        voiceRecordingScreenSent,
        locale: const Locale('ar'),
      );

      // `sent` is the one surface with no timer at all, so finding no
      // Latin-digit clock is itself the assertion that the script arrived.
      expect(find.textContaining('00:'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('VoiceRecordingScreen preview specifics', () {
    // Each state gets its OWN test: every preview here is the same widget tree
    // differing only in the script, so pumping a second preview into the same
    // tester would reuse the first preview's element.

    // The finding. The screen passes `text: l10n.voiceRecordingSending`
    // ("Sending…") to `OmdsLoadingButton`, but that widget's `AnimatedSwitcher`
    // renders the label only on the NOT-loading branch — with `isLoading: true`
    // it draws a 20dp spinner and the string never reaches the tree. The one
    // phase where the user is waiting on the network is the one with no words.
    //
    // If this starts failing because "Sending…" IS found, the button has been
    // fixed: delete this test and the matching bullet in the JEEB PREVIEWS
    // section of
    // `lib/features/voice_request/presentation/voice_recording_screen.dart`.
    testWidgets('KNOWN DEFECT: the in-flight button renders no label at all', (
      WidgetTester tester,
    ) async {
      await _pumpScripted(tester, voiceRecordingScreenSending);

      expect(find.text('Sending…'), findsNothing);
      // Not a failed render — the screen is very much on the sending phase, it
      // just says so with a spinner and nothing else.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // The finding. `voiceRecordingTimerLabel` is past-tense copy
    // ("{duration} recorded") reused for three different phases, so the screen
    // claims the clip is "recorded" while it is still on the wire, and again
    // the instant the 60s cap trips.
    testWidgets('the timer reads past-tense while the clip is still uploading',
        (WidgetTester tester) async {
      await _pumpScripted(tester, voiceRecordingScreenSending);

      expect(find.text('00:12 recorded'), findsOneWidget);
    });

    // The finding. `_TimerLabel` sits OUTSIDE the `_PrimarySurface` switch, so
    // it survives every error surface: a blocked mic renders a `00:00` clock
    // above an error saying recording is impossible.
    testWidgets('a blocked mic still renders a 00:00 timer above the error', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, voiceRecordingScreenPermissionDenied);

      expect(find.text('Microphone access needed'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      // The recoverable surface Sprint-6 Stream-B put in place of the old
      // snackbar — the reason this is not a tap-deny-tap dead end.
      expect(find.text('Try again'), findsOneWidget);
    });

    // The same defect on the other side: a failed upload strands the clip's
    // real duration above an error about the upload.
    testWidgets('a failed upload strands the clip duration above the error', (
      WidgetTester tester,
    ) async {
      await _pumpScripted(tester, voiceRecordingScreenUploadFailed);

      expect(find.text("Couldn't submit your recording"), findsOneWidget);
      expect(find.text('00:25 recorded'), findsOneWidget);
    });

    // The finding. `_TimerLabel` returns `SizedBox.shrink()` on `sent`, so the
    // confirmation never tells the user how long the request they just sent
    // was — the one screen where that number would be worth keeping.
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
    // that they are actually DIFFERENT previews and not the same fixture twice
    // — the whole reason both are in the canvas.
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
    // bar's own timer, the big display clock and the past-tense label — which
    // is the observation the preview's doc comment makes. Pinned so a redesign
    // that removes one has to come past this test.
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
    // it is how little it says: no mention of the 60-second cap or the
    // one-second floor, both of which the cubit enforces.
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
    // surface's action row is `Expanded` + `SizedBox(width: Spacing.medium)` +
    // `Expanded`, and the buttons inside lay their labels out as the lone
    // non-flex child of their own `Row` — measured against an UNBOUNDED width,
    // so they never wrap or ellipsize. At 390 pt the pair runs 14 px past the
    // screen in EN and 69 px in AR, at 100% text, on the ordinary phone box the
    // preview declares.
    //
    // It is clean at the harness's 800 pt default, which is exactly why nothing
    // caught it before: every one of these states was only ever pumped at a
    // width no phone has.
    //
    // If these start coming back EMPTY the row has been given a wrap or an
    // ellipsis — delete this test and strike the note from the JEEB PREVIEWS
    // section of the screen.
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
      // row has no way to give them room.
      expect(ar.first, contains('69 pixels'));
    });

    // The control that makes the two tests above a fact about the PHONE box and
    // not about this setup: the same state, the same script, at the harness's
    // 800 pt default — clean.
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
