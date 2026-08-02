import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../cubit/voice_recording_cubit.dart';
import '../cubit/voice_recording_state.dart';
import '../data/voice_recording_repository.dart';
import '../domain/audioplayers_voice_player.dart';
import '../domain/record_voice_recorder.dart';
import '../domain/voice_player.dart';
import '../domain/voice_recorder.dart';
import 'widgets/animated_mic_button.dart';




class VoiceRecordingKeys {
  const VoiceRecordingKeys._();

  static const Key micButton = Key('voice_request_mic_button');
  static const Key blockedState = Key('voice_request_blocked_state');
  static const Key recordingWaveform = Key('voice_request_recording_waveform');
  static const Key cancelButton = Key('voice_request_cancel_button');
  static const Key playbackToggle = Key('voice_request_playback_toggle');
  static const Key playbackProgress = Key('voice_request_playback_progress');
  static const Key discardButton = Key('voice_request_discard_button');
  static const Key sendButton = Key('voice_request_send_button');
  static const Key uploadErrorState = Key('voice_request_upload_error_state');
  static const Key retryUploadButton = Key('voice_request_retry_upload_button');
  static const Key recordAnotherButton = Key(
    'voice_request_record_another_button',
  );
}






typedef VoiceSentCallback =
    void Function(
      String id,
      String? transcript, {
      String? localAudioPath,
      Duration duration,
    });










class VoiceRecordingScreen extends StatelessWidget {
  const VoiceRecordingScreen({super.key, this.cubit, this.onSent});

  
  
  final VoiceRecordingCubit? cubit;

  
  
  
  
  
  
  final VoiceSentCallback? onSent;

  @override
  Widget build(BuildContext context) {
    final view = _VoiceRecordingView(onSent: onSent);
    if (cubit != null) {
      return BlocProvider<VoiceRecordingCubit>.value(
        value: cubit!,
        child: view,
      );
    }
    return BlocProvider<VoiceRecordingCubit>(
      create: (_) => _buildProductionCubit(),
      child: view,
    );
  }

  
  
  
  
  
  VoiceRecordingCubit _buildProductionCubit() {
    final GetIt di = sl;
    final VoiceRecorder recorder = di.isRegistered<VoiceRecorder>()
        ? di<VoiceRecorder>()
        : RecordVoiceRecorder();
    final VoicePlayer player = di.isRegistered<VoicePlayer>()
        ? di<VoicePlayer>()
        : AudioPlayersVoicePlayer();
    final VoiceRecordingRepository repository =
        di.isRegistered<VoiceRecordingRepository>()
        ? di<VoiceRecordingRepository>()
        : HttpVoiceRecordingRepository(dio: resolveGatewayDio());
    return VoiceRecordingCubit(
      recorder: recorder,
      player: player,
      repository: repository,
    );
  }
}

class _VoiceRecordingView extends StatelessWidget {
  const _VoiceRecordingView({this.onSent});

  final VoiceSentCallback? onSent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(title: l10n.voiceRecordingTitle, centerTitle: false),
      body: SafeArea(
        child: BlocConsumer<VoiceRecordingCubit, VoiceRecordingState>(
          listenWhen: (prev, curr) =>
              prev.phase != curr.phase || prev.error != curr.error,
          listener: (context, state) {
            if (state.phase == VoiceRecordingPhase.sent &&
                state.result != null) {
              
              
              
              
              
              
              
              onSent?.call(
                state.result!.id,
                state.result!.transcript,
                localAudioPath: state.clip?.sourcePath,
                duration: state.clip?.duration ?? Duration.zero,
              );
            }
            final error = state.error;
            if (error != null && _isTransientError(error)) {
              
              
              
              ScaffoldMessenger.of(context).clearSnackBars();
              showOmdsErrorSnackbar(context, message: _errorCopy(l10n, error));
              context.read<VoiceRecordingCubit>().acknowledgeError();
            }
          },
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
              child: Column(
                children: [
                  const SizedBox(height: Spacing.large),
                  if (state.phase != VoiceRecordingPhase.sent) ...[
                    Text(
                      _isReviewPhase(state.phase)
                          ? l10n.voiceRecordingReviewTitle
                          : l10n.voiceRecordingSubtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: Spacing.large),
                  ],
                  _TimerLabel(state: state),
                  const Spacer(),
                  _PrimarySurface(state: state),
                  const Spacer(),
                  _ActionRow(state: state),
                  const SizedBox(height: Spacing.large),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TimerLabel extends StatelessWidget {
  const _TimerLabel({required this.state});
  final VoiceRecordingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final duration = state.isRecording
        ? state.elapsed
        : (state.clip?.duration ?? Duration.zero);
    final shouldShow =
        state.isRecording ||
        state.hasClip ||
        state.phase == VoiceRecordingPhase.sending;
    if (state.phase == VoiceRecordingPhase.sent) {
      return const SizedBox.shrink();
    }
    if (!shouldShow) {
      return Text(
        '00:00',
        style: textTheme.displaySmall?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }
    return Column(
      children: [
        Text(
          _formatDuration(duration),
          style: textTheme.displaySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.voiceRecordingTimerLabel(_formatDuration(duration)),
          style: textTheme.labelMedium,
        ),
      ],
    );
  }
}

class _PrimarySurface extends StatelessWidget {
  const _PrimarySurface({required this.state});
  final VoiceRecordingState state;

  @override
  Widget build(BuildContext context) {
    if (state.hasUploadFailure) {
      return _UploadFailureSurface(error: state.error!);
    }
    switch (state.phase) {
      case VoiceRecordingPhase.idle:
      case VoiceRecordingPhase.recording:
        return _MicSurface(state: state);
      case VoiceRecordingPhase.recorded:
      case VoiceRecordingPhase.playing:
      case VoiceRecordingPhase.sending:
        return _PlaybackPreview(state: state);
      case VoiceRecordingPhase.sent:
        return _SentConfirmation();
    }
  }
}



class _MicSurface extends StatelessWidget {
  const _MicSurface({required this.state});

  final VoiceRecordingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<VoiceRecordingCubit>();
    if (state.isRecording) {
      return _buildWaveformBar(context, cubit, l10n);
    }
    
    
    
    
    final error = state.error;
    if (error != null && _isBlockingError(error)) {
      return _BlockedSurface(error: error, onRetry: cubit.startRecording);
    }
    return _buildIdleMic(context, cubit, l10n);
  }

  Widget _buildWaveformBar(
    BuildContext context,
    VoiceRecordingCubit cubit,
    AppLocalizations l10n,
  ) {
    return Semantics(
      identifier: 'voice_request_recording_waveform',
      container: true,
      label: l10n.voiceRecordingReleaseToStop,
      child: OmdsRecordingInput(
        key: VoiceRecordingKeys.recordingWaveform,
        duration: state.elapsed,
        isRecording: true,
        onSend: cubit.stopRecording,
        onCancel: cubit.cancelRecording,
      ),
    );
  }

  Widget _buildIdleMic(
    BuildContext context,
    VoiceRecordingCubit cubit,
    AppLocalizations l10n,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        
        
        
        
        Semantics(
          identifier: 'voice_request_mic_button',
          container: true,
          child: AnimatedMicButton(
            key: VoiceRecordingKeys.micButton,
            isRecording: false,
            enabled: true,
            onPressStart: cubit.startRecording,
            onPressEnd: cubit.stopRecording,
            semanticLabel: l10n.voiceRecordingMicSemantic,
          ),
        ),
        const SizedBox(height: Spacing.medium),
        Text(
          l10n.voiceRecordingHoldToRecord,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}






class _BlockedSurface extends StatelessWidget {
  const _BlockedSurface({required this.error, required this.onRetry});

  final VoiceRecordingError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPermission = error == VoiceRecordingError.permissionDenied;
    return Semantics(
      identifier: 'voice_request_blocked_state',
      container: true,
      child: OmdsErrorState(
        key: VoiceRecordingKeys.blockedState,
        icon: Icons.mic_off_outlined,
        iconColor: Theme.of(context).colorScheme.primary,
        title: isPermission
            ? l10n.voiceRecordingPermissionTitle
            : l10n.voiceRecordingUnavailableTitle,
        message: isPermission
            ? l10n.voiceRecordingPermissionBody
            : l10n.voiceRecordingErrorUnavailable,
        retryLabel: l10n.voiceRecordingRetry,
        onRetry: onRetry,
      ),
    );
  }
}

class _PlaybackPreview extends StatelessWidget {
  const _PlaybackPreview({required this.state});
  final VoiceRecordingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<VoiceRecordingCubit>();
    final colorScheme = Theme.of(context).colorScheme;
    final clip = state.clip;
    final total = clip?.duration ?? Duration.zero;
    final position = state.playbackPosition;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'voice_request_playback_toggle',
          child: OmdsPrimaryButton(
            key: VoiceRecordingKeys.playbackToggle,
            text: state.isPlaying
                ? l10n.voiceRecordingPause
                : l10n.voiceRecordingPlay,
            icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
            variant: OmdsButtonVariant.secondary,
            onTap: state.isSending ? () {} : () => cubit.togglePlayback(),
            isEnabled: !state.isSending,
          ),
        ),
        const SizedBox(height: Spacing.small),
        Semantics(
          identifier: 'voice_request_playback_progress',
          container: true,
          value: '${(progress * 100).round()}%',
          child: IgnorePointer(
            ignoring: state.isSending,
            child: OmdsSeekBar(
              key: VoiceRecordingKeys.playbackProgress,
              duration: total,
              position: position,
              bufferedPosition: Duration.zero,
              onChangeEnd: cubit.seekPlayback,
              activeColor: colorScheme.primary,
              bufferedColor: colorScheme.primary,
              inactiveColor: colorScheme.onSurfaceVariant,
              thumbColor: colorScheme.primary,
              thumbRadius: 8,
              trackHeight: 4,
            ),
          ),
        ),
      ],
    );
  }
}

class _UploadFailureSurface extends StatelessWidget {
  const _UploadFailureSurface({required this.error});

  final VoiceRecordingError error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsErrorState(
      key: VoiceRecordingKeys.uploadErrorState,
      icon: Icons.cloud_upload_outlined,
      title: l10n.voiceRecordingUploadErrorTitle,
      message: _errorCopy(l10n, error),
      padding: const EdgeInsets.all(Spacing.medium),
    );
  }
}



class _SentConfirmation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSuccessIcon(colorScheme),
        const SizedBox(height: Spacing.medium),
        Text(l10n.voiceRecordingSentTitle, style: textTheme.titleLarge),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.voiceRecordingSentBody,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: Spacing.small),
        _BroadcastingBanner(l10n: l10n, colorScheme: colorScheme),
      ],
    );
  }

  Widget _buildSuccessIcon(ColorScheme colorScheme) {
    return Container(
      width: Sizes.tenXLarge,
      height: Sizes.tenXLarge,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.check_circle,
        size: Sizes.fiveXLarge,
        color: colorScheme.primary,
      ),
    );
  }
}



class _BroadcastingBanner extends StatelessWidget {
  const _BroadcastingBanner({required this.l10n, required this.colorScheme});

  final AppLocalizations l10n;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broadcast_on_personal,
            size: Sizes.large,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: Spacing.xSmall),
          Text(
            l10n.voiceRecordingBroadcastingHint,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.state});
  final VoiceRecordingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<VoiceRecordingCubit>();
    if (state.hasUploadFailure) {
      return _UploadFailureActions(cubit: cubit, l10n: l10n);
    }
    switch (state.phase) {
      case VoiceRecordingPhase.idle:
        return const SizedBox.shrink();
      case VoiceRecordingPhase.recording:
        return SizedBox(
          width: double.infinity,
          child: Semantics(
            identifier: 'voice_request_cancel_button',
            container: true,
            child: OMDSOutlinedButton(
              key: VoiceRecordingKeys.cancelButton,
              text: l10n.voiceRecordingCancel,
              onTap: () => cubit.cancelRecording(),
            ),
          ),
        );
      case VoiceRecordingPhase.recorded:
      case VoiceRecordingPhase.playing:
        return Row(
          children: [
            Expanded(
              child: Semantics(
                identifier: 'voice_request_discard_button',
                container: true,
                child: OMDSOutlinedButton(
                  key: VoiceRecordingKeys.discardButton,
                  text: l10n.voiceRecordingRecordAgain,
                  onTap: () => cubit.discardClip(),
                ),
              ),
            ),
            const SizedBox(width: Spacing.medium),
            Expanded(
              child: Semantics(
                identifier: 'voice_request_send_button',
                container: true,
                child: OmdsPrimaryButton(
                  key: VoiceRecordingKeys.sendButton,
                  text: l10n.voiceRecordingSubmit,
                  onTap: () => cubit.send(),
                  isEnabled: state.canSend,
                ),
              ),
            ),
          ],
        );
      case VoiceRecordingPhase.sending:
        return SizedBox(
          width: double.infinity,
          child: OmdsLoadingButton(
            text: l10n.voiceRecordingSending,
            isLoading: true,
            onTap: () {},
          ),
        );
      case VoiceRecordingPhase.sent:
        return SizedBox(
          width: double.infinity,
          child: Semantics(
            identifier: 'voice_request_record_another_button',
            container: true,
            child: OmdsPrimaryButton(
              key: VoiceRecordingKeys.recordAnotherButton,
              text: l10n.voiceRecordingRecordAnother,
              onTap: () => cubit.reset(),
            ),
          ),
        );
    }
  }
}

class _UploadFailureActions extends StatelessWidget {
  const _UploadFailureActions({required this.cubit, required this.l10n});

  final VoiceRecordingCubit cubit;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OMDSOutlinedButton(
            key: VoiceRecordingKeys.discardButton,
            text: l10n.voiceRecordingRecordAgain,
            onTap: () => cubit.discardClip(),
          ),
        ),
        const SizedBox(width: Spacing.medium),
        Expanded(
          child: Semantics(
            identifier: 'voice_request_retry_upload_button',
            child: OmdsPrimaryButton(
              key: VoiceRecordingKeys.retryUploadButton,
              text: l10n.voiceRecordingRetryUploadSubmit,
              onTap: () => cubit.send(),
            ),
          ),
        ),
      ],
    );
  }
}





bool _isBlockingError(VoiceRecordingError error) =>
    error == VoiceRecordingError.permissionDenied ||
    error == VoiceRecordingError.recorderUnavailable;

bool _isUploadError(VoiceRecordingError error) =>
    error == VoiceRecordingError.uploadNetwork ||
    error == VoiceRecordingError.uploadServer ||
    error == VoiceRecordingError.uploadUnknown;

bool _isTransientError(VoiceRecordingError error) =>
    !_isBlockingError(error) && !_isUploadError(error);

bool _isReviewPhase(VoiceRecordingPhase phase) =>
    phase == VoiceRecordingPhase.recorded ||
    phase == VoiceRecordingPhase.playing ||
    phase == VoiceRecordingPhase.sending;

String _errorCopy(AppLocalizations l10n, VoiceRecordingError error) {
  switch (error) {
    case VoiceRecordingError.permissionDenied:
      return l10n.voiceRecordingErrorPermission;
    case VoiceRecordingError.recorderUnavailable:
      return l10n.voiceRecordingErrorUnavailable;
    case VoiceRecordingError.recorderFailed:
      return l10n.voiceRecordingErrorRecorderFailed;
    case VoiceRecordingError.tooShort:
      return l10n.voiceRecordingErrorTooShort;
    case VoiceRecordingError.maxDurationReached:
      return l10n.voiceRecordingErrorMaxReached;
    case VoiceRecordingError.uploadNetwork:
      return l10n.voiceRecordingErrorUploadNetwork;
    case VoiceRecordingError.uploadServer:
      return l10n.voiceRecordingErrorUploadServer;
    case VoiceRecordingError.uploadUnknown:
      return l10n.voiceRecordingErrorUploadGeneric;
  }
}

String _formatDuration(Duration duration) {
  final clamped = duration.isNegative ? Duration.zero : duration;
  final minutes = clamped.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
