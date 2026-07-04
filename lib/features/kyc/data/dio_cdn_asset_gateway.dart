import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../domain/cdn_asset_gateway.dart';

/// Dio-backed [CdnAssetGateway].
///
/// Endpoint (gateway BFF signed-PUT broker, `docs/adr/0004-s03-kyc-service-
/// and-gateway-bff.md`):
///   POST /api/cdn/assets {slot, content_type}
///     → {upload_url, object_ref, expires_in}
/// followed by a direct `PUT` of the raw bytes to the returned `upload_url` —
/// an absolute signed URL, uploaded as-is rather than joined to the gateway
/// [Dio] instance's base path.
class DioCdnAssetGateway implements CdnAssetGateway {
  const DioCdnAssetGateway(this._dio);

  final Dio _dio;

  static const String _brokerPath = '/api/cdn/assets';

  @override
  Future<String> uploadAsset({
    required CdnUploadSlot slot,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final ticket = await _dio.post<Map<String, dynamic>>(
      _brokerPath,
      data: {
        'slot': _wireSlot(slot),
        'content_type': contentType,
      },
    );
    final body = ticket.data ?? const <String, dynamic>{};
    final uploadUrl = body['upload_url'] as String?;
    final objectRef = body['object_ref'] as String?;
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw const CdnUploadException(
        'Missing upload_url in /api/cdn/assets response',
      );
    }
    if (objectRef == null || objectRef.isEmpty) {
      throw const CdnUploadException(
        'Missing object_ref in /api/cdn/assets response',
      );
    }

    await _dio.put<void>(
      uploadUrl,
      data: bytes,
      options: Options(headers: {'Content-Type': contentType}),
    );

    return objectRef;
  }

  String _wireSlot(CdnUploadSlot slot) {
    switch (slot) {
      case CdnUploadSlot.idDocumentFront:
        return 'id_document_front';
      case CdnUploadSlot.idDocumentBack:
        return 'id_document_back';
      case CdnUploadSlot.vehicleRegistration:
        return 'vehicle_registration';
      case CdnUploadSlot.selfieWithLiveness:
        return 'selfie_with_liveness';
    }
  }
}
