// Shared dev-only fixtures for `VoiceRecordingScreen`.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_11_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/voice_request/presentation/voice_recording_screen.dart`.
//
// The catalog owned a private `_voiceCubit` / `_voiceCubitWithTicker` /
// `_seedRecorded` / `_seedSent`. Copying those into the preview section would
// have given the two surfaces two different scripts — and for this screen the
// designed state IS the script: every phase is reached by driving the real
// [VoiceRecordingCubit] through its public API, so a one-line difference in
// the seeding order lands the two surfaces on different phases while both
// still "work". Both surfaces now import this file.
//
// ## Why a script and not a seeded state
//
// [VoiceRecordingCubit] has no `seed:` constructor and `emit` is
// `@visibleForTesting`, so the only honest way to reach a phase from `lib/` is
// the lifecycle itself:
//
//   idle → startRecording() → recording → stopRecording() → recorded
//        → send() → sending → sent
//
// That is a feature, not a workaround: a fixture that emitted `recorded`
// directly could describe a state the cubit cannot actually produce (a clip
// shorter than [VoiceRecordingState.minSendableDuration], say, which
// `stopRecording` discards as a mis-tap). Every state below is one the app
// can really be in.
//
// ## Why the ticker is injected
//
// `startRecording()` subscribes to `tickerFactory(tickInterval)`, which
// defaults to a live `Stream.periodic` — a real 100 ms clock. Two consequences
// for a dev surface:
//
//   * elapsed time is whatever the wall clock happened to be, so "recorded"
//     would carry a different duration on every open, and
//   * a widget test that never closes the cubit is left with a pending timer.
//
// [voiceRecordingScreenCubitWithTicker] replaces it with a controller the
// caller drives by hand, which is what makes `00:03` mean 00:03. The catalog's
// idle/recording/blocked states deliberately keep the LIVE clock (they call
// [voiceRecordingScreenCubit], which does not override the factory) — a
// designer looking at the recording bar wants the timer to run.
//
// Everything here is network-free by construction: the shipped
// [FakeVoiceRecorder] / [FakeVoicePlayer] / [FakeVoiceRecordingRepository]
// are in-memory, and no code path reaches `HttpVoiceRecordingRepository` or
// the DI container. The `CatalogNetworkGuard` both hosts install is a net, not
// the plan.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_cubit.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_state.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';

/// An upload that is accepted and never lands.
///
/// `VoiceRecordingCubit.send()` emits `sending` and only leaves that phase when
/// the repository future settles, so a `Completer` that is never completed is
/// the only way to hold the screen on the in-flight surface long enough to look
/// at it. The shipped [FakeVoiceRecordingRepository] resolves in a microtask,
/// which means the `sending` frame is real but unobservable.
class VoiceRecordingScreenPendingRepository implements VoiceRecordingRepository {
  const VoiceRecordingScreenPendingRepository();

  @override
  Future<TranscriptionResult> upload(VoiceClip clip) =>
      Completer<TranscriptionResult>().future;
}

/// The cubit both dev surfaces drive, wired to the shipped in-memory fakes.
///
/// [startFailure] is thrown by the recorder on `start()` — the mic
/// pre-condition failures (permission denied, recorder held by another app)
/// that render the blocking surface rather than the idle mic.
///
/// [uploadFailure] is thrown by the repository on `upload()` — the submission
/// failures that keep the clip and render the persistent upload-error surface.
/// Ignored when an explicit [repository] is supplied.
///
/// [tickerFactory] is left at the cubit's own default when omitted, which is a
/// LIVE 100 ms clock. Pass one (or use [voiceRecordingScreenCubitWithTicker])
/// whenever the elapsed time has to be deterministic.
VoiceRecordingCubit voiceRecordingScreenCubit({
  VoiceRecorderFailure? startFailure,
  VoiceUploadFailure? uploadFailure,
  VoiceRecordingRepository? repository,
  VoiceRecordingTickerFactory? tickerFactory,
}) {
  final VoiceRecorder recorder = FakeVoiceRecorder(startFailure: startFailure);
  final VoicePlayer player = FakeVoicePlayer();
  final VoiceRecordingRepository uploads =
      repository ?? FakeVoiceRecordingRepository(failure: uploadFailure);
  // `VoiceRecordingCubit.tickerFactory` defaults to a private top-level
  // function, so "keep the default" has to be spelled as "do not pass it".
  if (tickerFactory == null) {
    return VoiceRecordingCubit(
      recorder: recorder,
      player: player,
      repository: uploads,
    );
  }
  return VoiceRecordingCubit(
    recorder: recorder,
    player: player,
    repository: uploads,
    tickerFactory: tickerFactory,
  );
}

/// The same cubit with its recording clock replaced by a controller the caller
/// drives, so elapsed time is chosen rather than measured.
///
/// Feed the returned `ticker` the elapsed duration you want the cubit to see
/// (`ticker.add(const Duration(seconds: 3))`), then let one microtask turn pass
/// before stopping — [voiceRecordingScreenSeedRecorded] does both.
({VoiceRecordingCubit cubit, StreamController<Duration> ticker})
voiceRecordingScreenCubitWithTicker({
  VoiceRecorderFailure? startFailure,
  VoiceUploadFailure? uploadFailure,
  VoiceRecordingRepository? repository,
}) {
  // A dev surface's cubit/controller pair lives for the duration of that
  // surface only (same as every other seeded cubit in the catalog); there is no
  // owner to hand a dispose hook to.
  // ignore: close_sinks
  final StreamController<Duration> controller =
      StreamController<Duration>.broadcast();
  return (
    cubit: voiceRecordingScreenCubit(
      startFailure: startFailure,
      uploadFailure: uploadFailure,
      repository: repository,
      tickerFactory: (_) => controller.stream,
    ),
    ticker: controller,
  );
}

/// Starts recording and pins the elapsed clock at [duration], leaving the
/// screen on the press-and-hold surface for as long as the host is open.
///
/// Nothing stops the recorder afterwards, which is the point: `recording` is
/// the phase a real user only ever holds for a second or two.
Future<void> voiceRecordingScreenSeedRecording(
  VoiceRecordingCubit cubit,
  StreamController<Duration> ticker, {
  Duration duration = const Duration(seconds: 7),
}) async {
  await cubit.startRecording();
  ticker.add(duration);
}

/// Records a clip of exactly [duration] and stops, landing on `recorded`.
///
/// The `await Future<void>.delayed(Duration.zero)` is load-bearing: a broadcast
/// stream delivers asynchronously, so without a turn between the tick and the
/// stop the cubit still reads `elapsed == 0`, treats the stop as a mis-tap
/// below [VoiceRecordingState.minSendableDuration], discards the clip and
/// bounces back to `idle` with `tooShort`.
///
/// [duration] must be >= 1s for the same reason, and < 60s — at the cap the
/// cubit stops itself (see [voiceRecordingScreenSeedDurationCeiling]).
Future<void> voiceRecordingScreenSeedRecorded(
  VoiceRecordingCubit cubit,
  StreamController<Duration> ticker, {
  Duration duration = const Duration(seconds: 3),
}) async {
  await cubit.startRecording();
  ticker.add(duration);
  await Future<void>.delayed(Duration.zero);
  await cubit.stopRecording();
}

/// Records [duration] and submits it — `sent` with the fake repository, or the
/// retained-clip upload-error surface when the cubit was built with an
/// `uploadFailure` / a failing [repository].
Future<void> voiceRecordingScreenSeedSent(
  VoiceRecordingCubit cubit,
  StreamController<Duration> ticker, {
  Duration duration = const Duration(seconds: 3),
}) async {
  await voiceRecordingScreenSeedRecorded(cubit, ticker, duration: duration);
  await cubit.send();
}

/// Holds the button past the 60-second cap and lets the cubit stop ITSELF.
///
/// Deliberately does not call `stopRecording()`: `_onRecordTick` sees
/// `elapsed >= VoiceRecordingState.maxDuration`, pins the timer at the cap and
/// auto-finalizes with [VoiceRecordingError.maxDurationReached]. Calling stop
/// as well would race that auto-stop and no-op. This is the only fixture that
/// leaves an error on a `recorded` state, and the error is a TRANSIENT one —
/// the screen answers it with a snackbar and then clears it.
Future<void> voiceRecordingScreenSeedDurationCeiling(
  VoiceRecordingCubit cubit,
  StreamController<Duration> ticker,
) =>
    voiceRecordingScreenSeedRecording(
      cubit,
      ticker,
      duration: VoiceRecordingState.maxDuration,
    );
