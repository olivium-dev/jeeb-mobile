import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../domain/cdn_asset_gateway.dart';

/// Dio-backed [CdnAssetGateway].
///
/// Two-step CDN signed-PUT broker (ADR-0004 / JEBV4-259 "approach B" — the
/// gateway now proxies the KYC-photo PUT to cdn-service internally and returns
/// an ABSOLUTE, gateway-hosted upload URL):
///   1. `POST /api/cdn/assets {slot, content_type}` on the SHARED authenticated
///      gateway [Dio] (this call legitimately needs the Bearer token) →
///      `{upload_url, object_ref, expires_in, method, required_headers}`.
///      `upload_url` is ALWAYS absolute; `method` + `required_headers` are the
///      exact verb + headers the signed-PUT must carry (`required_headers`
///      always includes `Content-Type`).
///   2. Upload the RAW bytes with `method` to the absolute `upload_url`,
///      carrying `required_headers` verbatim — through a DEDICATED,
///      interceptor-free [Dio] (see [_bareUploadDio]). The shared gateway Dio
///      carries a Bearer-auth interceptor, diagnostic/redacting log
///      interceptors, a gateway `baseUrl`, and a default
///      `Content-Type: application/json`; routing the binary PUT through it is
///      exactly what attached auth/JSON headers and (for a relative URL)
///      redirected the request back at the gateway edge — the JEBV4-259 415.
///      The dedicated client has NONE of those: no interceptors, no baseUrl, no
///      JSON default, no `Authorization` header.
///   3. Return `object_ref` for the caller to embed as the domain `*_url` field.
class DioCdnAssetGateway implements CdnAssetGateway {
  DioCdnAssetGateway(this._brokerDio, {Dio? uploadDio})
      : _uploadDio = uploadDio ?? _bareUploadDio();

  /// The SHARED authenticated gateway client — used ONLY for the broker POST.
  final Dio _brokerDio;

  /// The DEDICATED, interceptor-free client — used ONLY for the signed-PUT of
  /// the raw bytes. Never the shared client.
  final Dio _uploadDio;

  static const String _brokerPath = '/api/cdn/assets';

  /// P4/P5: the AUTHENTICATED gateway read proxy for a brokered asset
  /// (`GET /api/cdn/assets/content/{**objectPath}`). The only working read
  /// path — see [CdnAssetGateway.fetchAsset].
  static const String _contentPath = '/api/cdn/assets/content';

  /// Bounded timeouts for the signed-PUT so a STALLED CDN upload fails fast
  /// instead of hanging the KYC "submitting" spinner forever (JEBV4-259 latent
  /// bug): the raw [Dio] previously carried NO timeouts, so a half-open socket
  /// mid-upload blocked `DioKycGateway.submit()` — and therefore the whole KYC
  /// wizard — unbounded (the ~98s spinner an on-device jeeber saw). The image
  /// PUT is a SEND, so [_sendTimeout] is the load-bearing one — note the shared
  /// gateway Dio sets connect/receive but NO send timeout — with connect +
  /// receive bounded too. Values are generous for a compressed ID photo on a
  /// slow link yet finite, so a genuine stall surfaces as a [CdnUploadException]
  /// (→ retryable submit error) rather than an infinite hang.
  static const Duration _connectTimeout = Duration(seconds: 20);
  static const Duration _sendTimeout = Duration(seconds: 30);
  static const Duration _receiveTimeout = Duration(seconds: 30);

  /// A fresh [Dio] with NO `baseUrl` and NO interceptors — Dio's default
  /// [ImplyContentTypeInterceptor] is removed too — so nothing can mutate the
  /// binary body or attach auth / `Content-Type: application/json` headers.
  /// It DOES carry bounded connect/send/receive timeouts so a stalled upload
  /// can never hang the submit indefinitely.
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

  /// The dedicated upload client, exposed so tests can assert it is
  /// interceptor-free and distinct from the shared broker client.
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

  /// Brokers the signed-PUT ticket on the shared authenticated Dio.
  Future<_CdnUploadTicket> _brokerTicket(
    CdnUploadSlot slot,
    String contentType,
  ) async {
    final res = await _brokerDio.post<Map<String, dynamic>>(
      _brokerPath,
      data: {'slot': _wireSlot(slot), 'content_type': contentType},
    );
    return _CdnUploadTicket.fromBroker(
      res.data ?? const <String, dynamic>{},
      fallbackContentType: contentType,
    );
  }

  /// PUTs [bytes] verbatim through the dedicated interceptor-free Dio.
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
      // Surface non-2xx as a domain error below rather than a DioException.
      validateStatus: (_) => true,
      // Per-request bound so a stalled PUT fails fast even when a caller injects
      // a custom upload Dio without timeouts on its BaseOptions (connectTimeout
      // lives only on BaseOptions — see [_bareUploadDio]).
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
    }
  }

  @override
  Future<Uint8List> fetchAsset(String objectRef) async {
    if (objectRef.trim().isEmpty) {
      throw const CdnFetchException('Empty object_ref');
    }
    try {
      // The SHARED authenticated Dio: this read legitimately needs the Bearer
      // (the gateway read proxy is capability-gated — it is deliberately NOT a
      // [PublicEndpoint], unlike the HMAC-signed PUT). `ResponseType.bytes`
      // bypasses the JSON response transformer; the binary body is never
      // logged (see the `List<int>` guard in `RedactingLogInterceptor`).
      //
      // `objectRef` is a cdn-minted slug (`chat_attachment/<32-hex>.jpg`); its
      // `/` must stay a PATH SEPARATOR so the gateway's `content/{**objectPath}`
      // catch-all binds it. Do NOT percent-encode it here — the gateway does
      // the single-segment encoding cdn-service's fetch route requires.
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

/// Parsed `POST /api/cdn/assets` response — the signed-PUT instructions the
/// dedicated upload client replays verbatim.
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
      contentType:
          _headerValue(headers, 'Content-Type') ?? fallbackContentType,
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

  /// `required_headers` verbatim; falls back to just `Content-Type` for an
  /// older gateway that omits the field (it now always includes it).
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
