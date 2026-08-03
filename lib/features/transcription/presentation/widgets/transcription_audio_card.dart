import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_meter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/transcription_cubit.dart';
import '../transcription_screen.dart';

/// Replay control for the original recording (redesign-2026-08 tpl 310-320):
/// a tonal card holding a solid navy play/pause disc and, filling the rest of
/// the row, a seekable scrubber with the start/end times split to the edges.
class TranscriptionAudioCard extends StatelessWidget {
  const TranscriptionAudioCard({super.key, required this.state});

  final TranscriptionState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: OmdsBorderRadius.medium,
      ),
      child: Row(
        children: [
          _PlaybackToggle(isPlaying: state.isPlaying),
          const SizedBox(width: Spacing.small),
          _PlaybackWaveform(isPlaying: state.isPlaying),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: TranscriptionKeys.audioToggle,
      button: true,
      label:
          isPlaying ? l10n.transcriptionPauseAudio : l10n.transcriptionPlayAudio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
          boxShadow: JeebShadows.raised,
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
                color: colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The voice mark inside the replay card (motion spec §2.2 — 06 is a listed
/// consumer of `voice-waveform.json`, "previewing a voice clip").
///
/// It occupies the same box whether or not the clip is running, so starting
/// playback never resizes the scrubber beside it; the bars move only while
/// audio is genuinely playing and otherwise rest on the composition's first
/// frame. Decorative: the toggle and the scrubber already carry the card's
/// semantics.
///
/// Radially symmetric (09-MOTION-VALIDATION §8 `RTL: none`) — no mirror.
class _PlaybackWaveform extends StatelessWidget {
  const _PlaybackWaveform({required this.isPlaying});

  /// 320×96 canvas, 90f, seamless loop, orange bars with an alpha tail.
  static const String _asset = 'assets/animations/voice-waveform.json';

  /// Sized to sit on the row's midline beside a Ø48 disc without crowding the
  /// scrubber; the width holds the composition's 320:96 canvas aspect. The
  /// film wants ~48dp of height to render its 6px bars at full weight, which
  /// this row cannot give without halving the (functional) scrubber — the
  /// scrubber wins.
  static const double _height = 24;
  static const double _width = _height * 320 / 96;

  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Lottie.asset(
        _asset,
        width: _width,
        height: _height,
        // Reduce-motion (and pause) hold frame 0 — a still voice mark.
        animate: isPlaying && !MediaQuery.disableAnimationsOf(context),
        addRepaintBoundary: true,
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
      // NOT periwinkle: periwinkle-on-white is a documented AA failure
      // (color_role_contrast_test.dart).
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
