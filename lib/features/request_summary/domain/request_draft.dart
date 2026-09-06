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
    this.operationId,
    this.recipientPhoneLookupFailed = false,
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

  /// Idempotency-Key for this draft's whole retry chain, so a moderation
  /// acknowledge-then-resubmit can never create a second request.
  final String? operationId;

  /// The recipient-phone read failed (as opposed to "the user has no phone"),
  /// so a missing `recipientPhone` is not evidence of absence.
  final bool recipientPhoneLookupFailed;

  RequestDraft copyWith({String? operationId, bool? recipientPhoneLookupFailed}) =>
      RequestDraft(
        description: description,
        transcription: transcription,
        audioUrl: audioUrl,
        photoUrls: photoUrls,
        tierId: tierId,
        tierName: tierName,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        pickupAddress: pickupAddress,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
        dropoffAddress: dropoffAddress,
        recipientPhone: recipientPhone,
        audioLocalPath: audioLocalPath,
        audioDurationMs: audioDurationMs,
        operationId: operationId ?? this.operationId,
        recipientPhoneLookupFailed:
            recipientPhoneLookupFailed ?? this.recipientPhoneLookupFailed,
      );
}
