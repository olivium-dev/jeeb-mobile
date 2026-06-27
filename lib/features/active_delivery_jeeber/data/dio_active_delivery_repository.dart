import 'package:dio/dio.dart';

import '../../../core/network/mock_gateway_client.dart';
import '../domain/active_delivery_repository.dart';
import '../domain/jeeber_delivery.dart';
import '../domain/jeeber_delivery_status.dart';

/// Dio-backed [ActiveDeliveryRepository] (T-MOB-031, extended by JM-051;
/// Sprint-3 S0-OAD-04/05 adds the frozen origin-only `:10090` lifecycle surface).
///
/// Speaks the gateway-contract `/v1/...` paths against the ORIGIN-ONLY Dio base
/// (`http://192.168.2.39:10090`, ARCH-01 — host/prefix NEVER hardcoded here).
/// `MockGatewayClient` selects the wire shape **by base**, not by host string:
/// the same flag that points Dio at the `:4010` Express mock
/// ([MockGatewayClient.useMockPrefixes]) also selects the legacy `:4010`
/// delivery routes, while the device/real default selects the Sprint-3 FROZEN
/// plural `:10090` routes. Two coexisting wire shapes, one repository:
///
/// **Origin `:10090` (Sprint-3 Contract 8, FROZEN — device/real default):**
///   GET   /v1/deliveries/{id}          → delivery row (Contract 8c)
///   PATCH /v1/deliveries/{id}/status   → body { to, evidenceUrl } (Contract 8b)
///                                         200 → delivery row | 422 → bad
///                                         transition | 422 {otp_required} on the
///                                         AtDoor→Done attempt without a verified
///                                         door OTP (Contract 8d).
///
/// **Mock `:4010` (legacy — KEEP for dev flavor, Contract 8b/8c aliases):**
///   GET  /v1/delivery/{id}              → delivery JSON
///   POST /v1/delivery/status/transition → body { deliveryId, to, evidenceUrl? }
///
/// Shared on both bases (already plural — unchanged this sprint):
///   GET  /v1/deliveries/{id}/otp        → get-or-issue handover OTP (Contract 8d)
///   POST /v1/deliveries/{id}/otp/verify → body { code } — completes a
///                                          phone-bearing delivery to Done
///   POST /v1/delivery/proof-photo       → body { deliveryId, filename }
///                                          201 → { url, evidenceUrl, deliveryId }
///
/// **D2 (route ambiguity):** which delivery route `:10090` actually serves is
/// NOT safe to assume — the plural `PATCH /v1/deliveries/{id}/status` is the
/// frozen origin-only surface this repository builds against; all logic/tests
/// pass on fixtures, and the live `:10090` round-trip is **[DEPLOY-GATED]**
/// behind S0-BE-07 (documented in `lanes/delivery.md`, NOT claimed).
class DioActiveDeliveryRepository implements ActiveDeliveryRepository {
  /// [originGateway] selects the wire shape. When `true` (the device/real
  /// default) the repository speaks the Sprint-3 FROZEN plural `:10090` routes;
  /// when `false` it speaks the legacy `:4010` mock routes. The default mirrors
  /// the base selection — `!MockGatewayClient.useMockPrefixes` — so the wire
  /// shape always tracks the base the same Dio is pointed at (Contract 8b:
  /// "MockGatewayClient selects by base — never hardcode a host"). Tests inject
  /// the flag explicitly to exercise both surfaces under a plain `flutter test`.
  const DioActiveDeliveryRepository(this._dio, {bool? originGateway})
      : originGateway = originGateway ?? !MockGatewayClient.useMockPrefixes;

  final Dio _dio;

  /// Whether to use the frozen origin-only `:10090` plural lifecycle routes
  /// (`GET /v1/deliveries/{id}`, `PATCH /v1/deliveries/{id}/status`) instead of
  /// the legacy `:4010` mock routes. See the constructor doc.
  final bool originGateway;

  // GET  /v1/deliveries/{id}/otp        → get-or-issue the handover OTP (the
  //                                        same path the recipient's "Show OTP"
  //                                        uses). Called issue-on-demand before
  //                                        verify so a code always exists even
  //                                        when the jeeber completes before the
  //                                        recipient opens Show-OTP.
  // POST /v1/deliveries/{id}/otp/verify → completes a phone-bearing delivery
  //                                        `AtDoor → Done` once the recipient
  //                                        OTP is verified. S7: both share the
  //                                        `/v1/deliveries` prefix so the single
  //                                        rewrite key catches them.
  static const _v1DeliveriesPath = '/v1/deliveries';

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async {
    try {
      // Origin `:10090` reads the plural `/v1/deliveries/{id}` (Contract 8c);
      // the `:4010` mock keeps the legacy singular `/v1/delivery/{id}` alias.
      final path = originGateway
          ? '$_v1DeliveriesPath/$deliveryId'
          : '/v1/delivery/$deliveryId';
      final response = await _dio.get<Map<String, dynamic>>(path);
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
      final response = originGateway
          // Origin `:10090` (Contract 8b, FROZEN): the jeeber writes via
          // `PATCH /v1/deliveries/{id}/status` with the camelCase body
          // { to, evidenceUrl } — the deliveryId lives in the PATH, never the
          // body; `evidenceUrl` is sent as an explicit null when absent so the
          // byte-shape matches the frozen `{ to, evidenceUrl: <string|null> }`.
          ? await _dio.patch<Map<String, dynamic>>(
              '$_v1DeliveriesPath/$deliveryId/status',
              data: <String, dynamic>{
                'to': to.apiValue,
                'evidenceUrl':
                    (evidenceUrl != null && evidenceUrl.isNotEmpty)
                        ? evidenceUrl
                        : null,
              },
            )
          // Legacy `:4010` mock alias kept for dev flavor.
          : await _dio.post<Map<String, dynamic>>(
              '/v1/delivery/status/transition',
              data: <String, dynamic>{
                'deliveryId': deliveryId,
                'to': to.apiValue,
                'trigger': 'jeeber',
                if (evidenceUrl != null && evidenceUrl.isNotEmpty)
                  'evidenceUrl': evidenceUrl,
              },
            );
      // Both endpoints return the full delivery row; read its status.
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
        '$_v1DeliveriesPath/$deliveryId/otp/verify',
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
