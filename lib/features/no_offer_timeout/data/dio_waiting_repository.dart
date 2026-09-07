import 'package:dio/dio.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/single_flight_get.dart';
import '../domain/waiting_repository.dart';
import '../domain/waiting_request.dart';

class DioWaitingRepository implements WaitingRepository {
  DioWaitingRepository(
    Dio dio, {
    SingleFlightGet? coalescer,
    DateTime Function()? now,
  }) : _dio = dio,
       _coalescer = coalescer ?? SingleFlightGet(dio),
       _now = now ?? DateTime.now;

  final Dio _dio;
  final SingleFlightGet _coalescer;

  final DateTime Function() _now;

  static const _requestsPath = '/v1/requests';
  static const _offersPath = '/v1/offers';

  @override
  Future<WaitingRequest> fetchWaiting(String requestId) async {
    final request = await _fetchRequestJson(requestId);
    final rowCount = request['offersCount'] is num
        ? (request['offersCount'] as num).toInt()
        : null;
    final probed = await fetchOfferCount(requestId);
    // Known when EITHER source answered; unknown only when both are silent.
    // A fabricated zero is never presented as a count.
    return _parse(
      requestId,
      request,
      probed ?? rowCount ?? 0,
      probed: probed != null || rowCount != null,
    );
  }

  @override
  Future<WaitingRequest> fetchRequest(String requestId) async {
    final request = await _fetchRequestJson(requestId);
    final rowCount = request['offersCount'] is num
        ? (request['offersCount'] as num).toInt()
        : null;
    return _parse(requestId, request, rowCount ?? 0, probed: rowCount != null);
  }

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

  @override
  Future<int?> fetchOfferCount(String requestId) async {
    try {
      final response = await _coalescer.get(
        _offersPath,
        queryParameters: {'requestId': requestId},
      );
      final data = response.data;
      final List<dynamic> items;
      if (data is List) {
        items = data;
      } else if (data is Map<String, dynamic>) {
        items =
            (data['offers'] as List?) ??
            (data['items'] as List?) ??
            const <dynamic>[];
      } else {
        items = const <dynamic>[];
      }
      return items.whereType<Map<String, dynamic>>().where((o) {
        final status = o['status'] as String?;
        return status != 'withdrawn';
      }).length;
    } on DioException catch (e) {
      Diag.event('waiting_offer_count_failed', <String, Object?>{
        'kind': AppFailure.of(e).kind.name,
      });
      return null;
    } catch (_) {
      return null;
    }
  }

  WaitingRequest _parse(
    String requestId,
    Map<String, dynamic> json,
    int offerCount, {
    required bool probed,
  }) {
    final status = json['status'] as String?;
    final notified = (json['notifiedCount'] as num?)?.toInt() ?? 0;
    final phase = _phaseFor(status, offerCount);
    return WaitingRequest(
      requestId: requestId,
      phase: phase,
      notifiedCount: notified,
      offerCount: offerCount,
      receivedAt: _now(),
      remainingAtReceipt: _parseRemaining(json, phase, requestId),
      displayId: json['displayId'] as String?,
      tier: json['tier'] as String?,
      title: json['title'] as String? ?? json['description'] as String?,
      offerCountIsProbed: probed,
    );
  }

  WaitingRequestPhase _phaseFor(String? status, int offerCount) {
    final normalized = (status ?? '').trim().toLowerCase().replaceAll('_', '-');
    switch (normalized) {
      case 'matched':
      case 'accepted':
      case 'picked':
      case 'picked-up':
      case 'in-transit':
      case 'at-door':
      case 'heading-off':
        return WaitingRequestPhase.matched;
      case 'cancelled':
      case 'canceled':
        return WaitingRequestPhase.cancelled;
      case 'expired':
        return WaitingRequestPhase.expired;
      case 'delivered':
      case 'done':
      case 'rated':
        return WaitingRequestPhase.closed;
    }
    if (offerCount > 0 || normalized == 'offers-received') {
      return WaitingRequestPhase.offersArrived;
    }
    if (normalized.isEmpty || normalized == 'pending') {
      return WaitingRequestPhase.broadcasting;
    }
    return WaitingRequestPhase.closed;
  }

  Duration? _parseRemaining(
    Map<String, dynamic> json,
    WaitingRequestPhase phase,
    String requestId,
  ) {
    final raw = json['offerDeadlineInSeconds'];
    if (raw is num) {
      final seconds = raw.toInt();
      return Duration(seconds: seconds < 0 ? 0 : seconds);
    }
    if (raw != null) {
      throw WaitingException(
        WaitingFailure.contractViolation,
        'offerDeadlineInSeconds must be a number, '
        'got ${raw.runtimeType} ($requestId)',
      );
    }
    if (_countdownApplies(phase)) {
      throw WaitingException(
        WaitingFailure.contractViolation,
        'offerDeadlineInSeconds absent on a live $phase row ($requestId)',
      );
    }
    return null; // legitimate — accepted / scheduled / terminal
  }

  static bool _countdownApplies(WaitingRequestPhase p) =>
      p == WaitingRequestPhase.broadcasting ||
      p == WaitingRequestPhase.offersArrived;

  Never _rethrowRequest(DioException e) {
    if (e.response?.statusCode == 404) {
      throw const WaitingException(WaitingFailure.notFound);
    }
    final AppFailure f = AppFailure.of(e);
    throw WaitingException(
      f is NetworkFailure || f is TimeoutFailure
          ? WaitingFailure.network
          : WaitingFailure.unknown,
      null,
      f,
    );
  }
}
