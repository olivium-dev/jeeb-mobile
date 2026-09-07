import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/gateway_problem.dart';
import '../../../core/network/mock_gateway_client.dart';
import '../../kyc/domain/cdn_asset_gateway.dart';
import '../domain/active_delivery_repository.dart';
import '../domain/jeeber_delivery.dart';
import '../domain/jeeber_delivery_status.dart';

class DioActiveDeliveryRepository implements ActiveDeliveryRepository {
  const DioActiveDeliveryRepository(
    this._dio, {
    required CdnAssetGateway cdnAssetGateway,
    bool? originGateway,
  })  : _cdn = cdnAssetGateway,
        originGateway = originGateway ?? !MockGatewayClient.useMockPrefixes;

  final Dio _dio;

  final CdnAssetGateway _cdn;

  final bool originGateway;

  static const _v1DeliveriesPath = '/v1/deliveries';

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async {
    try {
      final path = originGateway
          ? '$_v1DeliveriesPath/$deliveryId'
          : '/v1/delivery/$deliveryId';
      final response = await _dio.get<Map<String, dynamic>>(path);
      final data = response.data;
      if (data == null) {
        throw const ActiveDeliveryException.typed(ActiveDeliveryFailure.server);
      }
      return JeeberDelivery.fromJson(data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) async {
    final options = Options(
      headers: <String, Object?>{
        'Idempotency-Key': transitionIdempotencyKey(
          deliveryId: deliveryId,
          from: from,
          to: to,
          evidenceUrl: evidenceUrl,
        ),
      },
    );
    try {
      final response = originGateway
          ? await _dio.patch<Map<String, dynamic>>(
              '$_v1DeliveriesPath/$deliveryId/status',
              data: <String, dynamic>{
                'to': to.apiValue,
                'evidenceUrl':
                    (evidenceUrl != null && evidenceUrl.isNotEmpty)
                        ? evidenceUrl
                        : null,
              },
              options: options,
            )
          : await _dio.post<Map<String, dynamic>>(
              '/v1/delivery/status/transition',
              data: <String, dynamic>{
                'deliveryId': deliveryId,
                'to': to.apiValue,
                'trigger': 'jeeber',
                if (evidenceUrl != null && evidenceUrl.isNotEmpty)
                  'evidenceUrl': evidenceUrl,
              },
              options: options,
            );
      final raw = response.data?['status'] as String?;
      if (raw == null) return to;
      return JeeberDeliveryStatusX.fromApi(raw);
    } on DioException catch (e) {
      throw _mapTransitionError(e, from: from, to: to);
    }
  }

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async {
    try {
      try {
        await _dio.get<Map<String, dynamic>>(
          '$_v1DeliveriesPath/$deliveryId/otp',
        );
      } on DioException catch (e) {
        // Opportunistic: the screen fetches the code again. Traced so an
        // at-door failure is not invisible.
        Diag.event('otp_prefetch_failed', <String, Object?>{
          'deliveryId': deliveryId,
          'kind': AppFailure.of(e).kind.name,
        });
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '$_v1DeliveriesPath/$deliveryId/otp/verify',
        data: <String, dynamic>{'code': code},
      );
      final data = response.data ?? const <String, dynamic>{};
      final raw = data['status'] as String?;
      if (raw != null) return JeeberDeliveryStatusX.fromApi(raw);
      // A body carrying neither `status` nor `verified` is not a verified
      // handover: defaulting to true marks a delivery done on silence.
      if (data['verified'] != true) {
        throw const ActiveDeliveryException.typed(
          ActiveDeliveryFailure.invalidOtp,
        );
      }
      return JeeberDeliveryStatus.done;
    } on DioException catch (e) {
      throw _mapOtpError(e);
    }
  }

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    try {
      return await _cdn.uploadAsset(
        slot: CdnUploadSlot.proofOfDelivery,
        bytes: bytes,
        contentType: contentType,
      );
    } on CdnUploadException {
      throw const ActiveDeliveryException.typed(ActiveDeliveryFailure.server);
    }
  }

  ActiveDeliveryException _mapError(DioException e) {
    final AppFailure failure = AppFailure.of(e);
    return switch (failure.kind) {
      AppFailureKind.network || AppFailureKind.timeout =>
        const ActiveDeliveryException.typed(ActiveDeliveryFailure.network),
      AppFailureKind.notFound =>
        const ActiveDeliveryException.typed(ActiveDeliveryFailure.notFound),
      _ => const ActiveDeliveryException.typed(ActiveDeliveryFailure.server),
    };
  }

  ActiveDeliveryException _mapTransitionError(
    DioException e, {
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
  }) {
    final status = e.response?.statusCode;
    final String? suffix = _typeSuffix(e);

    if (status == 400) {
      return ActiveDeliveryException.typed(
        ActiveDeliveryFailure.badRequest,
        typeSuffix: suffix,
      );
    }

    if (status == 422) {
      if (suffix == 'otp-required' || _reason(e) == 'otp_required') {
        return const ActiveDeliveryException.typed(
          ActiveDeliveryFailure.otpRequired,
        );
      }
      if (from == JeeberDeliveryStatus.atDoor &&
          to == JeeberDeliveryStatus.done) {
        return const ActiveDeliveryException.typed(
          ActiveDeliveryFailure.otpRequired,
        );
      }
      return ActiveDeliveryException.typed(
        ActiveDeliveryFailure.invalidTransition,
        typeSuffix: suffix,
      );
    }

    // 409 is the sprint-009 accept-race vocabulary — the row already moved,
    // which is a refused transition, not a server fault.
    if (status == 409) {
      return ActiveDeliveryException.typed(
        ActiveDeliveryFailure.invalidTransition,
        typeSuffix: suffix,
      );
    }

    return _mapError(e);
  }

  GatewayProblem? _problem(DioException e) =>
      GatewayProblem.tryParse(e.response?.data);

  String? _typeSuffix(DioException e) => _problem(e)?.typeSuffix;

  /// The `reason` EXTENSION member only — never `detail`/`title`/`message`,
  /// which carry server prose the UI must not render.
  String? _reason(DioException e) => _problem(e)?.reason?.trim().toLowerCase();

  ActiveDeliveryException _mapOtpError(DioException e) {
    final status = e.response?.statusCode;
    final GatewayProblem? problem = _problem(e);
    final String? suffix = problem?.typeSuffix;

    if (status == 401) {
      return ActiveDeliveryException.typed(
        ActiveDeliveryFailure.invalidOtp,
        attemptsRemaining: problem?.attemptsRemaining,
      );
    }
    if (status == 400 || status == 422) {
      if (suffix == 'otp-code-required') {
        return const ActiveDeliveryException.typed(
          ActiveDeliveryFailure.otpCodeRequired,
        );
      }
      return ActiveDeliveryException.typed(
        ActiveDeliveryFailure.invalidOtp,
        attemptsRemaining: problem?.attemptsRemaining,
      );
    }
    if (status == 404) {
      return const ActiveDeliveryException.typed(
        ActiveDeliveryFailure.notFound,
      );
    }
    if (status == 423) {
      return ActiveDeliveryException.typed(
        ActiveDeliveryFailure.otpLocked,
        escalationId: problem?.escalationId,
        lockedAt: problem?.lockedAt,
      );
    }
    return _mapError(e);
  }

}

/// Derived from the edge being walked, so a replay or a re-tapped Retry of the
/// SAME step cannot advance the ladder twice.
String transitionIdempotencyKey({
  required String deliveryId,
  required JeeberDeliveryStatus from,
  required JeeberDeliveryStatus to,
  String? evidenceUrl,
}) {
  final scope =
      'transition:$deliveryId:${from.apiValue}:${to.apiValue}:${evidenceUrl ?? ''}';
  return sha256.convert(utf8.encode(scope)).toString();
}
