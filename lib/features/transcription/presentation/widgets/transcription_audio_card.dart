import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/transcription_cubit.dart';
import '../transcription_screen.dart';

import '../../../../core/previews/jeeb_preview.dart';

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
// ============================= JEEB PREVIEWS =============================
/// Phone width, and tall enough to show both the ~96 pt production card and the
const Size _transcriptionAudioCardBox = Size(390, 160);

/// The gateway `audioId` every fixture carries — the Screen Catalog's id for
const String _transcriptionAudioCardAudioId = 'audio-ready-1';

/// The composer's on-device recording (JEBV4-13). Present on the normal in-app
const String _transcriptionAudioCardLocalPath =
    '/data/user/0/jeeb/cache/voice-request.m4a';

/// The Screen Catalog's fixture length for this screen.
const Duration _transcriptionAudioCardClipLength = Duration(seconds: 42);

/// `VoiceRecordingState.maxDuration` — the recorder's hard cap.
const Duration _transcriptionAudioCardRecorderCapLength = Duration(seconds: 60);

/// Seeds the card the way the transcription screen does, and gives it the
Widget _transcriptionAudioCardHosted(
  TranscriptionState state, {
  bool bounded = false,
}) {
  final Widget card = BlocProvider<TranscriptionCubit>(
    create: (_) => TranscriptionCubit(),
    child: TranscriptionAudioCard(state: state),
  );
  if (bounded) return card;
  return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[card]);
}

/// A clip built from the composer handoff, playhead wherever [position] says.
TranscriptionState _transcriptionAudioCardClip({
  required Duration total,
  Duration position = Duration.zero,
  bool isPlaying = false,
  String? localAudioPath = _transcriptionAudioCardLocalPath,
}) {
  return TranscriptionState(
    text: 'Please deliver 2 bags of rice and a water gallon to Hamra, Beirut.',
    audioPath: _transcriptionAudioCardAudioId,
    localAudioPath: localAudioPath,
    audioDuration: total,
    playbackPosition: position,
    isPlaying: isPlaying,
  );
}

/// The state the screen opens in: audio on file, nothing played yet.
@JeebPreview(
  group: 'transcription',
  name: 'Idle at start',
  size: _transcriptionAudioCardBox,
)
Widget transcriptionAudioCardIdle() => _transcriptionAudioCardHosted(
      _transcriptionAudioCardClip(total: _transcriptionAudioCardClipLength),
    );

/// Mid-playback — the only state where elapsed and total differ, and therefore
@JeebPreview(
  group: 'transcription',
  name: 'Playing mid-clip',
  size: _transcriptionAudioCardBox,
)
Widget transcriptionAudioCardPlaying() => _transcriptionAudioCardHosted(
      _transcriptionAudioCardClip(
        total: _transcriptionAudioCardClipLength,
        position: const Duration(seconds: 17),
        isPlaying: true,
      ),
    );

/// Playback finished — `_onCompleted` parks the playhead at the end and clears
@JeebPreview(
  group: 'transcription',
  name: 'Finished',
  size: _transcriptionAudioCardBox,
)
Widget transcriptionAudioCardFinished() => _transcriptionAudioCardHosted(
      _transcriptionAudioCardClip(
        total: _transcriptionAudioCardClipLength,
        position: _transcriptionAudioCardClipLength,
      ),
    );

/// The longest clip the composer can ever hand over: the 60-second recorder
@JeebPreview(
  group: 'transcription',
  name: 'Recorder cap',
  size: _transcriptionAudioCardBox,
)
Widget transcriptionAudioCardRecorderCap() => _transcriptionAudioCardHosted(
      _transcriptionAudioCardClip(
        total: _transcriptionAudioCardRecorderCapLength,
        position: const Duration(seconds: 59),
        isPlaying: true,
      ),
    );

/// Audio on file, duration unknown — reachable, not hypothetical.
@JeebPreview(
  group: 'transcription',
  name: 'Unknown duration',
  size: _transcriptionAudioCardBox,
)
Widget transcriptionAudioCardUnknownDuration() =>
    _transcriptionAudioCardHosted(
      _transcriptionAudioCardClip(
        total: Duration.zero,
        localAudioPath: null,
      ),
    );

/// The same clip in a height-bounded parent instead of a [ListView] — a layout
@JeebPreview(
  group: 'transcription',
  name: 'Bounded slot',
  size: _transcriptionAudioCardBox,
)
Widget transcriptionAudioCardBoundedSlot() => _transcriptionAudioCardHosted(
      _transcriptionAudioCardClip(
        total: _transcriptionAudioCardClipLength,
        position: const Duration(seconds: 30),
        isPlaying: true,
      ),
      bounded: true,
    );
