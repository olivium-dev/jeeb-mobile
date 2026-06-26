import 'package:dio/dio.dart';

import '../domain/recipient_phone_resolver.dart';
import '../domain/request_draft.dart';
import '../domain/request_submission_service.dart';

/// Dio-backed [RequestSubmissionService] — POSTs the assembled draft to the
/// gateway create-request RPC and returns the server-minted request id.
///
/// Endpoint contract (jeeb-gateway `JeebRequestsController.Create`):
///   POST /v1/requests  → 201 { id, status, ... }
/// The `MockGatewayClient` rewrite map maps `/v1/requests` →
/// `/delivery-service/v1/requests` for the :4010 Express mock; the bare
/// `/requests` gateway controller this replaces is [Obsolete].
///
/// T-BE-019 / JEB-55 (compose recipient-phone): the body now carries
/// `recipientPhone` so the gateway request-store row gets a non-null
/// `RecipientPhone`. The gateway OTP issue/verify path reads the phone from
/// THAT store row (not the delivery-service row), so without it the at-door
/// `POST /deliveries/{id}/otp/verify {code:"1234"}` returns 400
/// `recipient-phone-missing`. The compose flow does not (yet) prompt for a
/// recipient phone, so we default to the signed-in client's own profile phone
/// via [_phoneResolver] — the requester is the default recipient. The field is
/// additive and optional end-to-end (the gateway `CreateRequestBody.RecipientPhone`
/// is nullable), so omitting it keeps today's behaviour.
class DioRequestSubmissionService implements RequestSubmissionService {
  const DioRequestSubmissionService(
    this._dio, {
    RecipientPhoneResolver? phoneResolver,
  }) : _phoneResolver = phoneResolver;

  final Dio _dio;

  /// Resolves the DEFAULT recipient phone (the signed-in client's own phone)
  /// when the [RequestDraft] does not carry one. Null in tests / call sites
  /// that always supply an explicit draft phone — then no fallback is attempted.
  final RecipientPhoneResolver? _phoneResolver;

  static const String _path = '/v1/requests';

  @override
  Future<String> submit(RequestDraft draft) async {
    try {
      final recipientPhone = await _resolveRecipientPhone(draft);
      final response = await _dio.post<Map<String, dynamic>>(
        _path,
        data: _buildBody(draft, recipientPhone),
      );
      return _parseId(response.data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  /// The draft phone wins; otherwise fall back to the signed-in client's own
  /// profile phone. A resolver failure (offline / no profile) degrades to null
  /// — the create must NEVER fail just because the default recipient phone
  /// could not be resolved (the gateway field is optional; only the at-door OTP
  /// needs it).
  Future<String?> _resolveRecipientPhone(RequestDraft draft) async {
    final fromDraft = _normalize(draft.recipientPhone);
    if (fromDraft != null) return fromDraft;
    final resolver = _phoneResolver;
    if (resolver == null) return null;
    try {
      return _normalize(await resolver.resolve());
    } catch (_) {
      return null;
    }
  }

  String? _normalize(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Map<String, dynamic> _buildBody(RequestDraft draft, String? recipientPhone) {
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
      'recipientPhone': ?recipientPhone,
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
