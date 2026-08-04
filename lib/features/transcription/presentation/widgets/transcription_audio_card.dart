import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_meter.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/transcription_cubit.dart';
import '../transcription_screen.dart';

JeebSemanticColors _semanticsOf(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();

/// Replay control for the original recording (MIDNIGHT R8, board `tpl 479-488`):
/// rest glass at `lg`, an orange play disc, then the seekable scrubber with the
/// start/end times split to the edges. The board draws NO waveform in this row.
class TranscriptionAudioCard extends StatelessWidget {
  const TranscriptionAudioCard({super.key, required this.state});

  final TranscriptionState state;

  /// Board `padding:14px 16px`, border-box (the card folds its own stroke in).
  static const EdgeInsetsGeometry _padding =
      EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14);

  @override
  Widget build(BuildContext context) {
    return JeebOutlinedCard(
      radius: JeebRadii.lg,
      // Board stroke is `rgba(255,255,255,.15)` — the §4 strong rung.
      borderColor: _semanticsOf(context).glassBorderStrong,
      padding: _padding,
      child: Row(
        children: [
          _PlaybackToggle(isPlaying: state.isPlaying),
          const SizedBox(width: Spacing.small),
          Expanded(child: _PlaybackProgress(state: state)),
        ],
      ),
    );
  }
}

class _PlaybackToggle extends StatelessWidget {
  const _PlaybackToggle({required this.isPlaying});

  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final roles = context.jeebRoles;
    return Semantics(
      identifier: TranscriptionKeys.audioToggle,
      button: true,
      label:
          isPlaying ? l10n.transcriptionPauseAudio : l10n.transcriptionPlayAudio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: roles.accent,
          shape: BoxShape.circle,
          // Board `0 10px 22px rgba(215,59,0,.45)` → the §7 small orange lift.
          boxShadow: JeebShadows.ctaOrangeSmall,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.read<TranscriptionCubit>().togglePlayback(),
            // Ø48 already satisfies the 48dp tap-target minimum on its own.
            child: SizedBox.square(
              dimension: Sizes.fourXLarge,
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                size: Sizes.large,
                color: roles.onAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaybackProgress extends StatelessWidget {
  const _PlaybackProgress({required this.state});

  final TranscriptionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final total = state.audioDuration;
    final position = _format(state.playbackPosition);
    final duration = _format(total);
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (state.playbackPosition.inMilliseconds / total.inMilliseconds)
            .clamp(0.0, 1.0);
    final timeStyle = context.jeebText.caption.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          identifier: TranscriptionKeys.scrubber,
          slider: true,
          label: l10n.transcriptionScrubberLabel,
          value: '$position / $duration',
          child: JeebMeter.scrubber(
            value: progress,
            // Board `rgba(255,255,255,.15)`; the tone default is opaque navy,
            // which reads as a bar ON the glass instead of a hole in it.
            trackColor: _semanticsOf(context).glassFillPressed,
            onSeek: (fraction) => context.read<TranscriptionCubit>().seekTo(
                  Duration(
                    milliseconds: (total.inMilliseconds * fraction).round(),
                  ),
                ),
          ),
        ),
        const SizedBox(height: Spacing.twoXSmall),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TimeLabel(text: position, style: timeStyle),
            _TimeLabel(text: duration, style: timeStyle),
          ],
        ),
      ],
    );
  }
}

/// A clock read-out is always LTR — under `ar` an inherited RTL direction
/// renders `0:04` as `04:0`.
class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(text, style: style),
    );
  }
}

/// `0:04`, not `00:04` — the board drops the leading zero on minutes.
String _format(Duration duration) {
  final clamped = duration.isNegative ? Duration.zero : duration;
  final minutes = clamped.inMinutes.remainder(60);
  final seconds = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
