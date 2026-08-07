import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_radii.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_shadows.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_navy_surface_card.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../cubit/voice_recording_cubit.dart';
import '../cubit/voice_recording_state.dart';
import '../data/voice_recording_repository.dart';
import '../domain/audioplayers_voice_player.dart';
import '../domain/record_voice_recorder.dart';
import '../domain/voice_player.dart';
import '../domain/voice_recorder.dart';
import 'voice_recording_error_policy.dart';
import 'widgets/live_transcript_band.dart';
import 'widgets/mic_cluster.dart';
import 'widgets/mic_field_rings.dart';
import 'widgets/recording_readout.dart';

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
  const VoiceRecordingScreen({
    super.key,
    this.cubit,
    this.onSent,
    this.onSwitchToTyping,
  });

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

  /// Hands off to typed input from the keyboard satellite. Null hides the
  /// satellite entirely — the screen stays router-agnostic and each mounting
  /// route decides where "type instead" goes.
  final VoidCallback? onSwitchToTyping;

  @override
  Widget build(BuildContext context) {
    final view = _VoiceRecordingView(
      onSent: onSent,
      onSwitchToTyping: onSwitchToTyping,
    );
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
  const _VoiceRecordingView({this.onSent, this.onSwitchToTyping});

  final VoiceSentCallback? onSent;
  final VoidCallback? onSwitchToTyping;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      // The field is the background; the tile draws one orange glow on the
      // floor under the mic and no orbit arcs, wash or twinkles. The alpha is
      // the §8 hero step, not content's .22 — "the whole floor glows orange
      // under the mic" is this tile's caption, and the mic IS the light source.
      body: JeebMidnightField(
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.bottom,
        glowColor: context.jeebRoles.accent.withValues(alpha: _kFloorGlowAlpha),
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
            if (error != null && isTransientVoiceError(error)) {
              // Recording errors remain one-shot feedback. Upload errors are
              // deliberately excluded: the retained clip renders a persistent
              // OMDS error state with retry-submit and record-again actions.
              ScaffoldMessenger.of(context).clearSnackBars();
              showOmdsErrorSnackbar(
                context,
                message: voiceErrorCopy(l10n, error),
              );
              context.read<VoiceRecordingCubit>().acknowledgeError();
            }
          },
          builder: (context, state) {
            // The board docks the composer at the thumb and leaves the space
            // above it to the transcript band. Only the two designed phases get
            // that treatment; the undesigned ones stay centred as before.
            final bool docked = _isDockedPhase(state);
            return Semantics(
              identifier: 'voice_request_root',
              container: true,
              explicitChildNodes: true,
              child: Stack(
                children: [
                  if (docked) const Positioned.fill(child: MicFieldRings()),
                  SafeArea(
                    child: Column(
                      children: [
                        JeebTopBar.back(
                          title: l10n.voiceRecordingNewRequestTitle,
                          identifier: 'voice_request_back',
                          onLeadingPressed: () =>
                              Navigator.of(context).maybePop(),
                        ),
                        if (docked)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              Spacing.xLarge,
                              Spacing.xSmall,
                              Spacing.xLarge,
                              0,
                            ),
                            child: LiveTranscriptBand(
                              isRecording: state.isRecording,
                            ),
                          ),
                        Expanded(
                          child: _PhaseBody(
                            state: state,
                            docked: docked,
                            onSwitchToTyping: onSwitchToTyping,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The scrolling half of the screen: composer docked at the thumb when there is
/// room, scrollable when a 200% text scale takes more than the viewport — the
/// `Spacer` layout this replaces overflowed by 8px in Arabic at 200%.
class _PhaseBody extends StatelessWidget {
  const _PhaseBody({
    required this.state,
    required this.docked,
    this.onSwitchToTyping,
  });

  final VoiceRecordingState state;
  final bool docked;
  final VoidCallback? onSwitchToTyping;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.xLarge,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: docked
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.center,
              children: [
                _PhaseSurface(
                  state: state,
                  onSwitchToTyping: onSwitchToTyping,
                ),
                SizedBox(height: docked ? Spacing.twoXSmall : Spacing.large),
                _ActionRow(state: state),
                const SizedBox(height: Spacing.medium),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PhaseSurface extends StatelessWidget {
  const _PhaseSurface({required this.state, this.onSwitchToTyping});

  final VoiceRecordingState state;
  final VoidCallback? onSwitchToTyping;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VoiceRecordingCubit>();
    if (state.hasUploadFailure) {
      return _UploadFailureSurface(error: state.error!);
    }
    switch (state.phase) {
      case VoiceRecordingPhase.idle:
      case VoiceRecordingPhase.recording:
        if (_isBlocked(state)) {
          return _BlockedSurface(
            error: state.error!,
            onRetry: cubit.startRecording,
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RecordingReadout(
              state: state,
              waveformKey: VoiceRecordingKeys.recordingWaveform,
            ),
            const SizedBox(height: Spacing.xSmall),
            MicCluster(
              micKey: VoiceRecordingKeys.micButton,
              cancelKey: VoiceRecordingKeys.cancelButton,
              isRecording: state.isRecording,
              progress: state.isRecording ? _elapsedFraction(state) : null,
              onPressStart: cubit.startRecording,
              onPressEnd: cubit.stopRecording,
              onCancel: cubit.cancelRecording,
              onSwitchToTyping: onSwitchToTyping,
            ),
          ],
        );
      case VoiceRecordingPhase.recorded:
      case VoiceRecordingPhase.playing:
      case VoiceRecordingPhase.sending:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context).voiceRecordingReviewTitle,
              textAlign: TextAlign.center,
              style: context.jeebText.h2.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: Spacing.large),
            _PlaybackPreview(state: state),
          ],
        );
      case VoiceRecordingPhase.sent:
        return _SentConfirmation();
    }
  }
}

/// Recoverable blocking state for the mic pre-conditions (permission denied /
/// recorder unavailable), on the §2.7 empty-state family in its danger-tinted
/// `error` status. "Try again" goes back to
/// [VoiceRecordingCubit.startRecording], which re-requests the OS permission /
/// re-checks the recorder — no backend call, no dead-end.
class _BlockedSurface extends StatelessWidget {
  const _BlockedSurface({required this.error, required this.onRetry});

  final VoiceRecordingError error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPermission = error == VoiceRecordingError.permissionDenied;
    return JeebEmptyState(
      key: VoiceRecordingKeys.blockedState,
      identifier: 'voice_request_blocked_state',
      status: JeebEmptyStateStatus.error,
      illustrationSize: _kStateIllustrationSize,
      padding: EdgeInsets.zero,
      headline: isPermission
          ? l10n.voiceRecordingPermissionTitle
          : l10n.voiceRecordingUnavailableTitle,
      body: isPermission
          ? l10n.voiceRecordingPermissionBody
          : l10n.voiceRecordingErrorUnavailable,
      action: JeebCtaButton.primary(
        label: l10n.voiceRecordingRetry,
        onTap: onRetry,
        identifier: 'voice_request_retry_button',
      ),
    );
  }
}

/// The replay control, on a rest-glass card — the board never draws 05's
/// review, so it borrows R1's card recipe rather than inventing a surface.
class _PlaybackPreview extends StatelessWidget {
  const _PlaybackPreview({required this.state});
  final VoiceRecordingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<VoiceRecordingCubit>();
    final colorScheme = Theme.of(context).colorScheme;
    final semantics = _semanticColors(context);
    final clip = state.clip;
    final total = clip?.duration ?? Duration.zero;
    final position = state.playbackPosition;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
    return JeebGlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            identifier: 'voice_request_playback_toggle',
            child: JeebCtaButton.outline(
              key: VoiceRecordingKeys.playbackToggle,
              label: state.isPlaying
                  ? l10n.voiceRecordingPause
                  : l10n.voiceRecordingPlay,
              leadingIcon: state.isPlaying ? Icons.pause : Icons.play_arrow,
              onTap: state.isSending ? null : () => cubit.togglePlayback(),
              isEnabled: !state.isSending,
              expand: true,
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
                // A scrub track is chrome, not live state, so it spends no
                // accent; three ink rungs keep played/buffered/unplayed apart
                // while every one of them clears 3:1 on the navy.
                activeColor: colorScheme.onSurface,
                bufferedColor: semantics.inkSoft,
                inactiveColor: colorScheme.onSurfaceVariant,
                thumbColor: colorScheme.onSurface,
                thumbRadius: 8,
                trackHeight: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadFailureSurface extends StatelessWidget {
  const _UploadFailureSurface({required this.error});

  final VoiceRecordingError error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebEmptyState(
      key: VoiceRecordingKeys.uploadErrorState,
      identifier: 'voice_request_upload_error_state',
      status: JeebEmptyStateStatus.error,
      illustrationSize: _kStateIllustrationSize,
      padding: EdgeInsets.zero,
      headline: l10n.voiceRecordingUploadErrorTitle,
      body: voiceErrorCopy(l10n, error),
    );
  }
}

/// Shown after the send ack returns. Per T-MOB-011 AC3 the send button is
/// disabled and this confirmation surfaces the "Broadcasting" sub-line.
class _SentConfirmation extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final text = context.jeebText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SuccessDisc(),
        const SizedBox(height: Spacing.large),
        Text(
          l10n.voiceRecordingSentTitle,
          textAlign: TextAlign.center,
          style: text.h1.copyWith(color: scheme.onSurface),
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.voiceRecordingSentBody,
          textAlign: TextAlign.center,
          style: text.body.copyWith(color: _semanticColors(context).mutedText),
        ),
        const SizedBox(height: Spacing.medium),
        const _BroadcastingChip(),
      ],
    );
  }
}

/// The success mark. Green, not orange: §4.1's budget spends orange on the mic
/// and the live accents, and a confirmation is neither.
class _SuccessDisc extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final JeebRoles roles = context.jeebRoles;
    return SizedBox.square(
      dimension: Sizes.eightXLarge,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: roles.successContainer,
        ),
        child: Icon(
          Icons.check_rounded,
          size: Sizes.threeXLarge,
          color: roles.success,
        ),
      ),
    );
  }
}

/// The "Broadcasting" line under the sent confirmation — R1's chip recipe:
/// solid navy pill, orange live dot, orange label. Static, like R1's own.
class _BroadcastingChip extends StatelessWidget {
  const _BroadcastingChip();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final JeebRoles roles = context.jeebRoles;
    return JeebNavySurfaceCard(
      radius: JeebRadii.pill,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: Sizes.xSmall,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: roles.accent,
                boxShadow: JeebShadows.glowDot,
              ),
            ),
          ),
          const SizedBox(width: Spacing.xSmall),
          Text(
            l10n.voiceRecordingBroadcastingHint,
            style: context.jeebText.bodySmall.copyWith(color: roles.accent),
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
      case VoiceRecordingPhase.recording:
        // Blocked pre-conditions replace the cluster, so its caption goes too.
        if (_isBlocked(state)) return const SizedBox.shrink();
        return Text(
          l10n.voiceRecordingHoldToRecord,
          textAlign: TextAlign.center,
          style: context.jeebText.bodySmall.copyWith(
            color: _semanticColors(context).mutedText,
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
                child: JeebCtaButton.outline(
                  key: VoiceRecordingKeys.discardButton,
                  label: l10n.voiceRecordingRecordAgain,
                  onTap: () => cubit.discardClip(),
                  expand: true,
                ),
              ),
            ),
            const SizedBox(width: Spacing.medium),
            Expanded(
              child: Semantics(
                identifier: 'voice_request_send_button',
                container: true,
                child: JeebCtaButton.primary(
                  key: VoiceRecordingKeys.sendButton,
                  label: l10n.voiceRecordingSubmit,
                  onTap: () => cubit.send(),
                  isEnabled: state.canSend,
                  expand: true,
                ),
              ),
            ),
          ],
        );
      case VoiceRecordingPhase.sending:
        return JeebCtaButton.primary(
          label: l10n.voiceRecordingSending,
          isLoading: true,
          expand: true,
        );
      case VoiceRecordingPhase.sent:
        return Semantics(
          identifier: 'voice_request_record_another_button',
          container: true,
          child: JeebCtaButton.primary(
            key: VoiceRecordingKeys.recordAnotherButton,
            label: l10n.voiceRecordingRecordAnother,
            onTap: () => cubit.reset(),
            expand: true,
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
          child: JeebCtaButton.outline(
            key: VoiceRecordingKeys.discardButton,
            label: l10n.voiceRecordingRecordAgain,
            onTap: () => cubit.discardClip(),
            expand: true,
          ),
        ),
        const SizedBox(width: Spacing.medium),
        Expanded(
          child: Semantics(
            identifier: 'voice_request_retry_upload_button',
            child: JeebCtaButton.primary(
              key: VoiceRecordingKeys.retryUploadButton,
              label: l10n.voiceRecordingRetryUploadSubmit,
              onTap: () => cubit.send(),
              expand: true,
            ),
          ),
        ),
      ],
    );
  }
}

/// Whether the mic pre-conditions are failing, i.e. the composer is replaced by
/// a recoverable error surface.
bool _isBlocked(VoiceRecordingState state) {
  if (state.isRecording || state.hasUploadFailure) return false;
  final error = state.error;
  return error != null && isBlockingVoiceError(error);
}

/// The two phases the board actually draws — composer docked at the thumb with
/// real emptiness above it. Everything else stays vertically centred.
bool _isDockedPhase(VoiceRecordingState state) =>
    !state.hasUploadFailure &&
    !_isBlocked(state) &&
    (state.phase == VoiceRecordingPhase.idle || state.isRecording);

double _elapsedFraction(VoiceRecordingState state) =>
    (state.elapsed.inMilliseconds /
            VoiceRecordingState.maxDuration.inMilliseconds)
        .clamp(0.0, 1.0);

/// The §2.7 illustration scaled to what is left once the top bar and the action
/// row have their room — the kit's own 300 overflows a 360×640 viewport here.
const double _kStateIllustrationSize = 208;

/// Token sheet §8's hero glow step. See the field call site.
const double _kFloorGlowAlpha = 0.40;

JeebSemanticColors _semanticColors(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();
