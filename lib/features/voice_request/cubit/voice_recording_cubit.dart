import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/voice_recording_repository.dart';
import '../domain/voice_clip.dart';
import '../domain/voice_player.dart';
import '../domain/voice_recorder.dart';
import 'voice_recording_state.dart';

typedef VoiceRecordingTickerFactory = Stream<Duration> Function(Duration step);
typedef VoicePollingDelay = Future<void> Function(Duration duration);

Stream<Duration> _defaultTickerFactory(Duration step) {
  return Stream<Duration>.periodic(step, (i) => step * (i + 1));
}

Future<void> _defaultPollingDelay(Duration duration) =>
    Future.delayed(duration);

class VoiceRecordingCubit extends Cubit<VoiceRecordingState> {
  VoiceRecordingCubit({
    required VoiceRecorder recorder,
    required VoicePlayer player,
    required VoiceRecordingRepository repository,
    VoiceRecordingTickerFactory tickerFactory = _defaultTickerFactory,
    Duration tickInterval = const Duration(milliseconds: 100),
    VoicePollingDelay pollingDelay = _defaultPollingDelay,
    Duration pollingTimeout = const Duration(seconds: 45),
    Duration initialPollingInterval = const Duration(seconds: 1),
    Duration maxPollingInterval = const Duration(seconds: 5),
    VoiceRecordingState initialState = const VoiceRecordingState(),
  }) : _recorder = recorder,
       _player = player,
       _repository = repository,
       _tickerFactory = tickerFactory,
       _tickInterval = tickInterval,
       _pollingDelay = pollingDelay,
       _pollingTimeout = pollingTimeout,
       _initialPollingInterval = initialPollingInterval,
       _maxPollingInterval = maxPollingInterval,
       assert(pollingTimeout > Duration.zero),
       assert(initialPollingInterval > Duration.zero),
       assert(maxPollingInterval >= initialPollingInterval),
       super(initialState);

  final VoiceRecorder _recorder;
  final VoicePlayer _player;
  final VoiceRecordingRepository _repository;
  final VoiceRecordingTickerFactory _tickerFactory;
  final Duration _tickInterval;
  final VoicePollingDelay _pollingDelay;
  final Duration _pollingTimeout;
  final Duration _initialPollingInterval;
  final Duration _maxPollingInterval;

  StreamSubscription<Duration>? _recordTickSub; // ignore: cancel_subscriptions
  int _sendGeneration = 0;

  Future<void> startRecording() async {
    if (state.phase != VoiceRecordingPhase.idle &&
        state.phase != VoiceRecordingPhase.sent) {
      return;
    }
    _cancelPendingSend();
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
      } catch (_) {}
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
    } catch (_) {}
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
    _cancelPendingSend();
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
    if (!state.canSend || state.phase == VoiceRecordingPhase.sending) return;
    if (state.phase == VoiceRecordingPhase.playing) {
      await _player.stop();
    }
    final clip = state.clip!;
    final sendGeneration = ++_sendGeneration;
    emit(state.copyWith(phase: VoiceRecordingPhase.sending, clearError: true));
    try {
      final uploaded = await _repository.upload(clip);
      final result = await _awaitTerminalTranscription(
        uploaded,
        sendGeneration: sendGeneration,
      );
      if (!_isCurrentSend(sendGeneration)) return;
      emit(state.copyWith(phase: VoiceRecordingPhase.sent, result: result));
    } on VoiceUploadException catch (e) {
      if (!_isCurrentSend(sendGeneration)) return;
      emit(
        state.copyWith(
          phase: VoiceRecordingPhase.recorded,
          error: _mapUploadFailure(e.failure),
        ),
      );
    } catch (_) {
      if (!_isCurrentSend(sendGeneration)) return;
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
    _cancelPendingSend();
    await _stopRecordTicker();
    if (state.phase == VoiceRecordingPhase.playing) {
      await _player.stop();
    }
    emit(const VoiceRecordingState());
  }

  @override
  Future<void> close() async {
    _cancelPendingSend();
    await _stopRecordTicker();

    try {
      await _recorder.cancel();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
    return super.close();
  }

  Future<TranscriptionResult> _awaitTerminalTranscription(
    TranscriptionResult initial, {
    required int sendGeneration,
  }) async {
    if (!_isQueued(initial.status)) return initial;
    final statusRepository = switch (_repository) {
      final VoiceTranscriptionStatusRepository repository => repository,
      _ => null,
    };
    if (statusRepository == null) return initial;

    var elapsed = Duration.zero;
    var delay = _initialPollingInterval;
    while (elapsed < _pollingTimeout) {
      final remaining = _pollingTimeout - elapsed;
      final boundedDelay = delay > remaining ? remaining : delay;
      await _pollingDelay(boundedDelay);
      elapsed += boundedDelay;
      if (!_isCurrentSend(sendGeneration)) return initial;

      final current = await statusRepository.getTranscriptionStatus(initial.id);
      if (!_isCurrentSend(sendGeneration)) return initial;
      final status = current.status?.trim().toLowerCase();
      if (status == 'completed' || status == 'transcribed') {
        return current;
      }
      if (status == 'failed') {
        throw const VoiceUploadException(VoiceUploadFailure.server);
      }
      if (status != 'queued' && status != 'processing') {
        throw const VoiceUploadException(VoiceUploadFailure.unknown);
      }
      delay = _doubleBounded(delay, _maxPollingInterval);
    }
    // A queue that outlived the poll budget is a timeout, not an outage.
    throw const VoiceUploadException(VoiceUploadFailure.timeout);
  }

  bool _isCurrentSend(int generation) =>
      !isClosed && generation == _sendGeneration;

  static bool _isQueued(String? status) {
    final normalized = status?.trim().toLowerCase();
    return normalized == 'queued' || normalized == 'processing';
  }

  static Duration _doubleBounded(Duration value, Duration maximum) {
    final doubled = value * 2;
    return doubled > maximum ? maximum : doubled;
  }

  void _cancelPendingSend() {
    _sendGeneration++;
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
      case VoiceUploadFailure.timeout:
        return VoiceRecordingError.uploadTimeout;
      case VoiceUploadFailure.tooLarge:
        return VoiceRecordingError.uploadTooLarge;
      case VoiceUploadFailure.unsupportedFormat:
        return VoiceRecordingError.uploadUnsupported;
      case VoiceUploadFailure.unavailable:
        return VoiceRecordingError.uploadUnavailable;
    }
  }
}
