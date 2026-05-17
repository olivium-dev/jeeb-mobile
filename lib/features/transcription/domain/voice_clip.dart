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
  });

  final String audioPath;
  final int durationMs;
  final String? transcript;
}
