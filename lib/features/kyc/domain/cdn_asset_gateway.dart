import 'dart:typed_data';

/// Upload slots recognized by the gateway's CDN signed-PUT broker
/// (`POST /api/cdn/assets`). Wire values are the broker's `slot` enum
/// (`CdnController.AllowedUploadSlots`): `id_document_front`,
/// `id_document_back`, `vehicle_registration`, `selfie_with_liveness`,
/// `proof_of_delivery`.
enum CdnUploadSlot {
  idDocumentFront,
  idDocumentBack,
  vehicleRegistration,
  selfieWithLiveness,

  /// JEBV4-200 (D3): the proof-of-delivery photo the jeeber captures at
  /// handover. Reuses the SAME shipped CDN streaming-proxy path as the KYC
  /// slots (JEBV4-259 / PR #257) — only the broker allowlist entry differs.
  /// Wire value `proof_of_delivery`; gateway `CdnController.AllowedUploadSlots`
  /// must include it (companion one-line gateway change).
  proofOfDelivery,

  /// P4/P5 (b01-20260725): an image attached inside the 1:1 chat (camera or
  /// gallery). Wire value `chat_attachment`; gateway
  /// `CdnController.AllowedUploadSlots` must include it (companion one-line
  /// gateway change). cdn-service does NOT validate slots — it sanitizes the
  /// value and uses it as a storage directory — so no upstream change is
  /// needed.
  chatAttachment,
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

  /// Fetches the raw bytes of a previously-uploaded asset by its durable
  /// `object_ref`, through the AUTHENTICATED gateway read proxy
  /// (`GET /api/cdn/assets/content/{objectRef}`).
  ///
  /// Why not a signed URL: cdn-service exposes NO signed-download endpoint —
  /// the gateway's `GET /api/cdn/assets/{id}/signed-url` dials a route
  /// (`api/v1/assets/{id}/signed-url`) that does not exist upstream. The read
  /// proxy is the only working path (verified live on MSI 2026-07-25).
  Future<Uint8List> fetchAsset(String objectRef);
}

/// Thrown when the broker's upload-ticket response is missing a field the
/// upload flow needs (`upload_url` / `object_ref`).
class CdnUploadException implements Exception {
  const CdnUploadException(this.message);

  final String message;

  @override
  String toString() => 'CdnUploadException: $message';
}

/// Thrown when an asset READ through the gateway proxy fails — network error,
/// a 4xx/5xx from the proxy, or a 200 with an empty body.
class CdnFetchException implements Exception {
  const CdnFetchException(this.message);

  final String message;

  @override
  String toString() => 'CdnFetchException: $message';
}
