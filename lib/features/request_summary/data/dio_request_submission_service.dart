import 'package:dio/dio.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../domain/recipient_phone_resolver.dart';
import '../domain/request_draft.dart';
import '../domain/request_submission_service.dart';
import 'chained_recipient_phone_resolver.dart';

class DioRequestSubmissionService implements RequestSubmissionService {
  const DioRequestSubmissionService(this._dio, this._recipientPhoneResolver);

  final Dio _dio;

  final RecipientPhoneResolver _recipientPhoneResolver;

  static const String _path = '/v1/requests';

  @override
  Future<String> submit(RequestDraft draft) async {
    try {
      final phone = await _resolveRecipientPhone(draft);
      final RequestDraft posted = _markLookup(draft, phone);
      final response = await _dio.post<Map<String, dynamic>>(
        _path,
        data: _buildBody(posted, phone),
        options: Options(
          headers: <String, dynamic>{
            if (draft.operationId != null) 'Idempotency-Key': draft.operationId,
          },
        ),
      );
      return _parseId(response.data);
    } on DioException catch (e) {
      throw _mapFailure(AppFailure.of(e));
    }
  }

  /// A null phone after a delegate threw is "we could not read one", not
  /// "the user has none" — record that instead of guessing.
  RequestDraft _markLookup(RequestDraft draft, String? phone) {
    final resolver = _recipientPhoneResolver;
    if (phone != null && phone.isNotEmpty) return draft;
    if (resolver is! ChainedRecipientPhoneResolver) return draft;
    if (!resolver.lastResolveErrored) return draft;
    Diag.event('request_submit_recipient_phone_unknown');
    return draft.copyWith(recipientPhoneLookupFailed: true);
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
      throw const RequestSubmissionException.classified(
        RequestSubmissionFailure.server,
        appFailure: UnknownFailure(parse: true),
      );
    }
    return id;
  }

  /// Classifies a create failure. Only Network/Timeout may blame connectivity;
  /// the 409 moderation suffixes become their own exception.
  RequestSubmissionException _mapFailure(AppFailure f) {
    final String? suffix = f.problem?.typeSuffix;
    if (f is ConflictFailure && suffix == 'prohibited-item-requires-ack') {
      return RequestModerationRequired(
        matches: f.problem!.matches,
        appFailure: f,
      );
    }
    if (f is ConflictFailure && suffix == 'prohibited-item-blocked') {
      return RequestModerationRequired(
        matches: f.problem!.matches,
        blocked: true,
        appFailure: f,
      );
    }
    return RequestSubmissionException.classified(
      switch (f) {
        UnauthorizedFailure() => RequestSubmissionFailure.unauthorized,
        ValidationFailure() => RequestSubmissionFailure.invalidInput,
        NetworkFailure() || TimeoutFailure() => RequestSubmissionFailure.network,
        _ => RequestSubmissionFailure.server,
      },
      appFailure: f,
    );
  }
}
