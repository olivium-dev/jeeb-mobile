// Shared dev-only fixtures for `VoiceRecordingScreen`.

import 'dart:async';

import 'dart:typed_data';

import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_cubit.dart';
import 'package:jeeb_mobile/features/voice_request/cubit/voice_recording_state.dart';
import 'package:jeeb_mobile/features/voice_request/data/voice_recording_repository.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_player.dart';
import 'package:jeeb_mobile/features/voice_request/domain/voice_recorder.dart';

/// An upload that is accepted and never lands.
/// `VoiceRecordingCubit.send()` emits `sending` and only leaves that phase when
/// the repository future settles, so a `Completer` that is never completed is
class VoiceRecordingScreenPendingRepository implements VoiceRecordingRepository {
  const VoiceRecordingScreenPendingRepository();

  @override
  Future<TranscriptionResult> upload(VoiceClip clip) =>
      Completer<TranscriptionResult>().future;
}

/// An upload that fails with a specific classified kind — the four AE-15
/// buckets (413 / 415 / 503 / receive-timeout) the screen must tell apart.
class VoiceRecordingScreenFailingRepository implements VoiceRecordingRepository {
  const VoiceRecordingScreenFailingRepository(this.failure);

  /// 413 — the clip is larger than the gateway accepts. Terminal.
  const VoiceRecordingScreenFailingRepository.tooLarge()
      : failure = VoiceUploadFailure.tooLarge;

  /// 415 — the container/codec is refused. Terminal.
  const VoiceRecordingScreenFailingRepository.unsupportedFormat()
      : failure = VoiceUploadFailure.unsupportedFormat;

  /// 503 — transcription is down; retrying later can win.
  const VoiceRecordingScreenFailingRepository.unavailable()
      : failure = VoiceUploadFailure.unavailable;

  /// The transcribe call or its poll budget ran out.
  const VoiceRecordingScreenFailingRepository.timeout()
      : failure = VoiceUploadFailure.timeout;

  final VoiceUploadFailure failure;

  @override
  Future<TranscriptionResult> upload(VoiceClip clip) async =>
      throw VoiceUploadException(failure);
}

/// The cubit both dev surfaces drive, wired to the shipped in-memory fakes.
/// [startFailure] is thrown by the recorder on `start()` — the mic
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

/// A cubit that STARTS in [state] — the seeds below drive the real cubit and
/// stall inside `flutter test`'s fake-async on `StreamSubscription.cancel()`,
/// which left the `recorded` and `sent` captures rendering the `recording`
/// surface instead. Live surfaces still use the async seeds.
VoiceRecordingCubit voiceRecordingScreenSeededCubit(VoiceRecordingState state) =>
    VoiceRecordingCubit(
      recorder: FakeVoiceRecorder(),
      player: FakeVoicePlayer(),
      repository: FakeVoiceRecordingRepository(),
      tickerFactory: (_) => const Stream<Duration>.empty(),
      initialState: state,
    );

/// A 3-second clip with real bytes, for the seeded states above.
VoiceClip voiceRecordingScreenClip({
  Duration duration = const Duration(seconds: 3),
}) => VoiceClip(
  bytes: Uint8List.fromList(List<int>.filled(2048, 0x55)),
  duration: duration,
  sourcePath: '/tmp/voice-catalog-clip.m4a',
);

/// The same cubit with its recording clock replaced by a controller the caller
/// drives, so elapsed time is chosen rather than measured.
({VoiceRecordingCubit cubit, StreamController<Duration> ticker})
voiceRecordingScreenCubitWithTicker({
  VoiceRecorderFailure? startFailure,
  VoiceUploadFailure? uploadFailure,
  VoiceRecordingRepository? repository,
}) {
  // A dev surface's cubit/controller pair lives for the duration of that
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
Future<void> voiceRecordingScreenSeedRecording(
  VoiceRecordingCubit cubit,
  StreamController<Duration> ticker, {
  Duration duration = const Duration(seconds: 7),
}) async {
  await cubit.startRecording();
  ticker.add(duration);
}

/// Records a clip of exactly [duration] and stops, landing on `recorded`.
/// The `await Future<void>.delayed(Duration.zero)` is load-bearing: a broadcast
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
Future<void> voiceRecordingScreenSeedSent(
  VoiceRecordingCubit cubit,
  StreamController<Duration> ticker, {
  Duration duration = const Duration(seconds: 3),
}) async {
  await voiceRecordingScreenSeedRecorded(cubit, ticker, duration: duration);
  await cubit.send();
}

/// Holds the button past the 60-second cap and lets the cubit stop ITSELF.
/// Deliberately does not call `stopRecording()`: `_onRecordTick` sees
Future<void> voiceRecordingScreenSeedDurationCeiling(
  VoiceRecordingCubit cubit,
  StreamController<Duration> ticker,
) =>
    voiceRecordingScreenSeedRecording(
      cubit,
      ticker,
      duration: VoiceRecordingState.maxDuration,
    );
