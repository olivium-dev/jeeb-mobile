import 'dart:typed_data';

/// Upload slots recognized by the gateway's CDN signed-PUT broker
/// (`POST /api/cdn/assets`). Wire values are the broker's `slot` enum
/// (`CdnController.AllowedUploadSlots`): `id_document_front`,
/// `id_document_back`, `vehicle_registration`, `selfie_with_liveness`.
enum CdnUploadSlot {
  idDocumentFront,
  idDocumentBack,
  vehicleRegistration,
  selfieWithLiveness,
}

/// Client for the CDN signed-upload broker described in
/// `docs/adr/0004-s03-kyc-service-and-gateway-bff.md`:
///   1. `POST /api/cdn/assets {slot, content_type}` →
///      `{upload_url, object_ref, expires_in}` (no bytes sent yet).
///   2. `PUT` the raw bytes directly to `upload_url` — bytes never touch the
///      gateway.
///   3. The returned `object_ref` is the durable reference the caller sends
///      onward as the domain's `*_url` field (e.g. `id_document_front_url`).
abstract class CdnAssetGateway {
  /// Uploads [bytes] for [slot] and returns the durable `object_ref` to embed
  /// in a downstream submit body.
  Future<String> uploadAsset({
    required CdnUploadSlot slot,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  });
}

/// Thrown when the broker's upload-ticket response is missing a field the
/// upload flow needs (`upload_url` / `object_ref`).
class CdnUploadException implements Exception {
  const CdnUploadException(this.message);

  final String message;

  @override
  String toString() => 'CdnUploadException: $message';
}
