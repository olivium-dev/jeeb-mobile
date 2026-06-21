/// Resolves the DEFAULT recipient phone for a create-request when the compose
/// flow did not capture one (T-BE-019 / JEB-55).
///
/// The compose UI has no recipient-phone field today, but the gateway needs a
/// non-null `recipientPhone` on the request so the at-door handover OTP
/// (`POST /deliveries/{id}/otp/verify {code:"1234"}`) can dispatch/validate the
/// code — otherwise it returns 400 `recipient-phone-missing`. The pragmatic,
/// blueprint-aligned default is the signed-in client's OWN phone (the requester
/// is the default recipient).
///
/// PURE domain contract — no Dio/Flutter imports. Implementations resolve the
/// phone from wherever it lives (the gateway `GET /v1/users/me`, a cached
/// profile, …). Returning `null` is legal — the create then simply omits the
/// field and behaves as before (the gateway field is optional).
abstract class RecipientPhoneResolver {
  /// The default recipient phone in E.164, or `null` when none can be resolved.
  /// MUST NOT throw — a resolution failure degrades to `null` so the order
  /// create never fails just because the default phone was unavailable.
  Future<String?> resolve();
}
