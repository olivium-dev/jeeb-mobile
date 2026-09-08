import 'package:dio/dio.dart';

import '../../../core/idempotency/operation_id.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/gateway_problem.dart';
import '../domain/offer_submission_repository.dart';

class DioOfferSubmissionRepository
    implements OfferSubmissionRepository, IdempotentOfferSubmission {
  const DioOfferSubmissionRepository(this._dio, {OperationIdFactory? newKey})
    : _newKey = newKey ?? newOperationId;

  final Dio _dio;

  /// Seam so a test can pin the minted key; the composer normally supplies its
  /// own draft-scoped key through [submitOfferIdempotent].
  final OperationIdFactory _newKey;

  /// The live request-scoped submit path (BUG-2 corrected route):
  static String _pathFor(String requestId) => '/requests/$requestId/offers';

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) {
    return submitOfferIdempotent(
      requestId: requestId,
      priceUsd: priceUsd,
      etaMinutes: etaMinutes,
      idempotencyKey: _newKey(),
      note: note,
    );
  }

  @override
  Future<OfferSubmissionResult> submitOfferIdempotent({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    required String idempotencyKey,
    String? note,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _pathFor(requestId),
        data: _buildBody(priceUsd, etaMinutes, note),
        options: Options(
          headers: <String, dynamic>{'Idempotency-Key': idempotencyKey},
        ),
      );
      return _parseResult(response.data, requestId);
    } on OfferSubmissionException {
      rethrow;
    } on DioException catch (e) {
      throw _map(AppFailure.of(e), e.response?.statusCode, e.response?.data);
    } catch (e) {
      throw OfferSubmissionException(
        OfferSubmissionFailure.server,
        cause: AppFailure.of(e),
      );
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
    final offerId = (data?['id'] as String?) ?? (data?['offerId'] as String?);
    // A 201 that names no offer is not a submitted offer; never report success.
    if (offerId == null || offerId.trim().isEmpty) {
      throw const OfferSubmissionException(
        OfferSubmissionFailure.server,
        cause: UnknownFailure(parse: true),
      );
    }
    final rawConversationId = (data?['conversationId'] as String?)?.trim();
    final conversationId =
        (rawConversationId != null && rawConversationId.isNotEmpty)
        ? rawConversationId
        : requestId;
    return OfferSubmissionResult(
      offerId: offerId,
      conversationId: conversationId,
    );
  }

  /// Machine `typeSuffix` only — the retired substring heuristic matched `'20'`
  /// inside a GUID and reported a cap that no longer exists (AE-05/UX-12).
  OfferSubmissionException _map(AppFailure f, [int? status, Object? raw]) {
    final GatewayProblem? p = f.problem;
    final String? suffix = p?.typeSuffix;

    // 402 has no AppFailure subtype: an empty body leaves nothing but the
    // transport status to read it from.
    if (status == 402 || p?.status == 402 || suffix == 'insufficient-balance') {
      return OfferSubmissionException(
        OfferSubmissionFailure.insufficientBalance,
        balance: _parseBalance(p, raw),
        cause: f,
      );
    }
    return switch (f) {
      ValidationFailure() => OfferSubmissionException(switch (suffix) {
        'offer-fee-too-low' => OfferSubmissionFailure.feeTooLow,
        'offer-eta-invalid' => OfferSubmissionFailure.etaInvalid,
        'offer-note-too-long' => OfferSubmissionFailure.noteTooLong,
        _ => OfferSubmissionFailure.invalidInput,
      }, cause: f),
      ConflictFailure() => OfferSubmissionException(switch (suffix) {
        'offer-already-exists' => OfferSubmissionFailure.duplicateOffer,
        'same-delivery-role-violation' =>
          OfferSubmissionFailure.sameRoleViolation,
        'offer-out-of-range' => OfferSubmissionFailure.outOfRange,
        'request-not-open-for-offers' => OfferSubmissionFailure.requestNotOpen,
        _ => OfferSubmissionFailure.requestGone,
      }, cause: f),
      GoneFailure() || NotFoundFailure() => OfferSubmissionException(
        OfferSubmissionFailure.requestGone,
        cause: f,
      ),
      NetworkFailure() || TimeoutFailure() => OfferSubmissionException(
        OfferSubmissionFailure.network,
        cause: f,
      ),
      _ => OfferSubmissionException(OfferSubmissionFailure.server, cause: f),
    };
  }

  /// Each figure stays null when the body omits it (UX-15). A 402 that is not
  /// a problem document still carries the figures, so the raw map is read too.
  InsufficientBalanceInfo? _parseBalance(GatewayProblem? p, Object? raw) {
    final map = raw is Map ? raw : const <Object?, Object?>{};
    final needed = p?.needed ?? _double(map['needed']);
    final available = p?.available ?? _double(map['available']);
    final currency = p?.currency ?? _string(map['currency']);
    if (needed == null && available == null && currency == null) return null;
    return InsufficientBalanceInfo(
      needed: needed,
      available: available,
      currency: currency,
    );
  }

  static double? _double(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  static String? _string(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }
}
