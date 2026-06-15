import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/network/mock_gateway_client.dart';
import '../../../l10n/app_localizations.dart';
import '../cubit/voice_recording_cubit.dart';
import '../cubit/voice_recording_state.dart';
import '../data/voice_recording_repository.dart';
import '../domain/audioplayers_voice_player.dart';
import '../domain/record_voice_recorder.dart';
import '../domain/voice_player.dart';
import '../domain/voice_recorder.dart';
import 'widgets/animated_mic_button.dart';

/// Stable widget keys for the voice-request controls. Exposed so Codex QA /
/// integration tests can target the interactive elements deterministically
/// (T-MOB-011 DoD: every interactive widget has a Key / Semantics).
class VoiceRecordingKeys {
  const VoiceRecordingKeys._();

  static const Key micButton = Key('voice_request_mic_button');
  static const Key recordingWaveform = Key('voice_request_recording_waveform');
  static const Key cancelButton = Key('voice_request_cancel_button');
  static const Key playbackToggle = Key('voice_request_playback_toggle');
  static const Key playbackProgress = Key('voice_request_playback_progress');
  static const Key discardButton = Key('voice_request_discard_button');
  static const Key sendButton = Key('voice_request_send_button');
  static const Key recordAnotherButton =
      Key('voice_request_record_another_button');
}

/// Screen that lets the user record a voice request, preview it, and send it
/// to the gateway (JEEB-60 / T-mobile-007).
///
/// The screen hosts a [VoiceRecordingCubit] and wires the press-and-hold mic
/// button, recording timer, playback row, discard/send actions, and the
/// post-send confirmation. Production callers route here via `/voice-request`
/// (see `lib/core/router/app_router.dart`); tests inject a pre-wired cubit
/// via the [cubit] parameter so they can drive state transitions without the
/// real platform recorder.
class VoiceRecordingScreen extends StatelessWidget {
  const VoiceRecordingScreen({
    super.key,
    this.cubit,
    this.onSent,
  });

  /// Optional injected cubit. Tests pass a pre-wired one; production builds a
  /// default with the in-memory recorder/player and HTTP repository.
  final VoiceRecordingCubit? cubit;

  /// Callback fired once the cubit transitions to `sent`. Defaults to a
  /// no-op so the screen can also be used as a standalone surface.
  final ValueChanged<String>? onSent;

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

  /// Builds the cubit for the real app, resolving the platform recorder, player,
  /// and upload repository from the DI container (T-MOB-011). Falls back to a
  /// directly-constructed graph if GetIt has not been configured (e.g. a
  /// standalone preview), so the screen never hard-crashes on a missing
  /// registration.
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
            : HttpVoiceRecordingRepository(dio: MockGatewayClient.createDio());
    return VoiceRecordingCubit(
      recorder: recorder,
      player: player,
      repository: repository,
    );
  }
}

class _VoiceRecordingView extends StatelessWidget {
  const _VoiceRecordingView({this.onSent});

  final ValueChanged<String>? onSent;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.voiceRecordingTitle,
        centerTitle: false,
      ),
      body: SafeArea(
        child: BlocConsumer<VoiceRecordingCubit, VoiceRecordingState>(
          listenWhen: (prev, curr) =>
              prev.phase != curr.phase || prev.error != curr.error,
          listener: (context, state) {
            if (state.phase == VoiceRecordingPhase.sent &&
                state.result != null) {
              onSent?.call(state.result!.id);
            }
            final error = state.error;
            if (error != null) {
              // EXEMPT: OMDS does not export a standalone snackbar/toast
              // widget; ScaffoldMessenger.showSnackBar is the approved
              // fleet pattern for transient error feedback (T-MOB-011).
              ScaffoldMessenger.of(context)
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(
                    content: Text(_errorCopy(l10n, error)),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              context.read<VoiceRecordingCubit>().acknowledgeError();
            }
          },
          builder: (context, state) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
              child: Column(
                children: [
                  const SizedBox(height: Spacing.large),
                  Text(
                    l10n.voiceRecordingSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Spacing.large),
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
    final shouldShow = state.isRecording ||
        state.hasClip ||
        state.phase == VoiceRecordingPhase.sending;
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

/// Mic surface: shows [OmdsRecordingInput] with waveform while recording (AC1)
/// and [AnimatedMicButton] when idle.
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
        // Semantics(identifier:) surfaces as the Android resource-id so
        // uiautomator/Maestro can target the mic. The inner AnimatedMicButton
        // owns the `button:true` + spoken label; container:true keeps this an
        // addressable, merged node carrying the id (D2 / VoiceRecordingKeys).
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.medium,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: OmdsBorderRadius.medium,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Semantics(
                identifier: 'voice_request_playback_toggle',
                button: true,
                label: state.isPlaying
                    ? l10n.voiceRecordingPause
                    : l10n.voiceRecordingPlay,
                child: IconButton.filled(
                  key: VoiceRecordingKeys.playbackToggle,
                  iconSize: 40,
                  onPressed:
                      state.isSending ? null : () => cubit.togglePlayback(),
                  icon: Icon(
                    state.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.medium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      identifier: 'voice_request_playback_progress',
                      container: true,
                      value: '${(progress * 100).round()}%',
                      child: ClipRRect(
                        borderRadius: OmdsBorderRadius.twoXSmall,
                        child: LinearProgressIndicator(
                          key: VoiceRecordingKeys.playbackProgress,
                          value: progress,
                          minHeight: 6,
                          backgroundColor:
                              colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.xSmall),
                    Text(
                      '${_formatDuration(position)} / '
                      '${_formatDuration(total)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown after the send ack returns. Per T-MOB-011 AC3 the send button is
/// disabled and this confirmation surfaces the "Broadcasting" sub-line.
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

/// Sub-line shown below the sent confirmation, indicating the request is being
/// broadcast to nearby Jeebers (SM-1 Broadcasting phase, T-MOB-011 AC3).
class _BroadcastingBanner extends StatelessWidget {
  const _BroadcastingBanner({
    required this.l10n,
    required this.colorScheme,
  });

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
              child: OMDSOutlinedButton(
                key: VoiceRecordingKeys.discardButton,
                text: l10n.voiceRecordingDiscard,
                onTap: () => cubit.discardClip(),
              ),
            ),
            const SizedBox(width: Spacing.medium),
            Expanded(
              child: Semantics(
                identifier: 'voice_request_send_button',
                container: true,
                child: OmdsPrimaryButton(
                  key: VoiceRecordingKeys.sendButton,
                  text: l10n.voiceRecordingSend,
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

String _formatDuration(Duration duration) {
  final clamped = duration.isNegative ? Duration.zero : duration;
  final minutes = clamped.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
