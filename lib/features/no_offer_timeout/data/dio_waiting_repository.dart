import 'package:dio/dio.dart';

import '../domain/waiting_repository.dart';
import '../domain/waiting_request.dart';

/// Dio-backed [WaitingRepository] hitting the mock (jeeb-gateway in prod).
///
/// Endpoints (30_BACKLOG JM-026 · 42_GUARDRAILS_MOCK §1.2; the
/// [MockGatewayClient] interceptor rewrites the `:4010` service prefix):
///   GET /v1/requests/:requestId      → `/delivery-service/v1/requests/:id`
///                                      (status, notifiedCount, broadcastExpiresAt)
///   GET /v1/offers?requestId=:id     → `/offer-service/v1/offers?requestId=:id`
///                                      (offer count — the offers-arrived signal)
///
/// Two reads so the offers-arrived transition (AC2) is authoritative even if
/// the request row's denormalised `offersCount` lags a poll. The offers read is
/// best-effort: a transient failure there falls back to the request row's
/// `offersCount`, so the countdown/notified-count never blocks on it.
///
/// The matching broadcast (`POST /v1/matching/broadcast`,
/// `POST /v1/matching/find-jeebers`) is fired by the create-flow (JM-024/025)
/// BEFORE the user lands here — the seam seeds an already-broadcasting request.
/// This screen only READS the resulting state, so it does not re-broadcast.
class DioWaitingRepository implements WaitingRepository {
  const DioWaitingRepository(this._dio);

  final Dio _dio;

  static const _requestsPath = '/v1/requests';
  static const _offersPath = '/v1/offers';

  // Gateway omits a broadcast deadline on some payloads; fall back to a local
  // 5-minute window so `waiting_countdown` always renders.
  static const Duration _defaultWindow = Duration(minutes: 5);

  @override
  Future<WaitingRequest> fetchWaiting(String requestId) async {
    final request = await _fetchRequestJson(requestId);
    final offerCount = await fetchOfferCount(
      requestId,
      fallback: (request['offersCount'] as num?)?.toInt() ?? 0,
    );
    return _parse(requestId, request, offerCount);
  }

  @override
  Future<WaitingRequest> fetchRequest(String requestId) async {
    final request = await _fetchRequestJson(requestId);
    // Phase/offerCount derived from the row's OWN status only — the dedicated
    // offers read is layered on later by the cubit so `waiting_notified_count`
    // is never gated behind the offers GET (JM-026 AC1).
    final rowOfferCount = (request['offersCount'] as num?)?.toInt() ?? 0;
    return _parse(requestId, request, rowOfferCount);
  }

  /// GET the request row (status + notifiedCount + deadline). This is the only
  /// read on the critical path for the broadcast-state signature ids; a hard
  /// failure here is the only thing that should surface the error state.
  Future<Map<String, dynamic>> _fetchRequestJson(String requestId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_requestsPath/$requestId',
      );
      return response.data ?? const <String, dynamic>{};
    } on DioException catch (e) {
      _rethrowRequest(e);
    }
  }

  /// Authoritative offer count from the offers endpoint; falls back to
  /// [fallback] (the request row's denormalised `offersCount`) when the offers
  /// read fails. Best-effort: never throws (JM-026 AC2 — the offers signal must
  /// not tear down the already-painted broadcast state).
  @override
  Future<int> fetchOfferCount(String requestId, {int fallback = 0}) async {
    try {
      final response = await _dio.get<dynamic>(
        _offersPath,
        queryParameters: {'requestId': requestId},
      );
      final data = response.data;
      final List<dynamic> items;
      if (data is List) {
        items = data;
      } else if (data is Map<String, dynamic>) {
        items = (data['offers'] as List?) ??
            (data['items'] as List?) ??
            const <dynamic>[];
      } else {
        items = const <dynamic>[];
      }
      // Exclude withdrawn offers so a retracted bid doesn't keep the screen on
      // the review CTA.
      return items.whereType<Map<String, dynamic>>().where((o) {
        final status = o['status'] as String?;
        return status != 'withdrawn';
      }).length;
    } on DioException {
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  WaitingRequest _parse(
    String requestId,
    Map<String, dynamic> json,
    int offerCount,
  ) {
    final status = json['status'] as String?;
    final notified = (json['notifiedCount'] as num?)?.toInt() ?? 0;
    final deadline = _parseDeadline(json['broadcastExpiresAt'] as String?);
    return WaitingRequest(
      requestId: requestId,
      phase: _phaseFor(status, offerCount),
      notifiedCount: notified,
      offerCount: offerCount,
      broadcastExpiresAt: deadline,
      displayId: json['displayId'] as String?,
      tier: json['tier'] as String?,
      title: json['title'] as String?,
    );
  }

  WaitingRequestPhase _phaseFor(String? status, int offerCount) {
    if (offerCount > 0 || status == 'offers-received') {
      return WaitingRequestPhase.offersArrived;
    }
    if (status == 'pending') return WaitingRequestPhase.broadcasting;
    // accepted / matched / cancelled / delivered / expired — nothing to wait
    // for on this pre-accept surface.
    if (status == null) return WaitingRequestPhase.broadcasting;
    return WaitingRequestPhase.closed;
  }

  DateTime _parseDeadline(String? raw) {
    if (raw == null) return DateTime.now().add(_defaultWindow);
    return DateTime.tryParse(raw) ?? DateTime.now().add(_defaultWindow);
  }

  Never _rethrowRequest(DioException e) {
    final status = e.response?.statusCode;
    if (status == 404) {
      throw const WaitingException(WaitingFailure.notFound);
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      throw const WaitingException(WaitingFailure.network);
    }
    throw const WaitingException(WaitingFailure.unknown);
  }
}
