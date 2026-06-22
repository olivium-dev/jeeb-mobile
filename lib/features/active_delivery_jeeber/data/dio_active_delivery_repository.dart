import 'package:dio/dio.dart';

import '../domain/active_delivery_repository.dart';
import '../domain/jeeber_delivery.dart';
import '../domain/jeeber_delivery_status.dart';

/// Dio-backed [ActiveDeliveryRepository] (T-MOB-031, extended by JM-051).
///
/// Speaks the gateway-contract `/v1/...` paths; `MockGatewayClient` rewrites
/// the prefix to the `:4010` `delivery-service` (40_GUARDRAILS_ARCH §4 — never
/// hardcode a host/prefix here).
///
///   GET  /v1/delivery/{id}              → delivery JSON
///   POST /v1/delivery/status/transition → body { deliveryId, to, evidenceUrl? }
///                                          200 → delivery | 422 → bad transition
///                                          (422 `otp_required` → otpRequired)
///   POST /deliveries/{id}/otp/verify    → body { code } — completes a
///                                          phone-bearing delivery to Done
///                                          (iter6 close-tail door-OTP path #68)
///   POST /v1/delivery/proof-photo       → body { deliveryId, filename }
///                                          201 → { url, evidenceUrl, deliveryId }
class DioActiveDeliveryRepository implements ActiveDeliveryRepository {
  const DioActiveDeliveryRepository(this._dio);

  final Dio _dio;

  // POST /deliveries/{id}/otp/verify → the gateway path that completes a
  // phone-bearing delivery `AtDoor → Done` once the recipient OTP is verified
  // (iter6 close-tail; the same path #68 proved on the gateway).
  static const _deliveriesPath = '/deliveries';

  // GET /v1/deliveries/{id}/otp → get-or-issue the handover OTP (the same path
  // the recipient's "Show OTP" uses). Called issue-on-demand before verify so a
  // code_hash always exists even when the jeeber completes before the recipient
  // opens Show-OTP (iter6 jeeber door-OTP fix).
  static const _v1DeliveriesPath = '/v1/deliveries';

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/delivery/$deliveryId',
      );
      final data = response.data;
      if (data == null) {
        throw const ActiveDeliveryException(ActiveDeliveryFailure.server);
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
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/delivery/status/transition',
        data: <String, dynamic>{
          'deliveryId': deliveryId,
          'to': to.apiValue,
          'trigger': 'jeeber',
          if (evidenceUrl != null && evidenceUrl.isNotEmpty)
            'evidenceUrl': evidenceUrl,
        },
      );
      // The transition endpoint returns the full delivery row; read its status.
      final raw = response.data?['status'] as String?;
      if (raw == null) return to;
      return JeeberDeliveryStatusX.fromApi(raw);
    } on DioException catch (e) {
      throw _mapTransitionError(e);
    }
  }

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async {
    try {
      // ISSUE-ON-DEMAND (iter6 jeeber door-OTP fix): the jeeber-side complete
      // flow can reach this verify BEFORE the recipient ever opens "Show OTP",
      // in which case no handover OTP has been issued (code_hash empty) and the
      // verify 401s ("Incorrect code") even for the right code. Trigger the SAME
      // issuance the recipient's "Show OTP" path uses (`GET /v1/deliveries/{id}/
      // otp` — idempotent get-or-issue) first, so a code_hash always exists, then
      // verify. The returned code is the recipient's to read out; we DON'T use it
      // (the jeeber types what the recipient tells them) — we only need issuance.
      // Best-effort: if issuance hiccups, the verify still runs (it succeeds when
      // the recipient already issued via Show-OTP).
      try {
        await _dio.get<Map<String, dynamic>>(
          '$_v1DeliveriesPath/$deliveryId/otp',
        );
      } on DioException {
        // Degrade — proceed to verify; it works when the OTP was already issued.
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '$_deliveriesPath/$deliveryId/otp/verify',
        data: <String, dynamic>{'code': code},
      );
      final data = response.data ?? const <String, dynamic>{};
      // The gateway echoes the resulting delivery status; a verified handover
      // lands the delivery at Done. Accept an explicit `status`, fall back to
      // `verified:true → Done` so an ack-only 200 still completes.
      final raw = data['status'] as String?;
      if (raw != null) return JeeberDeliveryStatusX.fromApi(raw);
      final verified = data['verified'] as bool? ?? true;
      return verified
          ? JeeberDeliveryStatus.done
          : JeeberDeliveryStatus.atDoor;
    } on DioException catch (e) {
      throw _mapOtpError(e);
    }
  }

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required String filename,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/delivery/proof-photo',
        data: <String, dynamic>{
          'deliveryId': deliveryId,
          'filename': filename,
        },
      );
      final url = response.data?['evidenceUrl'] as String? ??
          response.data?['url'] as String?;
      if (url == null || url.isEmpty) {
        throw const ActiveDeliveryException(ActiveDeliveryFailure.server);
      }
      return url;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  ActiveDeliveryException _mapError(DioException e) {
    if (e.response?.statusCode == 404) {
      return const ActiveDeliveryException(ActiveDeliveryFailure.notFound);
    }
    if (_isNetworkError(e)) {
      return const ActiveDeliveryException(ActiveDeliveryFailure.network);
    }
    return ActiveDeliveryException(
      ActiveDeliveryFailure.server,
      'HTTP ${e.response?.statusCode}',
    );
  }

  ActiveDeliveryException _mapTransitionError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 422 || status == 400) {
      // A phone-bearing delivery answers `AtDoor → Done` with 422 `otp_required`
      // — the recipient OTP must be verified first. Distinguish it from a true
      // bad transition so the screen prompts for the code (iter6 close-tail).
      if (_isOtpRequired(e.response?.data)) {
        return const ActiveDeliveryException(
          ActiveDeliveryFailure.otpRequired,
        );
      }
      return const ActiveDeliveryException(
        ActiveDeliveryFailure.invalidTransition,
      );
    }
    return _mapError(e);
  }

  /// True when a 4xx transition body signals the recipient-OTP gate. The
  /// gateway returns a code/error/message of `otp_required` (it may nest under
  /// `error`/`detail`); match any `otp` token defensively so a small wording
  /// drift still routes to the OTP prompt rather than the misleading
  /// "transition not allowed".
  bool _isOtpRequired(Object? body) {
    if (body is! Map) return false;
    for (final key in const ['code', 'error', 'reason', 'message', 'detail']) {
      final v = body[key];
      if (v is String && v.toLowerCase().contains('otp')) return true;
      // `error`/`detail` may itself be a nested object carrying the code.
      if (v is Map) {
        final nested = (v['code'] ?? v['message'] ?? v['reason']);
        if (nested is String && nested.toLowerCase().contains('otp')) {
          return true;
        }
      }
    }
    return false;
  }

  ActiveDeliveryException _mapOtpError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 401 || status == 400 || status == 422) {
      // Wrong code. (Some gateways answer a bad door code with 422; a missing
      // delivery still surfaces as 404 below.)
      if (status == 404) {
        return const ActiveDeliveryException(ActiveDeliveryFailure.notFound);
      }
      return const ActiveDeliveryException(ActiveDeliveryFailure.invalidOtp);
    }
    if (status == 423) {
      return const ActiveDeliveryException(ActiveDeliveryFailure.otpLocked);
    }
    return _mapError(e);
  }

  bool _isNetworkError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.receiveTimeout;
}
