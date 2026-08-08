/// F3: outcomes of `POST /v1/users/me/role/unregister`. `unavailable` is
/// distinct from [networkError] — it maps the gateway's `502 upstream_fault`
/// (UM has no revoke op yet), so the UI can say "temporarily unavailable"
/// instead of a generic error or a fabricated success.
enum JeeberUnregisterOutcome {
  success,
  notAJeeber,
  activeDelivery,
  positiveBalance,
  unavailable,
  networkError,
}

abstract class JeeberUnregisterService {
  Future<JeeberUnregisterOutcome> unregister();
}
