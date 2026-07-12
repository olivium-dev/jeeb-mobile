import 'dart:typed_data';

import 'jeeber_delivery.dart';
import 'jeeber_delivery_status.dart';

/// Domain contract for the Jeeber active-delivery data layer (T-MOB-031,
/// extended by JM-051).
///
/// Endpoints (real mock gateway contract; `MockGatewayClient` rewrites `/v1/...`
/// to the `:4010` service prefix):
///   GET  /v1/delivery/{id}              → JeeberDelivery snapshot
///   POST /v1/delivery/status/transition → updated delivery; 422 on bad transition
///                                          (422 `otp_required` → [ActiveDeliveryFailure.otpRequired])
///   GET  /v1/deliveries/{id}/otp        → issue/trigger the handover OTP
///   POST /v1/deliveries/{id}/otp/verify → { verified, status } — completes a
///                                          phone-bearing delivery `AtDoor → Done`
///                                          when the recipient OTP is supplied.
///                                          ⚠️ MUST be the `/v1` plural
///                                          `otp/verify` path — the legacy
///                                          un-versioned `/deliveries/{id}/
///                                          verify-otp` is DEAD on live :10090
///                                          (400 otp-not-in-handover-state).
///   Proof-photo upload (D3, JEBV4-200): the REAL image bytes stream through the
///   gateway CDN signed-PUT broker (`POST /api/cdn/assets` + streaming proxy,
///   JEBV4-259 / PR #257) → durable `object_ref` stamped as `evidenceUrl`.
abstract class ActiveDeliveryRepository {
  /// Fetch the current snapshot for [deliveryId].
  Future<JeeberDelivery> fetchDelivery(String deliveryId);

  /// Advance the delivery status from [from] to [to], optionally stamping the
  /// proof-of-delivery [evidenceUrl] (carried on the `AtDoor → Done`
  /// transition, JM-051 / D3).
  ///
  /// Returns the updated [JeeberDeliveryStatus] on success.
  /// Throws [ActiveDeliveryException] on failure. A delivery created with a
  /// recipient phone requires the recipient OTP to complete `AtDoor → Done` —
  /// the gateway answers that step with **422 `otp_required`**, surfaced here as
  /// [ActiveDeliveryFailure.otpRequired] so the screen can prompt for the code.
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  });

  /// Complete a phone-bearing delivery to `Done` by verifying the recipient's
  /// door OTP (iter6 close-tail — live :10090 ground truth, request driven to
  /// Done: `GET /v1/deliveries/{id}/otp` to issue, then
  /// `POST /v1/deliveries/{id}/otp/verify {code}` → 200 { verified, status:Done }).
  /// The recipient gives the jeeber the code at the door; the jeeber enters it
  /// here. On success the delivery transitions to `Done`.
  ///
  /// Returns the resulting [JeeberDeliveryStatus] (`Done` on success).
  /// Throws [ActiveDeliveryException] with
  /// [ActiveDeliveryFailure.invalidOtp] on a wrong code (401),
  /// [ActiveDeliveryFailure.otpLocked] when attempts are exhausted (423), or the
  /// usual network/server failures otherwise.
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  });

  /// Upload the proof-of-delivery photo BYTES (D3, JEBV4-200) and return the
  /// durable evidence reference to stamp as the delivery's `evidenceUrl` on the
  /// terminal `AtDoor → Done` transition.
  ///
  /// Transmits the REAL captured image [bytes] — never a filename stand-in —
  /// through the gateway's shipped CDN signed-PUT streaming proxy (JEBV4-259 /
  /// PR #257). [contentType] is the media type of the bytes (e.g. `image/jpeg`).
  /// Throws [ActiveDeliveryException] on failure.
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  });
}

/// Typed failures for the active-delivery repository.
enum ActiveDeliveryFailure {
  network,
  invalidTransition,

  /// 422 `otp_required` on `AtDoor → Done` — the delivery carries a recipient
  /// phone and needs the door OTP verified before it can complete (iter6
  /// close-tail). Distinct from [invalidTransition] so the screen prompts for
  /// the code instead of a misleading "transition not allowed".
  otpRequired,

  /// 401 from the door-OTP verify — the entered code was wrong.
  invalidOtp,

  /// 423 from the door-OTP verify — attempts exhausted / locked.
  otpLocked,
  server,
  notFound,
}

class ActiveDeliveryException implements Exception {
  const ActiveDeliveryException(this.failure, [this.message]);

  final ActiveDeliveryFailure failure;
  final String? message;

  @override
  String toString() =>
      'ActiveDeliveryException(${failure.name}'
      '${message == null ? '' : ': $message'})';
}
