class RequestDraft {
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
  });
}
