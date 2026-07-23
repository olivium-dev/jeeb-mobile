import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/voice_recording_repository.dart';
import '../domain/voice_clip.dart';
import '../domain/voice_player.dart';
import '../domain/voice_recorder.dart';
import 'voice_recording_state.dart';

/// Factory producing a 1-tick-per-period stream while the recording / playback
/// is in flight. Pulled out as a typedef so tests can inject a manual
/// [StreamController] and drive elapsed time deterministically.
typedef VoiceRecordingTickerFactory = Stream<Duration> Function(Duration step);

Stream<Duration> _defaultTickerFactory(Duration step) {
  return Stream<Duration>.periodic(step, (i) => step * (i + 1));
}

/// Drives the press-and-hold voice request flow (JEEB-60).
///
/// Lifecycle:
///   idle → (startRecording) → recording → (stopRecording) → recorded
///         → (togglePlayback) ↔ playing
///         → (send) → sending → sent  (terminal until [reset])
///         → (discardClip) → idle
///
/// The cubit owns the recording-elapsed timer and the playback-position timer
/// via the injected [VoiceRecordingTickerFactory] so views never have to drive
/// their own clocks. The same factory is used by the unit tests to step time
/// without `Future.delayed` waits.
class VoiceRecordingCubit extends Cubit<VoiceRecordingState> {
  VoiceRecordingCubit({
    required VoiceRecorder recorder,
    required VoicePlayer player,
    required VoiceRecordingRepository repository,
    VoiceRecordingTickerFactory tickerFactory = _defaultTickerFactory,
    Duration tickInterval = const Duration(milliseconds: 100),
  }) : _recorder = recorder,
       _player = player,
       _repository = repository,
       _tickerFactory = tickerFactory,
       _tickInterval = tickInterval,
       super(const VoiceRecordingState());

  final VoiceRecorder _recorder;
  final VoicePlayer _player;
  final VoiceRecordingRepository _repository;
  final VoiceRecordingTickerFactory _tickerFactory;
  final Duration _tickInterval;

  // Cleared in [_stopRecordTicker], which every terminal recording path calls
  // (stop, cancel, auto-stop at the duration cap, and the cubit's `close`).
  StreamSubscription<Duration>? _recordTickSub; // ignore: cancel_subscriptions

  Future<void> startRecording() async {
    if (state.phase != VoiceRecordingPhase.idle &&
        state.phase != VoiceRecordingPhase.sent) {
      return;
    }
    emit(const VoiceRecordingState());
    try {
      await _recorder.start();
    } on VoiceRecorderException catch (e) {
      emit(
        state.copyWith(
          phase: VoiceRecordingPhase.idle,
          error: _mapRecorderFailure(e.failure),
        ),
      );
      return;
    } catch (_) {
      emit(
        state.copyWith(
          phase: VoiceRecordingPhase.idle,
          error: VoiceRecordingError.recorderFailed,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        phase: VoiceRecordingPhase.recording,
        elapsed: Duration.zero,
        clearClip: true,
        clearError: true,
        clearResult: true,
      ),
    );
    _recordTickSub = _tickerFactory(_tickInterval).listen(_onRecordTick);
  }

  Future<void> stopRecording() async {
    if (state.phase != VoiceRecordingPhase.recording) return;
    final elapsed = state.elapsed;
    await _stopRecordTicker();
    if (elapsed < VoiceRecordingState.minSendableDuration) {
      // Mis-tap. Abort the recorder, discard, and surface the hint.
      try {
        await _recorder.cancel();
      } catch (_) {
        // Best-effort cleanup — don't mask the underlying too-short signal.
      }
      emit(
        state.copyWith(
          phase: VoiceRecordingPhase.idle,
          elapsed: Duration.zero,
          clearClip: true,
          error: VoiceRecordingError.tooShort,
        ),
      );
      return;
    }
    await _finalizeRecording(elapsed);
  }

  /// Discards an in-flight recording without raising the too-short error.
  /// Used by the explicit "cancel" gesture (swipe-to-cancel on the mic
  /// button).
  Future<void> cancelRecording() async {
    if (state.phase != VoiceRecordingPhase.recording) return;
    await _stopRecordTicker();
    try {
      await _recorder.cancel();
    } catch (_) {
      // Ignore — we're tearing down anyway.
    }
    emit(
      state.copyWith(
        phase: VoiceRecordingPhase.idle,
        elapsed: Duration.zero,
        clearClip: true,
        clearError: true,
      ),
    );
  }

  /// Drops the captured clip and returns to idle so the user can re-record.
  Future<void> discardClip() async {
    if (!state.hasClip && state.phase != VoiceRecordingPhase.playing) return;
    if (state.phase == VoiceRecordingPhase.playing) {
      await _player.stop();
    }
    emit(const VoiceRecordingState());
  }

  /// Toggles between playing and paused/recorded for the captured clip.
  Future<void> togglePlayback() async {
    if (state.phase == VoiceRecordingPhase.playing) {
      await _player.pause();
      emit(state.copyWith(phase: VoiceRecordingPhase.recorded));
      return;
    }
    if (state.phase != VoiceRecordingPhase.recorded) return;
    final clip = state.clip;
    if (clip == null) return;
    emit(
      state.copyWith(
        phase: VoiceRecordingPhase.playing,
        // If playback reached the end last time, restart from zero.
        playbackPosition: state.playbackPosition >= clip.duration
            ? Duration.zero
            : state.playbackPosition,
      ),
    );
    await _player.play(
      clip,
      onPosition: _onPlaybackPosition,
      onCompleted: _onPlaybackCompleted,
      startAt: state.playbackPosition,
    );
  }

  /// Moves the review playhead. While audio is playing the platform player is
  /// updated immediately; while paused the retained position is used as the
  /// starting point on the next [togglePlayback].
  Future<void> seekPlayback(Duration position) async {
    if (state.phase != VoiceRecordingPhase.recorded &&
        state.phase != VoiceRecordingPhase.playing) {
      return;
    }
    final clip = state.clip;
    if (clip == null) return;
    final clamped = position < Duration.zero
        ? Duration.zero
        : (position > clip.duration ? clip.duration : position);
    final wasPlaying = state.phase == VoiceRecordingPhase.playing;
    emit(state.copyWith(playbackPosition: clamped));
    if (wasPlaying) {
      await _player.seek(clamped);
    }
  }

  /// Submits the captured clip to the gateway. No-op if there is no clip or
  /// if the clip is below [VoiceRecordingState.minSendableDuration].
  Future<void> send() async {
    if (!state.canSend) return;
    if (state.phase == VoiceRecordingPhase.playing) {
      await _player.stop();
    }
    final clip = state.clip!;
    emit(state.copyWith(phase: VoiceRecordingPhase.sending, clearError: true));
    try {
      final result = await _repository.upload(clip);
      emit(state.copyWith(phase: VoiceRecordingPhase.sent, result: result));
    } on VoiceUploadException catch (e) {
      emit(
        state.copyWith(
          phase: VoiceRecordingPhase.recorded,
          error: _mapUploadFailure(e.failure),
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          phase: VoiceRecordingPhase.recorded,
          error: VoiceRecordingError.uploadUnknown,
        ),
      );
    }
  }

  void acknowledgeError() {
    if (state.error == null) return;
    emit(state.copyWith(clearError: true));
  }

  /// Resets state back to idle. Used by the screen after the user dismisses
  /// the "sent" confirmation and wants to record another request.
  Future<void> reset() async {
    await _stopRecordTicker();
    if (state.phase == VoiceRecordingPhase.playing) {
      await _player.stop();
    }
    emit(const VoiceRecordingState());
  }

  @override
  Future<void> close() async {
    await _stopRecordTicker();
    // Best-effort teardown — swallow errors so close() can't throw.
    try {
      await _recorder.cancel();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
    return super.close();
  }

  Future<void> _finalizeRecording(Duration elapsed) async {
    final cappedElapsed = elapsed > VoiceRecordingState.maxDuration
        ? VoiceRecordingState.maxDuration
        : elapsed;
    final hitCap = elapsed >= VoiceRecordingState.maxDuration;
    try {
      final VoiceClip clip = await _recorder.stop(
        recordedDuration: cappedElapsed,
      );
      emit(
        state.copyWith(
          phase: VoiceRecordingPhase.recorded,
          elapsed: cappedElapsed,
          clip: clip,
          playbackPosition: Duration.zero,
          error: hitCap ? VoiceRecordingError.maxDurationReached : null,
          clearError: !hitCap,
        ),
      );
    } on VoiceRecorderException catch (e) {
      emit(
        state.copyWith(
          phase: VoiceRecordingPhase.idle,
          elapsed: Duration.zero,
          clearClip: true,
          error: _mapRecorderFailure(e.failure),
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          phase: VoiceRecordingPhase.idle,
          elapsed: Duration.zero,
          clearClip: true,
          error: VoiceRecordingError.recorderFailed,
        ),
      );
    }
  }

  void _onRecordTick(Duration elapsed) {
    if (state.phase != VoiceRecordingPhase.recording) return;
    if (elapsed >= VoiceRecordingState.maxDuration) {
      // Auto-stop: emit one final elapsed at the cap and finalize.
      emit(state.copyWith(elapsed: VoiceRecordingState.maxDuration));
      unawaited(_autoStopAtCap());
      return;
    }
    emit(state.copyWith(elapsed: elapsed));
  }

  Future<void> _autoStopAtCap() async {
    await _stopRecordTicker();
    await _finalizeRecording(VoiceRecordingState.maxDuration);
  }

  Future<void> _stopRecordTicker() async {
    final sub = _recordTickSub;
    _recordTickSub = null;
    await sub?.cancel();
  }

  void _onPlaybackPosition(Duration position) {
    if (state.phase != VoiceRecordingPhase.playing) return;
    final clip = state.clip;
    if (clip == null) return;
    final clamped = position > clip.duration ? clip.duration : position;
    emit(state.copyWith(playbackPosition: clamped));
  }

  void _onPlaybackCompleted() {
    if (state.phase != VoiceRecordingPhase.playing) return;
    final clip = state.clip;
    emit(
      state.copyWith(
        phase: VoiceRecordingPhase.recorded,
        playbackPosition: clip?.duration ?? Duration.zero,
      ),
    );
  }

  VoiceRecordingError _mapRecorderFailure(VoiceRecorderFailure failure) {
    switch (failure) {
      case VoiceRecorderFailure.permissionDenied:
        return VoiceRecordingError.permissionDenied;
      case VoiceRecorderFailure.unavailable:
        return VoiceRecordingError.recorderUnavailable;
      case VoiceRecorderFailure.unknown:
        return VoiceRecordingError.recorderFailed;
    }
  }

  VoiceRecordingError _mapUploadFailure(VoiceUploadFailure failure) {
    switch (failure) {
      case VoiceUploadFailure.network:
        return VoiceRecordingError.uploadNetwork;
      case VoiceUploadFailure.server:
        return VoiceRecordingError.uploadServer;
      case VoiceUploadFailure.unknown:
        return VoiceRecordingError.uploadUnknown;
    }
  }
}
