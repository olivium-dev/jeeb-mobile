import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/idempotency/operation_id.dart';
import '../domain/cdn_asset_gateway.dart';

/// Dio-backed [CdnAssetGateway].
class DioCdnAssetGateway implements CdnAssetGateway {
  DioCdnAssetGateway(this._brokerDio, {Dio? uploadDio})
    : _uploadDio = uploadDio ?? _bareUploadDio();

  final Dio _brokerDio;

  final Dio _uploadDio;

  static const String _brokerPath = '/api/cdn/assets';

  static const String _contentPath = '/api/cdn/assets/content';

  static const Duration _connectTimeout = Duration(seconds: 20);
  static const Duration _sendTimeout = Duration(seconds: 30);
  static const Duration _receiveTimeout = Duration(seconds: 30);

  static Dio _bareUploadDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: _connectTimeout,
        sendTimeout: _sendTimeout,
        receiveTimeout: _receiveTimeout,
      ),
    );
    dio.interceptors.clear(keepImplyContentTypeInterceptor: false);
    return dio;
  }

  @visibleForTesting
  Dio get uploadDio => _uploadDio;

  @override
  Future<String> uploadAsset({
    required CdnUploadSlot slot,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final ticket = await _brokerTicket(slot, contentType);
    await _putBytes(ticket: ticket, bytes: bytes, slot: slot);
    return ticket.objectRef;
  }

  Future<_CdnUploadTicket> _brokerTicket(
    CdnUploadSlot slot,
    String contentType,
  ) async {
    try {
      final res = await _brokerDio.post<Map<String, dynamic>>(
        _brokerPath,
        data: {'slot': _wireSlot(slot), 'content_type': contentType},
        options: Options(
          headers: <String, Object?>{'Idempotency-Key': newOperationId()},
        ),
      );
      return _CdnUploadTicket.fromBroker(
        res.data ?? const <String, dynamic>{},
        fallbackContentType: contentType,
      );
    } on DioException catch (e) {
      throw CdnUploadException(
        'CDN broker ticket failed for ${_wireSlot(slot)}: ${e.message}',
      );
    }
  }

  Future<void> _putBytes({
    required _CdnUploadTicket ticket,
    required Uint8List bytes,
    required CdnUploadSlot slot,
  }) async {
    try {
      final res = await _uploadDio.request<void>(
        ticket.uploadUrl, // absolute — baseUrl is ignored, used verbatim
        data: bytes, // raw Uint8List — Dio 5.x sends binary data untransformed
        options: _putOptions(ticket),
      );
      _ensure2xx(res.statusCode ?? 0, slot);
    } on DioException catch (e) {
      throw CdnUploadException(
        'CDN signed-PUT failed for ${_wireSlot(slot)}: ${e.message}',
      );
    }
  }

  static Options _putOptions(_CdnUploadTicket ticket) {
    return Options(
      method: ticket.method,
      headers: ticket.headers, // required_headers, verbatim
      contentType: ticket.contentType, // e.g. image/jpeg — never JSON
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
      sendTimeout: _sendTimeout,
      receiveTimeout: _receiveTimeout,
    );
  }

  void _ensure2xx(int status, CdnUploadSlot slot) {
    if (status < 200 || status >= 300) {
      throw CdnUploadException(
        'CDN signed-PUT returned $status for ${_wireSlot(slot)}',
      );
    }
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
      case CdnUploadSlot.proofOfDelivery:
        return 'proof_of_delivery';
      case CdnUploadSlot.chatAttachment:
        return 'chat_attachment';
      case CdnUploadSlot.avatar:
        return 'profile_avatar';
    }
  }

  @override
  Future<Uint8List> fetchAsset(String objectRef) async {
    if (objectRef.trim().isEmpty) {
      throw const CdnFetchException('Empty object_ref');
    }
    try {
      // `/` must stay a PATH SEPARATOR so the gateway's `content/{**objectPath}`
      final res = await _brokerDio.get<List<int>>(
        '$_contentPath/$objectRef',
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: _receiveTimeout,
        ),
      );
      final data = res.data;
      if (data == null || data.isEmpty) {
        throw const CdnFetchException('Empty asset body');
      }
      return Uint8List.fromList(data);
    } on DioException catch (e) {
      throw CdnFetchException('CDN fetch failed for $objectRef: ${e.message}');
    }
  }
}

class _CdnUploadTicket {
  const _CdnUploadTicket({
    required this.uploadUrl,
    required this.objectRef,
    required this.method,
    required this.headers,
    required this.contentType,
  });

  factory _CdnUploadTicket.fromBroker(
    Map<String, dynamic> body, {
    required String fallbackContentType,
  }) {
    final headers = _resolveHeaders(body, fallbackContentType);
    return _CdnUploadTicket(
      uploadUrl: _requireField(body, 'upload_url'),
      objectRef: _requireField(body, 'object_ref'),
      method: _resolveMethod(body),
      headers: headers,
      contentType: _headerValue(headers, 'Content-Type') ?? fallbackContentType,
    );
  }

  final String uploadUrl;
  final String objectRef;
  final String method;
  final Map<String, String> headers;
  final String contentType;

  static String _requireField(Map<String, dynamic> body, String key) {
    final value = (body[key] as String?) ?? '';
    if (value.isEmpty) {
      throw CdnUploadException('Missing $key in /api/cdn/assets response');
    }
    return value;
  }

  static String _resolveMethod(Map<String, dynamic> body) {
    final method = (body['method'] as String?)?.trim();
    return (method == null || method.isEmpty) ? 'PUT' : method.toUpperCase();
  }

  static Map<String, String> _resolveHeaders(
    Map<String, dynamic> body,
    String fallbackContentType,
  ) {
    final headers = _stringMap(body['required_headers']);
    if (headers.isEmpty) {
      return <String, String>{'Content-Type': fallbackContentType};
    }
    return headers;
  }

  static String? _headerValue(Map<String, String> headers, String name) {
    final lower = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }

  static Map<String, String> _stringMap(Object? raw) {
    if (raw is Map) {
      return raw.map((key, value) => MapEntry('$key', '$value'));
    }
    return const <String, String>{};
  }
}
