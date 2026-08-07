import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../voice_request/cubit/voice_recording_cubit.dart';
import '../../../voice_request/cubit/voice_recording_state.dart';
import '../../../voice_request/presentation/voice_recording_error_policy.dart';
import '../../../voice_request/presentation/widgets/recording_readout.dart';
import '../../../voice_request/presentation/widgets/recording_waveform.dart';

/// The status surface for recording in place on the client home screen — the
/// live timer, and every state the floating mic cannot express on its own.
class ClientHomeVoiceDock extends StatelessWidget {
  const ClientHomeVoiceDock({
    super.key,
    required this.bottom,
    required this.slideProgress,
    required this.handsFree,
    required this.tierBlocked,
    this.tierRetrying = false,
    this.onRetryUpload,
    this.onDiscard,
    this.onRetryBlocked,
    this.onDismissBlocked,
    this.onTypeInstead,
    this.onRetryTier,
    this.onDismissTier,
  });

  /// Above this effective body size the decorative waveform is dropped; the
  /// slide-to-cancel instruction is functional and is never dropped with it.
  static const double _waveformHideThreshold = 20;

  /// The timer is a hero numeral; an unclamped 200% system scale would push the
  /// strip past the card on a 360dp phone.
  static const double _timerMaxTextScale = 1.5;

  final double bottom;

  /// 0..1 slide-to-cancel travel the floating mic writes while it is held.
  final ValueListenable<double> slideProgress;

  /// True while the recording runs with no finger on the glass. Slide and
  /// release both need a pointer that is not there, so the hint has to change.
  final ValueListenable<bool> handsFree;

  /// True once a clip is ready but no delivery tier could be resolved.
  final bool tierBlocked;

  /// True while a tier retry is in flight.
  final bool tierRetrying;

  final VoidCallback? onRetryUpload;
  final VoidCallback? onDiscard;
  final VoidCallback? onRetryBlocked;
  final VoidCallback? onDismissBlocked;
  final VoidCallback? onTypeInstead;
  final VoidCallback? onRetryTier;
  final VoidCallback? onDismissTier;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: Spacing.xLarge,
      end: Spacing.xLarge,
      bottom: bottom,
      // The cubit ticks at 10Hz for a whole minute; without this the timer
      // re-records the route's layer, list viewport and header glass included.
      child: RepaintBoundary(
        child: BlocBuilder<VoiceRecordingCubit, VoiceRecordingState>(
          builder: (context, state) {
            final Widget? content = _content(context, state);
            if (content == null) return const SizedBox.shrink();
            return Semantics(
              identifier: 'client_home_voice_status',
              container: true,
              explicitChildNodes: true,
              child: JeebGlassCard(child: content),
            );
          },
        ),
      ),
    );
  }

  Widget? _content(BuildContext context, VoiceRecordingState state) {
    final l10n = AppLocalizations.of(context);
    final error = state.error;
    if (error != null && isBlockingVoiceError(error)) {
      return _blocked(context, l10n, error);
    }
    if (state.hasUploadFailure) return _uploadFailure(context, l10n, state);
    if (tierBlocked) return _tierBlocked(context, l10n);
    if (state.isSending) {
      return JeebCtaButton.primary(
        label: l10n.voiceRecordingSending,
        isLoading: true,
        expand: true,
      );
    }
    if (state.isRecording) return _recording(context, l10n, state);
    return null;
  }

  Widget _blocked(
    BuildContext context,
    AppLocalizations l10n,
    VoiceRecordingError error,
  ) {
    final isPermission = error == VoiceRecordingError.permissionDenied;
    return _Message(
      icon: Icons.mic_off_rounded,
      headline: isPermission
          ? l10n.voiceRecordingPermissionTitle
          : l10n.voiceRecordingUnavailableTitle,
      body: isPermission
          ? l10n.voiceRecordingErrorPermission
          : l10n.voiceRecordingErrorUnavailable,
      // A denial the OS will not re-prompt for makes Retry unwinnable, so the
      // card must also be closable.
      onDismiss: onDismissBlocked,
      dismissIdentifier: 'client_home_voice_blocked_dismiss',
      actions: <Widget>[
        Expanded(
          child: JeebCtaButton.outline(
            label: l10n.voiceRecordingRetry,
            identifier: 'client_home_voice_blocked_retry',
            onTap: onRetryBlocked,
            expand: true,
          ),
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: JeebCtaButton.text(
            label: l10n.voiceRecordingTypeInstead,
            identifier: 'client_home_voice_type_cta',
            onTap: onTypeInstead,
            expand: true,
          ),
        ),
      ],
    );
  }

  Widget _uploadFailure(
    BuildContext context,
    AppLocalizations l10n,
    VoiceRecordingState state,
  ) {
    return _Message(
      icon: Icons.warning_amber_rounded,
      headline: l10n.voiceRecordingUploadErrorTitle,
      body: voiceErrorCopy(l10n, state.error!),
      actions: <Widget>[
        Expanded(
          child: JeebCtaButton.primary(
            label: l10n.voiceRecordingRetry,
            identifier: 'client_home_voice_retry_upload',
            onTap: onRetryUpload,
            expand: true,
          ),
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: JeebCtaButton.text(
            label: l10n.voiceRecordingRecordAgain,
            identifier: 'client_home_voice_discard',
            onTap: onDiscard,
            expand: true,
          ),
        ),
      ],
    );
  }

  Widget _tierBlocked(BuildContext context, AppLocalizations l10n) {
    return _Message(
      icon: Icons.cloud_off_rounded,
      headline: l10n.homeVoiceTierUnavailable,
      onDismiss: onDismissTier,
      dismissIdentifier: 'client_home_voice_tier_dismiss',
      actions: <Widget>[
        Expanded(
          child: JeebCtaButton.primary(
            label: l10n.voiceRecordingRetry,
            identifier: 'client_home_voice_retry_tier',
            isLoading: tierRetrying,
            onTap: onRetryTier,
            expand: true,
          ),
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: JeebCtaButton.text(
            label: l10n.voiceRecordingTypeInstead,
            identifier: 'client_home_voice_tier_type_cta',
            onTap: onTypeInstead,
            expand: true,
          ),
        ),
      ],
    );
  }

  Widget _recording(
    BuildContext context,
    AppLocalizations l10n,
    VoiceRecordingState state,
  ) {
    final semantic = _semantic(context);
    final bodySize =
        context.jeebText.bodySmall.fontSize ?? _waveformHideThreshold;
    final showWaveform =
        MediaQuery.textScalerOf(context).scale(bodySize) <=
        _waveformHideThreshold;
    final Widget readout = Row(
      children: <Widget>[
        const _LiveDot(),
        const SizedBox(width: Spacing.xSmall),
        Flexible(child: _Timer(elapsed: state.elapsed)),
        if (showWaveform) ...<Widget>[
          const SizedBox(width: Spacing.small),
          Expanded(
            // The kit's live mark has a fixed 76dp intrinsic width; scaling
            // it down is the only way a squeezed row cannot overflow.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: RecordingWaveform(
                identifier: 'client_home_recording_waveform',
                // Not "release to stop": a recording started from the mic's
                // semantics action has no finger to release.
                semanticLabel: l10n.homeMicLabelRecording,
              ),
            ),
          ),
        ],
      ],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The readout recedes as the slide commits — attention belongs on the
        // destination, not on a timer for a clip about to be thrown away.
        RepaintBoundary(
          child: ValueListenableBuilder<double>(
            valueListenable: slideProgress,
            builder: (context, t, child) => Opacity(
              opacity: MediaQuery.disableAnimationsOf(context)
                  ? (t >= 1 ? _dimmedReadout : 1.0)
                  : 1 - (1 - _dimmedReadout) * t,
              child: child,
            ),
            child: readout,
          ),
        ),
        const SizedBox(height: Spacing.twoXSmall),
        // Confines the per-pointer-move slide rebuild to the hint row.
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: Listenable.merge(<Listenable>[slideProgress, handsFree]),
            builder: (context, _) {
              final bool rtl = Directionality.of(context) == TextDirection.rtl;
              // No pointer means no slide and no release: the second tap is
              // the only stop this user has.
              if (handsFree.value) {
                return _HandsFreeHint(muted: semantic.mutedText);
              }
              final double t = slideProgress.value;
              final bool armed = t >= 1;
              final bool pinned = MediaQuery.disableAnimationsOf(context);
              final double lean = pinned ? 0 : t;
              final Color error = Theme.of(context).colorScheme.error;
              // Binary at arm when motion is off, matching the disc beside it.
              final Color ink = armed
                  ? error
                  : (pinned
                        ? semantic.mutedText
                        : Color.lerp(semantic.mutedText, error, t)!);
              final int dir = rtl ? 1 : -1;
              return Transform.translate(
                offset: Offset(dir * _hintLean * lean, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Transform.translate(
                      offset: Offset(dir * Spacing.xSmall * lean, 0),
                      child: Icon(
                        rtl
                            ? Icons.chevron_right_rounded
                            : Icons.chevron_left_rounded,
                        size: 16,
                        color: ink,
                      ),
                    ),
                    Flexible(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          armed
                              ? l10n.homeVoiceReleaseToCancel
                              : l10n.homeVoiceSlideToCancel,
                          style: context.jeebText.bodySmall.copyWith(
                            color: ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The instruction for a recording nobody is holding: the stop lives in a
/// second tap, and it was previously spoken only as a TalkBack tap hint.
class _HandsFreeHint extends StatelessWidget {
  const _HandsFreeHint({required this.muted});

  final Color muted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      key: const Key('client-home-voice-hands-free-hint'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(
          child: Icon(Icons.touch_app_rounded, size: 16, color: muted),
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Flexible(
          child: Semantics(
            liveRegion: true,
            child: Text(
              l10n.homeVoiceTapToStop,
              style: context.jeebText.bodySmall.copyWith(color: muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

/// How far the whole hint row leans toward the start edge at full travel; the
/// chevron keeps its extra 8dp lead on top of it.
const double _hintLean = 12;

/// Where the timer + waveform row settles once the slide is armed.
const double _dimmedReadout = 0.7;

/// `00:07 / 1:00`. Directionality-isolated: under an Arabic paragraph UAX#9
/// swaps the two runs and the cap paints where the elapsed time belongs.
class _Timer extends StatelessWidget {
  const _Timer({required this.elapsed});

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatted = formatClock(elapsed);
    return Semantics(
      identifier: 'client_home_voice_timer',
      label: l10n.voiceRecordingTimerLabel(formatted),
      container: true,
      child: ExcludeSemantics(
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: ClientHomeVoiceDock._timerMaxTextScale,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '$formatted / '
              '${formatClock(VoiceRecordingState.maxDuration, padMinutes: false)}',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: context.jeebText.titleProminent.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.headline,
    required this.actions,
    this.body,
    this.onDismiss,
    this.dismissIdentifier,
  });

  final IconData icon;
  final String headline;
  final String? body;
  final List<Widget> actions;
  final VoidCallback? onDismiss;
  final String? dismissIdentifier;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semantic = _semantic(context);
    final colorScheme = Theme.of(context).colorScheme;
    final bodyText = body;
    final dismiss = onDismiss;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(icon, size: 20, color: colorScheme.error),
            ),
            const SizedBox(width: Spacing.xSmall),
            Expanded(
              child: Text(
                headline,
                style: context.jeebText.titleProminent.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            if (dismiss != null) ...<Widget>[
              const SizedBox(width: Spacing.xSmall),
              Semantics(
                identifier: dismissIdentifier,
                button: true,
                label: l10n.commonDismiss,
                container: true,
                child: IconButton(
                  onPressed: dismiss,
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  tooltip: l10n.commonDismiss,
                  color: semantic.mutedText,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          ],
        ),
        if (bodyText != null) ...<Widget>[
          const SizedBox(height: Spacing.twoXSmall),
          Text(
            bodyText,
            style: context.jeebText.bodySmall.copyWith(
              color: semantic.mutedText,
            ),
          ),
        ],
        const SizedBox(height: Spacing.small),
        Row(children: actions),
      ],
    );
  }
}

/// The live-capture mark beside the timer — R1's glow dot. Static: the screen's
/// rule is scoped, not reversed — decor holds still, affordances breathe.
class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: Sizes.xSmall,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.jeebRoles.accent,
        ),
      ),
    );
  }
}

JeebSemanticColors _semantic(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();
