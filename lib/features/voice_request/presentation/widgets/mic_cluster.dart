import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/directional_icons.dart';
import '../../../../core/widgets/jeeb/jeeb_mic_hero.dart';
import '../../../../l10n/app_localizations.dart';

/// The docked thumb cluster on the voice-request board: the `×` cancel
/// satellite, the Ø128 [JeebMicHero] with its max-duration arc, and the
/// keyboard satellite that hands off to typed input.
///
/// A [Row], deliberately not the board's absolutely-positioned stack: the two
/// satellites ride equal-flex flanks aligned to the reading start/end, which
/// puts the disc on the screen's axis in both directions without a single
/// `left:`/`right:` offset.
class MicCluster extends StatelessWidget {
  const MicCluster({
    super.key,
    required this.micKey,
    required this.cancelKey,
    required this.isRecording,
    required this.onPressStart,
    required this.onPressEnd,
    required this.onCancel,
    this.progress,
    this.onSwitchToTyping,
  });

  /// The frozen QA key for the mic disc (`VoiceRecordingKeys.micButton`).
  final Key micKey;

  /// The frozen QA key for the cancel satellite
  /// (`VoiceRecordingKeys.cancelButton`).
  final Key cancelKey;

  /// Whether audio is being captured — drives the halo, the arc and whether
  /// the cancel satellite is mounted at all.
  final bool isRecording;

  /// Touch-down: starts the recording.
  final VoidCallback onPressStart;

  /// Release: finalises the clip into the local review.
  final VoidCallback onPressEnd;

  /// Slide-to-cancel and the `×` tap share one handler — both discard the
  /// in-flight clip without raising the too-short error.
  final VoidCallback onCancel;

  /// Elapsed / max as 0–1 while recording; null draws no arc.
  final double? progress;

  /// Hands off to typed input. Null hides the Type satellite entirely — the
  /// screen stays router-agnostic and each route decides its destination.
  final VoidCallback? onSwitchToTyping;

  /// The square the mic block always reserves — the halo extent, so the
  /// cluster does not resize when recording starts.
  static final double micExtent = JeebMicHero.extentFor(
    size: JeebMicHero.sizeHero,
    halo: true,
    arc: true,
  );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Widget cluster = Row(
      children: <Widget>[
        // Equal flex on both flanks, so the mic sits on the screen's axis no
        // matter how wide a satellite caption grows — the board pins the two
        // circles to the edges and centres the disc.
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: isRecording
                ? _CircleSatellite(
                    circleKey: cancelKey,
                    icon: Icons.close,
                    identifier: 'voice_request_cancel_button',
                    semanticLabel: l10n.voiceRecordingCancel,
                    onTap: onCancel,
                    caption: _SlideCaption(
                      label: l10n.voiceRecordingSlideToCancel,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
        SizedBox.square(
          dimension: micExtent,
          child: Center(
            child: JeebMicHero(
              key: micKey,
              isRecording: isRecording,
              progress: progress,
              // Semantics(identifier:) surfaces as the Android resource-id so
              // uiautomator/Maestro can target the mic; a Key alone never
              // reaches them (D2).
              identifier: 'voice_request_mic_button',
              semanticLabel: l10n.voiceRecordingMicSemantic,
              onPressStart: onPressStart,
              onPressEnd: onPressEnd,
              onSlideCancel: onCancel,
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: onSwitchToTyping == null
                ? const SizedBox.shrink()
                // Inert while recording: the thumb is on the mic, and a stray
                // tap that navigated away would drop the in-flight clip.
                : IgnorePointer(
                    ignoring: isRecording,
                    child: _CircleSatellite(
                      icon: Icons.keyboard,
                      identifier: 'voice_request_type_button',
                      semanticLabel: l10n.voiceRecordingTypeInstead,
                      onTap: onSwitchToTyping,
                      caption: _SatelliteCaption(
                        label: l10n.voiceRecordingTypeInstead,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
    // The Stack is unconditional and the pulse owns its own on/off. Swapping
    // the cluster in and out of a wrapper on `isRecording` would re-parent
    // JeebMicHero mid-press, disposing the State that is tracking the live
    // pointer — release-to-stop and slide-to-cancel both die with it.
    return Stack(
      // Concentric with the disc, which the equal-flex flanks already centre —
      // a plain centre alignment is directional-safe.
      alignment: Alignment.center,
      children: <Widget>[
        _MicListeningPulse(isRecording: isRecording),
        cluster,
      ],
    );
  }
}

/// The listening breath that plays while the mic is held (motion spec §2.1).
///
/// `mic-listening.json` carries its own static orange disc + white glyph at the
/// canvas centre. At [extent] that disc lands at Ø105.6 — entirely behind the
/// Ø128 [JeebMicHero] — so only the two expanding rings ever read, which is
/// exactly the division of labour the spec asks for: Dart owns the press state,
/// the glow and the data-driven max-duration arc; the film owns the pulse.
///
/// Nothing here duplicates kit motion: [JeebMicHero]'s glow and halo are static
/// gradients, and its arc is bound to real elapsed time.
///
/// Radially symmetric (09-MOTION-VALIDATION §8 `RTL: none`) — no mirror.
class _MicListeningPulse extends StatelessWidget {
  const _MicListeningPulse({required this.isRecording});

  /// 240×240 canvas, 120f, seamless loop, reads on white and on navy.
  static const String asset = 'assets/animations/mic-listening.json';

  /// 1.2× the canvas. The rings run Ø115→Ø240 at this scale, so a ring emerges
  /// from the Ø128 disc's edge at ~49% opacity and has dissolved well before
  /// the box edge; 288 also stays inside the 24px gutters on a 360dp screen.
  static const double extent = 288;

  /// Only a held mic breathes — an idle composer that pulsed would claim to be
  /// listening when nothing is being captured.
  final bool isRecording;

  @override
  Widget build(BuildContext context) {
    if (!isRecording) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: IgnorePointer(
        // Laid out at the cluster's own mic square so the rings can overflow
        // the disc without widening the Row or moving the satellites.
        child: SizedBox.square(
          dimension: MicCluster.micExtent,
          child: OverflowBox(
            maxWidth: extent,
            maxHeight: extent,
            child: Lottie.asset(
              asset,
              width: extent,
              height: extent,
              // Reduce-motion holds frame 0: one still ring around the disc.
              animate: !MediaQuery.disableAnimationsOf(context),
              addRepaintBoundary: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// One Ø48 tonal circle plus its caption.
///
/// Ø48 rather than the board's Ø46: `Sizes` has no 46, literal-number sizes
/// are banned in `lib/features`, and 48 is the minimum tap target anyway.
class _CircleSatellite extends StatelessWidget {
  const _CircleSatellite({
    required this.icon,
    required this.identifier,
    required this.semanticLabel,
    required this.caption,
    this.onTap,
    this.circleKey,
  });

  final IconData icon;
  final String identifier;
  final String semanticLabel;
  final Widget caption;
  final VoidCallback? onTap;
  final Key? circleKey;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          identifier: identifier,
          label: semanticLabel,
          button: true,
          container: true,
          child: SizedBox.square(
            key: circleKey,
            dimension: Sizes.fourXLarge,
            child: Material(
              color: scheme.surfaceContainerHigh,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Icon(icon, size: Sizes.large, color: scheme.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.xSmall),
        caption,
      ],
    );
  }
}

/// `Slide` with a leading directional chevron. The chevron is a widget, never
/// a `‹` baked into the string — it has to mirror with the locale.
class _SlideCaption extends StatelessWidget {
  const _SlideCaption({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final Color ink = _captionInk(context);
    return _CaptionBox(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            DirectionalIcons.backIos(context),
            size: Sizes.small,
            color: ink,
          ),
          const SizedBox(width: Spacing.twoXSmall),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.jeebText.bodySmall.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _SatelliteCaption extends StatelessWidget {
  const _SatelliteCaption({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return _CaptionBox(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: context.jeebText.bodySmall.copyWith(color: _captionInk(context)),
      ),
    );
  }
}

/// Caps a caption at 80px so a 200%-scaled label stays a caption instead of
/// running the full width of its flank.
class _CaptionBox extends StatelessWidget {
  const _CaptionBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: Sizes.eightXLarge),
      child: child,
    );
  }
}

Color _captionInk(BuildContext context) =>
    (Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.light())
        .mutedText;
