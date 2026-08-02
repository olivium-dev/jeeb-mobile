import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/transcription_cubit.dart';
import '../transcription_screen.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests:
// test/previews/transcription/transcription_audio_card_preview_test.dart
// ===========================================================================
//
// Widget previews for [TranscriptionAudioCard] — run with
// `flutter widget-preview start`.
//
// The card is the replay control on the voice transcription-review screen: it
// sits above the machine transcript and lets the customer hear what the
// recorder actually captured before confirming the request.
// `_TranscriptionBody` renders it only when [TranscriptionState.hasAudio] is
// true, so every state below carries a non-empty `audioPath`.
//
// **Network-free by construction.** The card takes a plain
// [TranscriptionState] value — it fetches nothing. Its one ambient dependency
// is the [TranscriptionCubit] the play/pause button reaches for inside
// `onPressed`, and the cubit seeded here is built with no player argument, so
// it falls back to `NoopTranscriptAudioPlayer`: clicking the toggle in the
// canvas is an inert no-op, not a platform-channel call. There is no
// repository to fake and nothing to guard.
//
// **Fixtures.** The 42-second clip is the one the Screen Catalog already uses
// for this screen (`batch_11_entries.dart`, `audio-ready-1` / `durationMs:
// 42000`); the 60-second clip is `VoiceRecordingState.maxDuration`, the
// recorder's hard cap and therefore the longest audio this card can ever be
// handed. Each state's `mm:ss / mm:ss` read-out is deliberately distinct so
// the render test can prove every preview built ITS OWN state.
//
// ## What the matrix exposes
//
// **1. The card does not shrink-wrap — it fills whatever height it is given.**
// `_PlaybackProgress` builds a [Column] at the default `MainAxisSize.max`, so
// the card's height is its *incoming* `maxHeight`, not its content height. It
// only looks right in production because its single call site
// (`_TranscriptionBody`) is a [ListView] child, which hands it an unbounded
// main axis. Measured at 390 pt wide on a 400 pt slot: in a ListView the card
// is 390x96 with the bar at y=32 and the icon at y=16; in a bounded slot it
// becomes 390x400 with the bar stranded at y=16 and the icon centred at
// y=168 — 150 pt of empty card between the two halves of one control. See
// [transcriptionAudioCardBoundedSlot]. Every other preview here is wrapped in
// a `MainAxisSize.min` [Column] precisely so it reproduces the ListView
// geometry the app ships.
//
// **2. At 0% progress the bar is effectively invisible.** The track is
// `colorScheme.outline` at 20% alpha over `surfaceContainerHigh`, which
// resolves to a **1.24:1** contrast ratio in the light theme and **1.36:1** in
// dark — far under the 3:1 WCAG 2.2 §1.4.11 asks of a graphic that carries
// meaning. The filled portion is fine (11.23:1 light / 6.25:1 dark against the
// track), so the control reads correctly *once playing*; but
// [transcriptionAudioCardIdle] — the state every user meets first — is a card
// with an icon, a timestamp and a scrubber nobody can see.
//
// **3. RTL: the read-out and the bar mirror; the play glyph does not.**
// [LinearProgressIndicator] flips its fill in RTL (SDK
// `_LinearProgressIndicatorPainter.drawBar`), and the unpinned
// `'$position / $total'` string bidi-reorders to match, so an Arabic reader
// still meets elapsed first (rightmost) and the numbers stay in step with the
// fill — measured: elapsed at x 220.5–278.0, total at 128.5–186.0 in AR
// against 0.3–57.8 / 92.3–149.8 in EN. That half is correct and the AR RTL
// rendering is here to keep it correct. What does *not* flip is
// `Icons.play_circle_filled`, which carries no `matchTextDirection`: the
// triangle keeps pointing right while the playhead now travels left. The two
// halves of one control disagree about which way "forward" is.

/// Phone width, and tall enough to show both the ~96 pt production card and the
/// stretch in [transcriptionAudioCardBoundedSlot] without either touching the
/// box edge.
const Size _transcriptionAudioCardBox = Size(390, 160);

/// The gateway `audioId` every fixture carries — the Screen Catalog's id for
/// this screen. It is never rendered; it only makes
/// [TranscriptionState.hasAudio] true, which is what puts the card on screen at
/// all.
const String _transcriptionAudioCardAudioId = 'audio-ready-1';

/// The composer's on-device recording (JEBV4-13). Present on the normal in-app
/// handoff; its absence is what leaves the toggle inert on a cold deep link.
const String _transcriptionAudioCardLocalPath =
    '/data/user/0/jeeb/cache/voice-request.m4a';

/// The Screen Catalog's fixture length for this screen.
const Duration _transcriptionAudioCardClipLength = Duration(seconds: 42);

/// `VoiceRecordingState.maxDuration` — the recorder's hard cap.
const Duration _transcriptionAudioCardRecorderCapLength = Duration(seconds: 60);

/// Seeds the card the way the transcription screen does, and gives it the
/// unbounded main axis its real parent gives it.
///
/// The [Column] is not decoration. `_PlaybackProgress`'s own Column is
/// `MainAxisSize.max`, so a bounded parent stretches the card to fill (see
/// [transcriptionAudioCardBoundedSlot]); a `MainAxisSize.min` Column lays its
/// child out with `maxHeight: infinity`, exactly as the production [ListView]
/// does, and the card settles at its intrinsic 96 pt.
///
/// The cubit exists only for the toggle's `onPressed`. It is built with no
/// player, so it degrades to `NoopTranscriptAudioPlayer`, and [BlocProvider]
/// creates it lazily — a preview that is never clicked never builds it.
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
///
/// This is the contrast case. Progress is 0.0, so [LinearProgressIndicator]
/// paints *only* its track — `outline` at 20% alpha over `surfaceContainerHigh`,
/// 1.24:1 in light and 1.36:1 in dark. Compare the EN light and AR RTL dark
/// renderings: in both, the scrubber the layout reserves 8 pt for is not
/// visible at all until something has played. The icon and the `00:00 / 00:42`
/// read-out are the only affordances that survive.
@JeebPreview(
  group: 'transcription',
  name: 'Idle at start',
  size: _transcriptionAudioCardBox,
)
Widget transcriptionAudioCardIdle() => _transcriptionAudioCardHosted(
      _transcriptionAudioCardClip(total: _transcriptionAudioCardClipLength),
    );

/// Mid-playback — the only state where elapsed and total differ, and therefore
/// the only one in which the RTL rendering says anything.
///
/// EN light reads `00:17 / 00:42` left to right; AR RTL dark reorders it to
/// `00:42 / 00:17` on screen, which is *correct* — an Arabic reader starts at
/// the right and still meets elapsed first, in step with a bar that now fills
/// from the right. Hold the two renderings side by side: the numbers mirror,
/// the bar mirrors, and the play/pause glyph does not.
///
/// It is also the only state with a partially-filled bar (17/42 ≈ 40%), i.e.
/// the only one where the fill colour is reviewable against its own track.
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
/// `isPlaying`.
///
/// A full bar under a **play** icon. That is behaviourally right (the next tap
/// restarts from zero, per `togglePlayback`'s `restart` branch) but visually
/// ambiguous: the card offers no replay affordance distinct from play, so the
/// only cue that this clip is spent is a bar the idle state has already shown
/// is hard to see.
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
/// cap, one second from the end.
///
/// The read-out rolls into the minutes column here (`00:59 / 01:00`), making it
/// the widest string this card renders and the binding case for the 200%
/// rendering. The read-out is a bare [Text] with no `maxLines` and no
/// `overflow`, so at large text it soft-wraps around the ` / ` and grows the
/// card rather than clipping — measured 278x16 at 1.0 and 278x64 at 2.0, with
/// no overflow and no exception. Note that `flutter test` substitutes a
/// one-em-per-glyph font: the wrap is a worst case (292.5 pt wanted against 278
/// available), and with the shipping Inter face the 13-character read-out fits
/// on one line at both scales.
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
///
/// `VoiceRecordingScreen`'s listener forwards `duration: state.clip?.duration ??
/// Duration.zero` alongside a valid upload id, so whenever the recorder's clip
/// has already been released the review screen receives `hasAudio == true` with
/// `audioDuration == Duration.zero`. `localAudioPath` is dropped here too, the
/// way a rehydrated/cold-deep-link clip arrives.
///
/// The card then renders `00:00 / 00:00` over an empty determinate bar — pixel
/// for pixel what a zero-length recording would look like. There is no
/// indeterminate or "length unknown" treatment, so a customer holding perfectly
/// good audio is shown a control that says there is nothing to play, and the
/// toggle beneath it is still fully enabled (`onPressed` is never null) even
/// though `togglePlayback` will hand `audio-ready-1` — a gateway id, not a path
/// — to the player and silently swallow the failure. The
/// `total.inMilliseconds == 0` branch in `_PlaybackProgress` keeps this from
/// dividing by zero; it is a guard, not a design.
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
/// context, not a data state, and the reason every other preview here carries a
/// `MainAxisSize.min` wrapper.
///
/// `_PlaybackProgress`'s Column is `MainAxisSize.max`, so the card takes the
/// full height offered. Measured on a 400 pt slot: 390x400 instead of 390x96,
/// bar stranded at y=16 while the [Row] centres the icon at y=168. Nothing
/// throws, nothing paints an overflow stripe — the control just comes apart.
/// Today the only call site is a ListView child, so this cannot bite users; the
/// day someone drops this card into a fixed-height header, a bottom sheet row
/// or a [Row], it will, and silently.
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
