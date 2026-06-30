import 'package:dio/dio.dart';

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
  const DioRequestSubmissionService(this._dio);

  final Dio _dio;

  static const String _path = '/v1/requests';

  @override
  Future<String> submit(RequestDraft draft) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _path,
        data: _buildBody(draft),
      );
      return _parseId(response.data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Map<String, dynamic> _buildBody(RequestDraft draft) {
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
