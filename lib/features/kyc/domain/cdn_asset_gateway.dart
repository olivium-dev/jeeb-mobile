import 'dart:typed_data';

import '../../../core/network/app_failure.dart';

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

  /// F5: profile-picture change flow. Wire value `profile_avatar`; the
  /// gateway allowlist + public read route are a paired gateway PR.
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

/// NET-13: the retry-safe upload. A caller that owns a multi-slot submission
/// mints ONE operation id so a replay reuses the same key per slot.
abstract class IdempotentCdnAssetGateway implements CdnAssetGateway {
  Future<String> uploadAssetIdempotent({
    required CdnUploadSlot slot,
    required Uint8List bytes,
    required String operationId,
    String contentType = 'image/jpeg',
  });
}

class CdnUploadException implements Exception {
  const CdnUploadException(this.message, {this.failure, this.status});

  /// A stable non-user-facing label (`cdn_broker_ticket`, `cdn_signed_put`).
  /// Never rendered — read [failure] for copy.
  final String message;

  /// The classified transport failure, when there was one.
  final AppFailure? failure;

  /// The HTTP status, which [ValidationFailure] itself does not carry — 413
  /// and 415 are the two the upload flows must tell apart.
  final int? status;

  @override
  String toString() => 'CdnUploadException: $message';
}

class CdnFetchException implements Exception {
  const CdnFetchException(this.message, {this.failure});

  /// A stable non-user-facing label. Never rendered.
  final String message;

  final AppFailure? failure;

  @override
  String toString() => 'CdnFetchException: $message';
}
