class VoiceClip {
  const VoiceClip({
    required this.audioPath,
    required this.durationMs,
    this.transcript,
    this.localAudioPath,
  });

  final String audioPath;
  final int durationMs;
  final String? transcript;

  final String? localAudioPath;
}
