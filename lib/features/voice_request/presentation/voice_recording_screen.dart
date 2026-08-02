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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/voice_recording_screen_fixtures.dart';

/// Stable widget keys for the voice-request controls. Exposed so Codex QA /
/// integration tests can target the interactive elements deterministically
/// (T-MOB-011 DoD: every interactive widget has a Key / Semantics).
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

/// Signature of the sent handoff. Carries the gateway upload id, the optional
/// machine transcript, and (JEBV4-13) the recorder's on-device file path +
/// clip duration — the upload id is a gateway `audioId`, NOT a locally
/// playable path, so without [localAudioPath] the transcription review's
/// replay control had nothing real to play.
typedef VoiceSentCallback =
    void Function(
      String id,
      String? transcript, {
      String? localAudioPath,
      Duration duration,
    });

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
  const VoiceRecordingScreen({super.key, this.cubit, this.onSent});

  /// Optional injected cubit. Tests pass a pre-wired one; production builds a
  /// default with the in-memory recorder/player and HTTP repository.
  final VoiceRecordingCubit? cubit;

  /// Callback fired once the cubit transitions to `sent`. Receives the upload
  /// id and the optional machine [TranscriptionResult.transcript] so the
  /// downstream transcription-result screen can land on its happy path (it
  /// reads `clip.transcript`). The transcript is `null` when the gateway
  /// resolves it asynchronously; callers must tolerate null. Defaults to a
  /// no-op so the screen can also be used as a standalone surface.
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
              // Forward both the upload id AND the machine transcript so the
              // transcription-result screen lands on the happy path when the
              // gateway returned the transcript synchronously (T-MOB-011 →
              // T-MOB-TRANSCRIPT). `transcript` is null when resolved async.
              // JEBV4-13: also hand over the recorder's on-device file path +
              // duration — the id is a gateway audioId, not a playable path,
              // so the review screen's replay control needs the local file.
              onSent?.call(
                state.result!.id,
                state.result!.transcript,
                localAudioPath: state.clip?.sourcePath,
                duration: state.clip?.duration ?? Duration.zero,
              );
            }
            final error = state.error;
            if (error != null && _isTransientError(error)) {
              // Recording errors remain one-shot feedback. Upload errors are
              // deliberately excluded: the retained clip renders a persistent
              // OMDS error state with retry-submit and record-again actions.
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
    // Blocking pre-condition (mic permission denied / recorder unavailable):
    // render a recoverable, OMDS-consistent error surface instead of the idle
    // mic, so the user gets guidance + a retry rather than a silent no-op or a
    // transient snackbar dead-end.
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

/// Recoverable blocking state for the mic pre-conditions (permission denied /
/// recorder unavailable). Uses [OmdsErrorState] for fleet consistency and wires
/// "Try again" back to [VoiceRecordingCubit.startRecording], which re-requests
/// the OS permission / re-checks the recorder. Honest: no backend call, no
/// dead-end — the user can always retry from here once they grant access.
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

/// Errors that block recording until the user acts (grants mic permission, or
/// frees the recorder). These persist on screen as a recoverable
/// [OmdsErrorState] instead of a transient snackbar so the user is never left
/// in a dead-end tap-deny-tap loop.
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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/voice_request/voice_recording_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, and three things follow from that.
//
// 1. It owns its own `Scaffold` (OMDSAppBar + body) and [jeebPreviewHost] wraps
//    every child in one as well, so the canvas shows two nested Scaffolds. The
//    inner one is the real surface; the outer contributes a background and the
//    `ScaffoldMessenger` the transient-error snackbar needs. The canvas box is
//    therefore a real phone ([_voiceRecordingScreenPhoneBox], 390x844) rather
//    than the harness's 390x200 default — the body is a `Column` with two
//    `Spacer`s, so in a short box it is nothing but overflow.
//
// 2. It needs no `Router`. Every edge off this screen is the `onSent` callback,
//    which the previews leave null, so there is nothing here that reaches for
//    GoRouter — unlike `WalletHubScreen`, which needs a local one to be
//    tappable.
//
// 3. Every preview is wrapped in `TickerMode(enabled: false)`. Three things on
//    this screen animate forever: the `OmdsRecordingInput` waveform + pulsing
//    dot (`repeat(reverse: true)`), the `AnimatedMicButton` halo, and the
//    `CircularProgressIndicator` inside the sending button. `pumpAndSettle` —
//    which the shared render harness calls on every preview — never returns
//    while any of them is live. Muting freezes each at t=0, so what is
//    reviewable here is the recording POSE, not the motion. The snackbar in
//    `Ceiling · 60 second cap` is NOT muted: `ScaffoldMessenger` lives above
//    the mute in the host, which is why that one preview needs its own group
//    in the render test.
//
// ## How the states are reached
//
// [VoiceRecordingCubit] has no `seed:` constructor, so no preview can hand it a
// designed [VoiceRecordingState]. Each state below is instead SCRIPTED through
// the cubit's public lifecycle (`startRecording` → tick → `stopRecording` →
// `send`) against the shipped in-memory fakes, with the recording clock
// replaced by a controller the fixture drives. Those scripts are shared
// verbatim with the Screen Catalog entry —
// `lib/devtool/catalog/fixtures/voice_recording_screen_fixtures.dart` — so the
// designer's five states and the nine here cannot describe different screens.
// No preview builds a `HttpVoiceRecordingRepository`, a `RecordVoiceRecorder`
// or an `AudioPlayersVoicePlayer`, and `_buildProductionCubit` is never
// reached: network- and platform-free by construction rather than by the guard
// in [jeebPreviewHost].
//
// The scripts run as detached futures against a cubit the screen already
// holds, so the first frame of a preview can be `idle` and the settled frame
// `recorded`. That is deliberate — it is the same transition production makes.
//
// Every clip length is DISTINCT (3s / 7s / 12s / 25s / 60s) because the timer
// label is the only text several of these states do not otherwise share, and
// the render test pins it.
//
// ## What these previews surfaced in the screen — see the notes on each
//
//  * `Sending · upload in flight` renders NO text at all. The screen passes
//    `text: l10n.voiceRecordingSending` ("Sending…") to `OmdsLoadingButton`,
//    but that widget's `AnimatedSwitcher` shows the text ONLY when
//    `isLoading == false` — with `isLoading: true` the string is replaced by a
//    20dp spinner and never reaches the tree. The one phase where the user is
//    waiting on the network is also the one with no words and no semantics
//    label on the control.
//  * the timer label reads "00:12 recorded" WHILE the clip is uploading, and
//    "01:00 recorded" the instant the 60s cap trips. `voiceRecordingTimerLabel`
//    is past-tense copy used for three different phases.
//  * `Blocked · mic permission denied` still renders the "00:00" timer above
//    the error state, and `Upload failed · network` still renders the clip's
//    duration above an error that says the upload failed. `_TimerLabel` is
//    outside the `_PrimarySurface` switch, so it survives every error surface.
//  * `Ceiling · 60 second cap` is the one state that pairs a persistent surface
//    with a transient one: the review screen appears AND a red snackbar
//    explains why recording stopped. Read it at 200% text — the snackbar is
//    floating, so it overlays the Submit/Record-again row it is telling you
//    about.
//  * The review surface's action row OVERFLOWS at the declared 390 pt box, at
//    100% text, in both locales — 14 px in EN and 69 px in AR. It is an
//    `Expanded` + `Expanded` `Row`, but each button lays its own label out as
//    the lone non-flex child of an inner `Row`, so the labels are measured
//    against an unbounded width and neither wraps nor ellipsizes. Every state
//    that reaches the review surface carries it: `Recorded`, `Upload failed`
//    and `Ceiling`. It is clean at 800 pt, which is the width the shared render
//    harness used to pump at — which is exactly why it went unnoticed until
//    these previews declared a phone-sized box.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _voiceRecordingScreenPhoneBox = Size(390, 844);

/// Elapsed clock the `Recording` preview freezes at — long enough that the
/// waveform bar's own send button is past `minDurationToSend`, short of the cap.
const Duration _voiceRecordingScreenRecordingElapsed = Duration(seconds: 7);

/// Clip length the `Sending` preview captures. Distinct from every other
/// preview's so "00:12 recorded" identifies this state and no other.
const Duration _voiceRecordingScreenSendingClip = Duration(seconds: 12);

/// Clip length the `Upload failed` preview captures — long enough to read as a
/// real request the user would be annoyed to lose.
const Duration _voiceRecordingScreenFailedClip = Duration(seconds: 25);

/// A script run against the cubit the previewed screen is holding.
typedef _VoiceRecordingScreenScript =
    Future<void> Function(
      VoiceRecordingCubit cubit,
      StreamController<Duration> ticker,
    );

/// Builds the screen on a scripted cubit, with every ticker on the screen muted.
///
/// [startFailure] fails the recorder's `start()` (the mic pre-conditions);
/// [uploadFailure] fails the repository's `upload()`; [repository] overrides
/// the upload seam outright (the never-lands fake). All three are the fixture
/// file's parameters, unchanged — this only wires them to a widget.
Widget _voiceRecordingScreenAfter(
  _VoiceRecordingScreenScript script, {
  VoiceRecorderFailure? startFailure,
  VoiceUploadFailure? uploadFailure,
  VoiceRecordingRepository? repository,
}) {
  final (:cubit, :ticker) = voiceRecordingScreenCubitWithTicker(
    startFailure: startFailure,
    uploadFailure: uploadFailure,
    repository: repository,
  );
  // Detached on purpose: a preview function must return a Widget synchronously.
  // The screen is handed the cubit now and re-renders as the script advances it.
  unawaited(script(cubit, ticker));
  return TickerMode(
    enabled: false,
    child: VoiceRecordingScreen(cubit: cubit),
  );
}

/// The first frame of every entry into the flow: no clip, no error, a greyed
/// `00:00` and the 132dp mic.
///
/// This is the screen's empty state, and it is worth noticing how little it
/// says: "Hold to record" under the mic and nothing about the 60-second cap,
/// the 1-second floor, or what happens after you let go.
@JeebPreview(
  group: 'voice_request',
  name: 'Idle · nothing recorded',
  size: _voiceRecordingScreenPhoneBox,
)
Widget voiceRecordingScreenIdle() =>
    _voiceRecordingScreenAfter((_, _) async {});

/// Finger down, 7 seconds in: the mic is replaced by `OmdsRecordingInput` — a
/// pulsing dot, a waveform, its OWN timer, its OWN send button and its OWN
/// cancel button — with the screen's `Cancel` button below it.
///
/// Frozen at t=0 of the pulse (see the section note). Two things to read here:
/// the elapsed time is now on screen THREE times (the bar's `00:07`, the
/// display `00:07` and the "00:07 recorded" label), and the surface offers two
/// different ways to abandon the recording — the bar's ✕ and the full-width
/// `Cancel` — which are the same `cancelRecording()` call.
@JeebPreview(
  group: 'voice_request',
  name: 'Recording · waveform bar',
  size: _voiceRecordingScreenPhoneBox,
)
Widget voiceRecordingScreenRecording() => _voiceRecordingScreenAfter(
      (VoiceRecordingCubit cubit, StreamController<Duration> ticker) =>
          voiceRecordingScreenSeedRecording(
            cubit,
            ticker,
            duration: _voiceRecordingScreenRecordingElapsed,
          ),
    );

/// The review surface after a 3-second clip: play/pause, a seek rail, and the
/// `Record again` / `Submit` pair.
///
/// Matrixed because this is the RTL-sensitive layout on the screen. The action
/// row is an `Expanded` + `Expanded` `Row`, so **AR RTL dark** is where
/// `Record again` and `Submit` swap sides — and `Submit` is the destructive-
/// adjacent one — while the seek rail's filled portion has to mirror with them.
/// The **EN 200% text** card is where a two-word label and a one-word label
/// stop fitting the same half-width button.
@JeebPreview(
  group: 'voice_request',
  name: 'Recorded · ready to submit',
  size: _voiceRecordingScreenPhoneBox,
  matrix: true,
)
Widget voiceRecordingScreenRecorded() =>
    _voiceRecordingScreenAfter(voiceRecordingScreenSeedRecorded);

/// The upload in flight, held open by a repository read that never lands.
///
/// The state that surprised this file: the button says nothing. The screen
/// passes "Sending…" to `OmdsLoadingButton`, whose `AnimatedSwitcher` renders
/// the text only in the NOT-loading branch, so with `isLoading: true` it draws
/// a 20dp spinner and drops the string. Above it the review copy and the
/// playback controls are still on screen, greyed via `isEnabled: false` and an
/// `IgnorePointer` — but the timer still reads "00:12 recorded", past tense,
/// while the clip is mid-flight.
@JeebPreview(
  group: 'voice_request',
  name: 'Sending · upload in flight',
  size: _voiceRecordingScreenPhoneBox,
)
Widget voiceRecordingScreenSending() => _voiceRecordingScreenAfter(
      (VoiceRecordingCubit cubit, StreamController<Duration> ticker) =>
          voiceRecordingScreenSeedSent(
            cubit,
            ticker,
            duration: _voiceRecordingScreenSendingClip,
          ),
      repository: const VoiceRecordingScreenPendingRepository(),
    );

/// The terminal happy path (T-MOB-011 AC3): the check-circle, "Sent", the
/// body copy and the "Looking for Jeebers…" broadcasting chip, with `Record
/// another` as the only action.
///
/// Note what disappears: the timer is gone entirely (`_TimerLabel` returns
/// `SizedBox.shrink()` in `sent`), so the confirmation never tells the user how
/// long the request they just sent actually was.
@JeebPreview(
  group: 'voice_request',
  name: 'Sent · broadcasting',
  size: _voiceRecordingScreenPhoneBox,
)
Widget voiceRecordingScreenSent() =>
    _voiceRecordingScreenAfter(voiceRecordingScreenSeedSent);

/// `POST /transcribe` failed on the network. The clip is RETAINED and the
/// failure is persistent — an `OmdsErrorState` plus `Record again` /
/// `Retry upload & submit`, never a snackbar.
///
/// Matrixed because this carries the longest copy on the screen
/// ("Couldn't reach the server. Check your connection and try again.") under
/// the longest button label ("Retry upload & submit") in a two-`Expanded` Row.
/// The **EN 200% text** card is the one to look at: the error state, the
/// stranded `00:25` timer above it and the two buttons all compete for a
/// fixed-height `Column` with two `Spacer`s.
@JeebPreview(
  group: 'voice_request',
  name: 'Upload failed · network',
  size: _voiceRecordingScreenPhoneBox,
  matrix: true,
)
Widget voiceRecordingScreenUploadFailed() => _voiceRecordingScreenAfter(
      (VoiceRecordingCubit cubit, StreamController<Duration> ticker) =>
          voiceRecordingScreenSeedSent(
            cubit,
            ticker,
            duration: _voiceRecordingScreenFailedClip,
          ),
      uploadFailure: VoiceUploadFailure.network,
    );

/// The mic pre-condition failure a real user hits most: permission denied.
///
/// Sprint-6 Stream-B replaced a transient snackbar with this recoverable
/// surface — "Microphone access needed", the settings guidance and a
/// `Try again` that re-requests the OS permission — so there is no
/// tap-deny-tap dead-end. `test/voice_recording_blocked_state_test.dart` pins
/// the behaviour; this is the picture of it.
///
/// Look at the top of the card: the greyed `00:00` timer is still there, above
/// an error state saying recording is impossible.
@JeebPreview(
  group: 'voice_request',
  name: 'Blocked · mic permission denied',
  size: _voiceRecordingScreenPhoneBox,
)
Widget voiceRecordingScreenPermissionDenied() => _voiceRecordingScreenAfter(
      (VoiceRecordingCubit cubit, _) => cubit.startRecording(),
      startFailure: VoiceRecorderFailure.permissionDenied,
    );

/// The other blocking pre-condition: the recorder itself is unavailable
/// (another app holds the mic, or the platform recorder failed to initialise).
///
/// Same surface, different copy — "Microphone unavailable" — and the same
/// `Try again`. Worth previewing next to the permission card precisely because
/// they are near-identical: the only thing distinguishing "grant us access" from
/// "close your other app" is one title and one body line.
@JeebPreview(
  group: 'voice_request',
  name: 'Blocked · recorder unavailable',
  size: _voiceRecordingScreenPhoneBox,
)
Widget voiceRecordingScreenRecorderUnavailable() => _voiceRecordingScreenAfter(
      (VoiceRecordingCubit cubit, _) => cubit.startRecording(),
      startFailure: VoiceRecorderFailure.unavailable,
    );

/// The longest clip the screen can ever hold: the 60-second cap, tripped under
/// a still-held finger.
///
/// Reached the way production reaches it — the ticker crosses
/// `VoiceRecordingState.maxDuration`, `_onRecordTick` pins the timer at the cap
/// and `_autoStopAtCap()` finalises the clip WITHOUT the user releasing. The
/// result is the review surface carrying `01:00` (the only two-field timer this
/// screen renders) plus a transient `maxDurationReached` error, which the
/// listener answers with a red snackbar and then clears.
///
/// This is the only preview whose snackbar is live — `ScaffoldMessenger` sits
/// above the `TickerMode` mute — so it is also the only one the shared render
/// harness cannot settle. See the dedicated group in the render test.
@JeebPreview(
  group: 'voice_request',
  name: 'Ceiling · 60 second cap',
  size: _voiceRecordingScreenPhoneBox,
)
Widget voiceRecordingScreenDurationCeiling() =>
    _voiceRecordingScreenAfter(voiceRecordingScreenSeedDurationCeiling);
