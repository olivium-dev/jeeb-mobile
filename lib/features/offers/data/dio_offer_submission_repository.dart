import 'package:dio/dio.dart';

import '../domain/offer_submission_repository.dart';

/// Dio-backed [OfferSubmissionRepository].
///
/// Endpoint contract (mock gateway `/v1/offers` → :4010
/// `/offer-service/v1/offers`, `MockGatewayClient`):
///   POST /v1/offers
///   body: { requestId, priceUsd, etaMinutes, note }
///   201 → { offerId, conversationId, … } (10% reserved, D1)
///   402 → { type, title, status, detail, needed, available, currency } (O1) —
///         insufficient balance; mapped to [OfferSubmissionFailure.
///         insufficientBalance] + [InsufficientBalanceInfo] (JM-046)
///   409 → request already claimed (race)
///   422 → validation echo
class DioOfferSubmissionRepository implements OfferSubmissionRepository {
  const DioOfferSubmissionRepository(this._dio);

  final Dio _dio;

  static const String _path = '/v1/offers';

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _path,
        data: _buildBody(requestId, priceUsd, etaMinutes, note),
      );
      return _parseResult(response.data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Map<String, dynamic> _buildBody(
    String requestId,
    double priceUsd,
    int etaMinutes,
    String? note,
  ) {
    return {
      'requestId': requestId,
      'priceUsd': priceUsd,
      'etaMinutes': etaMinutes,
      if (note != null && note.isNotEmpty) 'note': note,
    };
  }

  OfferSubmissionResult _parseResult(Map<String, dynamic>? data) {
    final offerId = data?['offerId'] as String? ?? '';
    final conversationId = data?['conversationId'] as String? ?? '';
    return OfferSubmissionResult(
      offerId: offerId,
      conversationId: conversationId,
    );
  }

  OfferSubmissionException _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    // 402 (O1) is the insufficient-balance signal — NOT a generic error. Parse
    // {needed, available, currency} for the JM-046 sheet (42_GUARDRAILS_MOCK
    // §5.1). Defensive parse (40_GUARDRAILS_ARCH §4): tolerate snake_case and a
    // missing/malformed body (the cubit still surfaces the sheet; amounts fall
    // back to 0 / the wallet source).
    if (status == 402) {
      return OfferSubmissionException(
        OfferSubmissionFailure.insufficientBalance,
        balance: _parseBalance(e.response?.data),
      );
    }
    if (status == 409) {
      return const OfferSubmissionException(OfferSubmissionFailure.requestGone);
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const OfferSubmissionException(OfferSubmissionFailure.network);
    }
    return OfferSubmissionException(
      OfferSubmissionFailure.server,
      message: 'HTTP $status',
    );
  }

  InsufficientBalanceInfo? _parseBalance(Object? data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    return InsufficientBalanceInfo(
      needed: _num(map['needed'] ?? map['needed_amount']),
      available: _num(map['available'] ?? map['available_balance']),
      currency: _str(map['currency']) ?? 'USD',
    );
  }

  double _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}
