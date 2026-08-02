// Shared dev-only fixtures for `TranscriptionScreen`.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_11_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/transcription/presentation/transcription_screen.dart`.
//
// The catalog owned four inline `VoiceClip` literals and two inline cubit
// seeding scripts. Copying those into the preview section would have given the
// two surfaces two different definitions of the same "designed state" — and on
// this screen the clip IS the state: `TranscriptionCubit.seedFromClip` derives
// `status` from whether `clip.transcript` is blank, so a fixture that drops a
// transcript silently moves the screen from `ready` to `queued` while both
// surfaces still "work". Both surfaces now import this file.
//
// ## Why clips and cubits, not widgets
//
// [TranscriptionScreen] takes two independent dev seams and the states split
// cleanly across them:
//
//   * `audioPlayer:` — the screen builds its OWN cubit and seeds it from the
//     clip. That is the production path, so the two states reachable straight
//     from a clip (`ready`, `queued`) use it and stay `const`.
//   * `cubit:` — a pre-driven cubit handed in whole, for the states that are
//     only reachable by CALLING something (`markFailed`, `startEditing`).
//     `TranscriptionCubit` has no `seed:` constructor and `emit` is not public,
//     so this is the only honest way to reach them from `lib/`.
//
// Both seams already existed; nothing here required a production change.
//
// ## Network- and platform-free by construction
//
// Every cubit below is built with [NoopTranscriptAudioPlayer], so the screen
// never reaches `AudioPlayersTranscriptAudioPlayer` — its default — and the
// play/pause toggle is an inert no-op rather than a platform-channel call. No
// repository exists on this screen at all: `TranscriptionCubit` has no
// dependency other than the player, so there is nothing to fake and nothing to
// guard. The `CatalogNetworkGuard` both hosts install is a net, not the plan.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'package:jeeb_mobile/features/transcription/application/transcription_cubit.dart';
import 'package:jeeb_mobile/features/transcription/domain/transcript_audio_player.dart';
import 'package:jeeb_mobile/features/transcription/domain/voice_clip.dart';

/// The happy path: the machine transcript came back and the customer is
/// reviewing it before sending.
///
/// 42 s is the Screen Catalog's original fixture length for this screen; the
/// audio card renders it as `00:00 / 00:42`, which is what makes this state
/// identifiable in a render test.
const VoiceClip transcriptionScreenReadyClip = VoiceClip(
  audioPath: 'audio-ready-1',
  durationMs: 42000,
  transcript:
      'Please deliver 2 bags of rice and a water gallon to Hamra, Beirut.',
);

/// Upload landed, transcript has not — the screen's EMPTY state, and the
/// closest thing it has to a loading state.
///
/// `seedFromClip` maps a blank transcript to [TranscriptionStatus.queued], so
/// leaving `transcript` off is what produces the queued banner, the
/// "Type your request here" placeholder and a disabled Send.
const VoiceClip transcriptionScreenQueuedClip = VoiceClip(
  audioPath: 'audio-queued-1',
  durationMs: 15000,
);

/// The clip behind the failed states. Deliberately transcript-less: a
/// transcription that errored produced no text, so anything else would be
/// describing a state the app cannot reach.
const VoiceClip transcriptionScreenFailedClip = VoiceClip(
  audioPath: 'audio-failed-1',
  durationMs: 20000,
);

/// A short transcript the user is correcting by hand.
const VoiceClip transcriptionScreenEditingClip = VoiceClip(
  audioPath: 'audio-edit-1',
  durationMs: 30000,
  transcript: 'Two bags of rice',
);

/// Layout ceiling: the longest transcript this screen can be handed.
///
/// 59 s is one second under `VoiceRecordingState.maxDuration`, the recorder's
/// hard cap, so this is the most speech the composer can hand over in one clip
/// — and the transcript is written to match that length rather than to be
/// arbitrarily long. Preview-only today; the catalog is welcome to adopt it.
const VoiceClip transcriptionScreenLongestClip = VoiceClip(
  audioPath: 'audio-longest-1',
  durationMs: 59000,
  transcript:
      'Please go to the Spinneys on Verdun street and pick up two bags of '
      'basmati rice, a five litre water gallon, one kilo of tomatoes, half a '
      'kilo of green beans, a pack of pita bread and two boxes of laban. If '
      'the green beans do not look fresh please take zucchini instead, and '
      'call me before you pay so I can confirm the total.',
);

/// The audio is gone but the transcript survived: `hasAudio` is false, so
/// `_TranscriptionBody` drops `TranscriptionAudioCard` entirely.
///
/// Reachable in production when the gateway returns a transcript without an
/// `audioId`, and it is the same guard `TranscriptionCubit.togglePlayback`
/// leans on (`test/transcription_screen_test.dart`, "togglePlayback is a no-op
/// without audio"). Preview-only today; the catalog is welcome to adopt it.
const VoiceClip transcriptionScreenNoAudioClip = VoiceClip(
  audioPath: '',
  durationMs: 0,
  transcript: 'Bring me bread from the bakery on the corner.',
);

/// The cubit both dev surfaces drive, wired to the inert player.
///
/// Equivalent to what `TranscriptionScreen(clip: clip, audioPlayer: const
/// NoopTranscriptAudioPlayer())` builds internally — same player, same
/// `seedFromClip`. Use this form only when a state has to be driven FURTHER
/// than the clip can take it.
TranscriptionCubit transcriptionScreenCubit(VoiceClip clip) =>
    TranscriptionCubit(player: const NoopTranscriptAudioPlayer())
      ..seedFromClip(clip);

/// `seedFromClip` then `markFailed(failure)` — the transcription call errored.
///
/// Note the audio SURVIVES: `markFailed` only flips `status`/`failure`, so the
/// user can still replay the recording and type a manual description. That is
/// why the failed banner never blocks the screen.
TranscriptionCubit transcriptionScreenFailedCubit({
  VoiceClip clip = transcriptionScreenFailedClip,
  TranscriptionFailure failure = TranscriptionFailure.network,
}) => transcriptionScreenCubit(clip)..markFailed(failure);

/// `seedFromClip` then `startEditing()` — the text field is open over the
/// transcript.
///
/// This is the only state where `_TranscriptionActions` renders nothing at all
/// (`if (state.isEditing) return const SizedBox.shrink()`), so it is also the
/// only state whose bottom bar is missing.
TranscriptionCubit transcriptionScreenEditingCubit({
  VoiceClip clip = transcriptionScreenEditingClip,
}) => transcriptionScreenCubit(clip)..startEditing();
