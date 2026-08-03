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

  /// T-BE-019 / JEB-55: E.164 phone the at-door handover OTP is dispatched to.
  /// Threaded through to the gateway create body as `recipientPhone` so the
  /// gateway request-store row (which the OTP issue/verify path reads) carries
  /// a non-null phone — without it the gateway `POST /deliveries/{id}/otp/verify`
  /// returns 400 `recipient-phone-missing`. Null when the compose flow did not
  /// capture one; the submission service then falls back to the signed-in
  /// client's own profile phone (the requester is the default recipient).
  final String? recipientPhone;

  /// LOCAL-ONLY (never sent): on-device file the recorder wrote, so the summary
  /// can replay the clip. [audioUrl] is the gateway audioId — not playable.
  final String? audioLocalPath;

  /// LOCAL-ONLY: recorded clip length for the replay read-out. Null renders no
  /// duration at all rather than a fabricated one.
  final int? audioDurationMs;
}
