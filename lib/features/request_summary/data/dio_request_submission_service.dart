import 'package:dio/dio.dart';

import '../domain/recipient_phone_resolver.dart';
import '../domain/request_draft.dart';
import '../domain/request_submission_service.dart';

class DioRequestSubmissionService implements RequestSubmissionService {
  const DioRequestSubmissionService(this._dio, this._recipientPhoneResolver);

  final Dio _dio;

  final RecipientPhoneResolver _recipientPhoneResolver;

  static const String _path = '/v1/requests';

  @override
  Future<String> submit(RequestDraft draft) async {
    try {
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
