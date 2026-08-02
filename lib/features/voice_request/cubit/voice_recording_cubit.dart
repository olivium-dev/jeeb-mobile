import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/voice_recording_repository.dart';
import '../domain/voice_clip.dart';
import '../domain/voice_player.dart';
import '../domain/voice_recorder.dart';
import 'voice_recording_state.dart';

typedef VoiceRecordingTickerFactory = Stream<Duration> Function(Duration step);

Stream<Duration> _defaultTickerFactory(Duration step) {
  return Stream<Duration>.periodic(step, (i) => step * (i + 1));
}

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

      try {
        await _recorder.cancel();
      } catch (_) {

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

  Future<void> cancelRecording() async {
    if (state.phase != VoiceRecordingPhase.recording) return;
    await _stopRecordTicker();
    try {
      await _recorder.cancel();
    } catch (_) {

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

  Future<void> discardClip() async {
    if (!state.hasClip && state.phase != VoiceRecordingPhase.playing) return;
    if (state.phase == VoiceRecordingPhase.playing) {
      await _player.stop();
    }
    emit(const VoiceRecordingState());
  }

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
