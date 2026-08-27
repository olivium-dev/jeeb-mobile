/// Voice clip passed between `voice_request` and `transcription` screens.
///
/// Stub created by sanity-build pass (2026-05-17). The wave-2-4 batch placed
/// a `VoiceClip`-like value object inside `voice_request/domain/voice_clip.dart`
/// — `app_router.dart` imports from this path. This is a minimal compatible
/// shape; the recorder writes into [audioPath].
class VoiceClip {
  const VoiceClip({
    required this.audioPath,
    required this.durationMs,
    this.transcript,
    this.localAudioPath,
    this.language,
    this.reason,
  });

  final String audioPath;
  final int durationMs;
  final String? transcript;

  /// The gateway's documented `TranscribeResponse.language` (e.g. `ar-LB`),
  /// which drives 06's detected-language chip. The voice_request lane parses
  /// it and the router threads it through when present (see
  /// `docs/redesign-2026-08/wiring/06-transcription-review.md`); the chip
  /// deliberately renders nothing rather than guessing from the UI locale.
  final String? language;

  /// The gateway's queued reason (for example `circuit_open`,
  /// `exhausted_retries`, or `queued_by_owner`). It is retained as
  /// informational state and is never shown to users as raw server text.
  final String? reason;

  /// JEBV4-13 (dead transcription-play CTA): absolute path of the ON-DEVICE
  /// file the recorder wrote, when the handoff came from the in-app voice
  /// composer. [audioPath] carries the gateway's `audioId` (forwarded on
  /// confirm as the create request's `audioUrl`) which is NOT locally
  /// playable; this is the path the replay control actually plays. Null on a
  /// cold deep link / rehydrated clip — playback then degrades to a no-op.
  final String? localAudioPath;
}
