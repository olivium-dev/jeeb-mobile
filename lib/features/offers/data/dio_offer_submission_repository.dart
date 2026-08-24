import 'package:dio/dio.dart';

import '../domain/offer_submission_repository.dart';

class DioOfferSubmissionRepository implements OfferSubmissionRepository {
  const DioOfferSubmissionRepository(this._dio);

  final Dio _dio;

  /// The live request-scoped submit path (BUG-2 corrected route):
  static String _pathFor(String requestId) => '/requests/$requestId/offers';

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _pathFor(requestId),
        data: _buildBody(priceUsd, etaMinutes, note),
      );
      return _parseResult(response.data, requestId);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Map<String, dynamic> _buildBody(
    double priceUsd,
    int etaMinutes,
    String? note,
  ) {
    return {
      'fee': priceUsd,
      'etaMinutes': etaMinutes,
      if (note != null && note.isNotEmpty) 'note': note,
    };
  }

  OfferSubmissionResult _parseResult(
    Map<String, dynamic>? data,
    String requestId,
  ) {
    final offerId =
        (data?['id'] as String?) ?? (data?['offerId'] as String?) ?? '';
    final rawConversationId = (data?['conversationId'] as String?)?.trim();
    final conversationId = (rawConversationId != null &&
            rawConversationId.isNotEmpty)
        ? rawConversationId
        : requestId;
    return OfferSubmissionResult(
      offerId: offerId,
      conversationId: conversationId,
    );
  }

  OfferSubmissionException _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final type = _typeOf(data);
    // {needed, available, currency} for the JM-046 sheet (42_GUARDRAILS_MOCK
    if (status == 402) {
      return OfferSubmissionException(
        OfferSubmissionFailure.insufficientBalance,
        balance: _parseBalance(data),
      );
    }
    if (status == 403 && type == kWalletGuardTypeHolderUnresolved) {
      return const OfferSubmissionException(
        OfferSubmissionFailure.holderUnresolved,
      );
    }
    if (status == 503 && type == kWalletGuardTypeFeeUnresolvable) {
      return const OfferSubmissionException(
        OfferSubmissionFailure.feeUnresolvable,
      );
    }
    if (status == 503 && type == kWalletGuardTypeExposureUnresolvable) {
      return const OfferSubmissionException(
        OfferSubmissionFailure.exposureUnresolvable,
      );
    }
    if (status == 409 && type == kWalletGuardTypeOfferLiveLimitReached) {
      return OfferSubmissionException(
        OfferSubmissionFailure.offerCapReached,
        capInfo: _parseCapInfo(data),
      );
    }
    if (status == 409 && _isOfferCap(data)) {
      return const OfferSubmissionException(
        OfferSubmissionFailure.offerCapReached,
      );
    }
    if (status == 404 || status == 409 || status == 410) {
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

  /// (40_GUARDRAILS_ARCH §4). The cap reads like `offer-cap-reached` /
  bool _isOfferCap(Object? data) {
    if (data is! Map) return false;
    final haystack = [
      data['type'],
      data['code'],
      data['title'],
      data['detail'],
      data['error'],
    ].whereType<String>().map((s) => s.toLowerCase()).join(' ');
    if (haystack.contains('not-open') || haystack.contains('not_open')) {
      return false;
    }
    return haystack.contains('cap') ||
        haystack.contains('too-many') ||
        haystack.contains('too_many') ||
        haystack.contains('limit') ||
        haystack.contains('maximum') ||
        haystack.contains('20');
  }

  /// Exact-equality discriminator (CONTRACT §1): trim only, no lowercase.
  static String? _typeOf(Object? data) {
    if (data is! Map) return null;
    final raw = data['type'];
    return raw is String ? raw.trim() : null;
  }

  OfferCapInfo? _parseCapInfo(Object? data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    return OfferCapInfo(
      limit: _intOrNull(map['limit']),
      live: _intOrNull(map['live']),
    );
  }

  InsufficientBalanceInfo? _parseBalance(Object? data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    return InsufficientBalanceInfo(
      needed: _num(map['needed'] ?? map['needed_amount']),
      available: _num(map['available'] ?? map['available_balance']),
      currency: _str(map['currency']) ?? '',
      thisOffer: _numOrNull(map['thisOffer']),
      outstanding: _numOrNull(map['outstanding']),
    );
  }

  double _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  /// Absent / unparseable stays null so the sheet can hide the row.
  double? _numOrNull(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  int? _intOrNull(Object? v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}
