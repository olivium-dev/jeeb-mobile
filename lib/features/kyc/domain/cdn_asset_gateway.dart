import 'dart:typed_data';

enum CdnUploadSlot {
  idDocumentFront,
  idDocumentBack,
  vehicleRegistration,
  selfieWithLiveness,

  /// JEBV4-200 (D3): the proof-of-delivery photo the jeeber captures at
  /// handover. Reuses the SAME shipped CDN streaming-proxy path as the KYC
  proofOfDelivery,

  /// P4/P5 (b01-20260725): an image attached inside the 1:1 chat (camera or
  /// gallery). Wire value `chat_attachment`; gateway
  chatAttachment,

  /// F5 (b08-20260808): the profile-picture change flow. Wire value
  /// `profile_avatar`; the gateway allowlist edit + public read route are a
  /// paired gateway PR — see that PR body for the exact contract.
  avatar,
}

abstract class CdnAssetGateway {
  Future<String> uploadAsset({
    required CdnUploadSlot slot,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  });

  Future<Uint8List> fetchAsset(String objectRef);
}

class CdnUploadException implements Exception {
  const CdnUploadException(this.message);

  final String message;

  @override
  String toString() => 'CdnUploadException: $message';
}

class CdnFetchException implements Exception {
  const CdnFetchException(this.message);

  final String message;

  @override
  String toString() => 'CdnFetchException: $message';
}
