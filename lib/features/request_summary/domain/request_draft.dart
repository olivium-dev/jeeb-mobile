class RequestDraft {
  const RequestDraft({
    required this.description,
    this.transcription,
    this.audioUrl,
    this.photoUrls = const [],
    this.tierId,
    this.tierName,
    this.pickupLat,
    this.pickupLng,
    this.pickupAddress,
    this.dropoffLat,
    this.dropoffLng,
    this.dropoffAddress,
    this.recipientPhone,
    this.audioLocalPath,
    this.audioDurationMs,
  });
  final String description;
  final String? transcription;
  final String? audioUrl;
  final List<String> photoUrls;
  final String? tierId;
  final String? tierName;
  final double? pickupLat;
  final double? pickupLng;
  final String? pickupAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final String? dropoffAddress;

  final String? recipientPhone;

  /// LOCAL-ONLY (never sent): on-device file the recorder wrote, so the summary
  /// can replay the clip. [audioUrl] is the gateway audioId — not playable.
  final String? audioLocalPath;

  /// LOCAL-ONLY: recorded clip length for the replay read-out. Null renders no
  /// duration at all rather than a fabricated one.
  final int? audioDurationMs;
}
