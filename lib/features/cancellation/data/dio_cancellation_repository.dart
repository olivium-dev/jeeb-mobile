import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/gateway_problem.dart';
import '../domain/cancellation_repository.dart';
import '../domain/cancellation_result.dart';

/// Posts to /v1/deliveries/{id}/cancel; 409/422 → too_late_to_cancel.
/// Logs delivery.cancel_requested and delivery.cancel_confirmed per AC5.
class DioCancellationRepository implements CancellationRepository {
  const DioCancellationRepository(this._dio);

  final Dio _dio;

  @override
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) async {
    _logRequested(deliveryId, reason);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/deliveries/$deliveryId/cancel',
        data: _buildBody(reason, otherDetails),
        options: Options(
          headers: <String, Object?>{
            'Idempotency-Key': _cancelIdempotencyKey(
              deliveryId,
              reason,
              otherDetails,
            ),
          },
        ),
      );
      final result = _parse(response.data ?? {});
      _logConfirmed(deliveryId);
      return result;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  Map<String, dynamic> _buildBody(String reason, String? other) {
    return {
      'reason': reason,
      if (other != null && other.isNotEmpty) 'otherDetails': other,
    };
  }

  CancellationResult _parse(Map<String, dynamic> json) {
    return CancellationResult(
      deliveryId: json['deliveryId'] as String? ?? '',
      weeklyCount: (json['weeklyCount'] as int?) ?? 0,
      retryAfter: _parseRetryAfter(json['retryAfter']),
      strikeCount: json['strikeCount'] as int?,
      restriction: json['restriction'] as String?,
      pendingApproval: (json['pendingApproval'] as bool?) ?? false,
    );
  }

  /// The gateway sends either an ISO instant or a number of seconds; the
  /// unconditional `as String?` threw a TypeError on the second shape.
  DateTime? _parseRetryAfter(Object? raw) {
    if (raw is num) return DateTime.now().add(Duration(seconds: raw.round()));
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  Never _handleDioError(DioException e) {
    final int? status = e.response?.statusCode;
    if (status == 409 || status == 422) {
      throw const CancellationTooLateException();
    }
    final GatewayProblem? problem = GatewayProblem.tryParse(e.response?.data);
    final String? suffix = problem?.typeSuffix;
    if (status == 400 && suffix == 'cancellation-reason-required') {
      throw const CancellationException(
        null,
        CancellationFailure.reasonRequired,
      );
    }
    if (status == 403 && suffix == 'not-a-party') {
      throw const CancellationException(null, CancellationFailure.notAParty);
    }
    final AppFailure failure = AppFailure.of(e);
    throw CancellationException(null, switch (failure.kind) {
      AppFailureKind.network => CancellationFailure.network,
      AppFailureKind.timeout => CancellationFailure.timeout,
      AppFailureKind.rateLimited => CancellationFailure.rateLimited,
      AppFailureKind.server => CancellationFailure.server,
      AppFailureKind.forbidden => CancellationFailure.forbidden,
      _ => CancellationFailure.unknown,
    });
  }

  void _logRequested(String id, String reason) {
    Diag.event('delivery.cancel_requested', <String, Object?>{
      'deliveryId': id,
      'reason': reason,
    });
  }

  void _logConfirmed(String id) {
    Diag.event('delivery.cancel_confirmed', <String, Object?>{
      'deliveryId': id,
    });
  }
}

/// Derived from the payload, so the transport replay and the user's Retry of
/// the SAME cancel travel under one key and cannot open two cancellations.
String _cancelIdempotencyKey(String deliveryId, String reason, String? other) =>
    sha256
        .convert(utf8.encode('cancel:$deliveryId:$reason:${other ?? ''}'))
        .toString();
