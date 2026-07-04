import 'package:dio/dio.dart';

import '../domain/recipient_phone_resolver.dart';
import '../domain/request_draft.dart';
import '../domain/request_submission_service.dart';

/// Dio-backed [RequestSubmissionService] — POSTs the assembled draft to the
/// gateway create-request RPC and returns the server-minted request id.
///
/// Endpoint contract — the canonical gateway create-request path. Verified
/// LIVE against the dev gateway (`http://192.168.2.39:10090`):
///   POST /v1/requests  → 201 { id, clientId, status:"pending", ... }
/// `description` is the only required field; `tierId` + locations are optional.
/// `/v1/requests` (not the un-prefixed `/requests`) is used because it is the
/// path the rest of the app speaks AND the only one the local-mock
/// `MockGatewayClient` rewrites to `/delivery-service/v1/requests` — so the
/// same code creates a request against both the live gateway and the mock.
class DioRequestSubmissionService implements RequestSubmissionService {
  const DioRequestSubmissionService(this._dio, this._recipientPhoneResolver);

  final Dio _dio;

  /// Resolves the DEFAULT recipient phone (signed-in client's own profile
  /// phone, E.164) when the compose flow captured none. Reuses the existing
  /// [RecipientPhoneResolver] chain (ChainedRecipientPhoneResolver →
  /// SharedPrefsRecipientPhoneResolver / DioRecipientPhoneResolver). Best-effort:
  /// [RecipientPhoneResolver.resolve] never throws and may return null, in which
  /// case the create simply omits the optional `recipientPhone`.
  final RecipientPhoneResolver _recipientPhoneResolver;

  static const String _path = '/v1/requests';

  @override
  Future<String> submit(RequestDraft draft) async {
    try {
      // BUG-7: the gateway request-store row needs a non-null `recipientPhone`
      // or the at-door handover OTP issue/verify short-circuits with
      // 400 `recipient-phone-missing` before the code is ever evaluated. The
      // explicit compose-form phone wins; otherwise fall back to the resolver
      // default (the signed-in client's own profile phone, in E.164).
      final phone = await _resolveRecipientPhone(draft);
      final response = await _dio.post<Map<String, dynamic>>(
        _path,
        data: _buildBody(draft, phone),
      );
      return _parseId(response.data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// The explicit draft phone when present, else the resolver default. Returns
  /// null only when the compose flow captured none AND the resolver chain
  /// misses every source (then the create omits the optional field as before).
  Future<String?> _resolveRecipientPhone(RequestDraft draft) async {
    final fromDraft = draft.recipientPhone?.trim();
    if (fromDraft != null && fromDraft.isNotEmpty) return fromDraft;
    return _recipientPhoneResolver.resolve();
  }

  Map<String, dynamic> _buildBody(RequestDraft draft, String? phone) {
    return <String, dynamic>{
      'description': draft.description,
      if (draft.transcription != null) 'transcription': draft.transcription,
      if (draft.audioUrl != null) 'audioUrl': draft.audioUrl,
      'photos': draft.photoUrls,
      if (draft.tierId != null) 'tierId': draft.tierId,
      ..._location('pickup', draft.pickupLat, draft.pickupLng),
      ..._location('dropoff', draft.dropoffLat, draft.dropoffLng),
      if (draft.pickupAddress != null) 'pickupAddress': draft.pickupAddress,
      if (draft.dropoffAddress != null) 'dropoffAddress': draft.dropoffAddress,
      if (phone != null && phone.isNotEmpty) 'recipientPhone': phone,
    };
  }

  Map<String, dynamic> _location(String prefix, double? lat, double? lng) {
    if (lat == null || lng == null) return const <String, dynamic>{};
    return <String, dynamic>{
      '${prefix}Location': <String, double>{'lat': lat, 'lng': lng},
    };
  }

  String _parseId(Map<String, dynamic>? data) {
    final id = data?['id'] as String?;
    if (id == null || id.isEmpty) {
      throw const RequestSubmissionException(
        RequestSubmissionFailure.server,
        'missing id in 201 response',
      );
    }
    return id;
  }

  RequestSubmissionException _mapDioError(DioException e) {
    if (_isNetwork(e.type)) {
      return const RequestSubmissionException(RequestSubmissionFailure.network);
    }
    final status = e.response?.statusCode;
    // JEBV4-108: a 401 at the create seam is a SESSION failure, not a payload
    // problem — surface it as its own typed case so the UI can route to
    // re-auth instead of showing a misleading generic/connectivity error.
    // (Note: the TokenRefreshInterceptor has already had its single refresh
    // attempt by the time this surfaces, so this 401 is terminal.)
    if (status == 401) {
      return const RequestSubmissionException(
        RequestSubmissionFailure.unauthorized,
        'HTTP 401',
      );
    }
    if (status != null && status >= 400 && status < 500) {
      return RequestSubmissionException(
        RequestSubmissionFailure.invalidInput,
        'HTTP $status',
      );
    }
    return RequestSubmissionException(
      RequestSubmissionFailure.server,
      'HTTP $status',
    );
  }

  bool _isNetwork(DioExceptionType type) =>
      type == DioExceptionType.connectionError ||
      type == DioExceptionType.connectionTimeout ||
      type == DioExceptionType.sendTimeout ||
      type == DioExceptionType.receiveTimeout;
}
