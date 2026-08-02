import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/transcription_cubit.dart';
import '../transcription_screen.dart';

class TranscriptionAudioCard extends StatelessWidget {
  const TranscriptionAudioCard({super.key, required this.state});

  final TranscriptionState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: OmdsBorderRadius.medium,
      ),
      child: Row(
        children: [
          _PlaybackToggle(isPlaying: state.isPlaying),
          const SizedBox(width: Spacing.medium),
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
    return Semantics(
      identifier: TranscriptionKeys.audioToggle,
      button: true,
      label: isPlaying ? l10n.transcriptionPauseAudio : l10n.transcriptionPlayAudio,
      child: IconButton.filled(
        iconSize: Sizes.fourXLarge,
        onPressed: () => context.read<TranscriptionCubit>().togglePlayback(),
        icon: Icon(
          isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
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
    final colorScheme = Theme.of(context).colorScheme;
    final total = state.audioDuration;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (state.playbackPosition.inMilliseconds / total.inMilliseconds)
            .clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: OmdsBorderRadius.twoXSmall,
          child: LinearProgressIndicator(
            value: progress,
            minHeight: Sizes.xSmall,
            backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          '${_format(state.playbackPosition)} / ${_format(total)}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ],
    );
  }
}

String _format(Duration duration) {
  final clamped = duration.isNegative ? Duration.zero : duration;
  final minutes = clamped.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
