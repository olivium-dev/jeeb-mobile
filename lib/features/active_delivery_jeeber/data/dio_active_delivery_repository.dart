import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/mock_gateway_client.dart';
import '../../kyc/domain/cdn_asset_gateway.dart';
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
///   Proof-photo (D3, JEBV4-200): the REAL image bytes stream through the
///   gateway CDN signed-PUT broker (`POST /api/cdn/assets` + streaming proxy,
///   JEBV4-259 / PR #257) via [CdnAssetGateway] → durable `object_ref`.
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
  const DioActiveDeliveryRepository(
    this._dio, {
    required CdnAssetGateway cdnAssetGateway,
    bool? originGateway,
  })  : _cdn = cdnAssetGateway,
        originGateway = originGateway ?? !MockGatewayClient.useMockPrefixes;

  final Dio _dio;

  /// The shipped gateway CDN signed-PUT broker+proxy (JEBV4-259 / PR #257). The
  /// proof-of-delivery bytes stream through it exactly like the KYC photos — no
  /// filename stand-in, no bytes buffered in the gateway.
  final CdnAssetGateway _cdn;

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
      throw _mapTransitionError(e, from: from, to: to);
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
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    // JEBV4-200: transmit the REAL captured image bytes through the gateway's
    // shipped CDN signed-PUT streaming proxy (JEBV4-259 / PR #257). The two-step
    // broker mints a signed upload URL, the raw bytes stream to cdn-service, and
    // the durable `object_ref` returned here is stamped as the delivery's
    // `evidenceUrl` on `AtDoor → Done`. NO filename stand-in — the bytes ARE
    // sent (mirrors the KYC ID-photo upload). [deliveryId] is retained on the
    // contract for call-site clarity; the broker scopes the object to the
    // authenticated jeeber via the JWT subject.
    try {
      return await _cdn.uploadAsset(
        slot: CdnUploadSlot.proofOfDelivery,
        bytes: bytes,
        contentType: contentType,
      );
    } on CdnUploadException {
      throw const ActiveDeliveryException(ActiveDeliveryFailure.server);
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

  /// The gateway's typed 422 body is RFC 7807 problem+json carrying
  /// `reason` / `from` / `to` / `trigger` extensions plus a human `detail`
  /// (`DeliveriesController.MapTransitionException`). Match the `reason` TOKEN
  /// exactly — the old five-key substring scan could not tell `otp_required`
  /// from `transition_not_allowed` and could false-positive on any prose
  /// containing "otp" (P6/B3).
  ActiveDeliveryException _mapTransitionError(
    DioException e, {
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
  }) {
    final status = e.response?.statusCode;

    // P6/B4: a 400 on this route is the gateway's OWN body resolver refusing an
    // unresolvable canonical target — a client-bug signature, not an SM verdict.
    if (status == 400) {
      return ActiveDeliveryException(
        ActiveDeliveryFailure.badRequest,
        _reasonToken(e.response?.data),
      );
    }

    if (status == 422) {
      final reason = _reasonToken(e.response?.data);
      if (reason == 'otp_required') {
        return const ActiveDeliveryException(ActiveDeliveryFailure.otpRequired);
      }
      // Belt-and-braces: `AtDoor → Done` has exactly ONE exit and it is
      // `otp_verified`. Any 422 on that edge means "OTP needed", whatever the
      // upstream wording (this is the exact shape of the 2026-07-25 incident:
      // five 422 `transition_not_allowed` on AtDoor→Done).
      if (from == JeeberDeliveryStatus.atDoor &&
          to == JeeberDeliveryStatus.done) {
        return const ActiveDeliveryException(ActiveDeliveryFailure.otpRequired);
      }
      return ActiveDeliveryException(
        ActiveDeliveryFailure.invalidTransition,
        reason,
      );
    }

    return _mapError(e);
  }

  /// Extracts the structured rejection token from a 4xx body, normalized to
  /// lower-snake. Reads the canonical `reason` extension first, then the legacy
  /// `code`, then the RFC 7807 `detail` (the gateway mirrors the reason there),
  /// then `error`/`message`, plus one level of nesting. Returns null when the
  /// body carries no token.
  String? _reasonToken(Object? body) {
    if (body is! Map) return null;
    for (final key in const ['reason', 'code', 'detail', 'error', 'message']) {
      final v = body[key];
      if (v is String && v.trim().isNotEmpty) return v.trim().toLowerCase();
      if (v is Map) {
        final nested = v['reason'] ?? v['code'] ?? v['message'];
        if (nested is String && nested.trim().isNotEmpty) {
          return nested.trim().toLowerCase();
        }
      }
    }
    return null;
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
