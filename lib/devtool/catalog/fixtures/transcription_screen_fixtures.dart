import 'package:jeeb_mobile/features/transcription/application/transcription_cubit.dart';
import 'package:jeeb_mobile/features/transcription/domain/transcript_audio_player.dart';
import 'package:jeeb_mobile/features/transcription/domain/voice_clip.dart';

/// Ready: machine transcript came back, customer reviewing.
const VoiceClip transcriptionScreenReadyClip = VoiceClip(
  audioPath: 'audio-ready-1',
  durationMs: 42000,
  transcript:
      'Please deliver 2 bags of rice and a water gallon to Hamra, Beirut.',
);

/// Queued: upload landed, transcript pending.
const VoiceClip transcriptionScreenQueuedClip = VoiceClip(
  audioPath: 'audio-queued-1',
  durationMs: 15000,
);

/// Failed: transcription call errored, no text.
const VoiceClip transcriptionScreenFailedClip = VoiceClip(
  audioPath: 'audio-failed-1',
  durationMs: 20000,
);

/// Editing: user correcting transcript.
const VoiceClip transcriptionScreenEditingClip = VoiceClip(
  audioPath: 'audio-edit-1',
  durationMs: 30000,
  transcript: 'Two bags of rice',
);

/// Longest transcript: 59s near recorder's hard cap.
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

/// Audio missing, transcript survives.
const VoiceClip transcriptionScreenNoAudioClip = VoiceClip(
  audioPath: '',
  durationMs: 0,
  transcript: 'Bring me bread from the bakery on the corner.',
);

/// Cubit wired to inert player; use when state needs driving beyond the clip.
TranscriptionCubit transcriptionScreenCubit(VoiceClip clip) =>
    TranscriptionCubit(player: const NoopTranscriptAudioPlayer())
      ..seedFromClip(clip);

/// Seed then `markFailed` — transcription errored.
TranscriptionCubit transcriptionScreenFailedCubit({
  VoiceClip clip = transcriptionScreenFailedClip,
  TranscriptionFailure failure = TranscriptionFailure.network,
}) => transcriptionScreenCubit(clip)..markFailed(failure);

/// Seed then `startEditing()` — text field open over transcript.
TranscriptionCubit transcriptionScreenEditingCubit({
  VoiceClip clip = transcriptionScreenEditingClip,
}) => transcriptionScreenCubit(clip)..startEditing();
