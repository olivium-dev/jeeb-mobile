// PURE Dart. No Flutter / Dio / GetIt imports (40_GUARDRAILS_ARCH §1 layer rules).
//
// Wallet domain contract (JM-053). The wire format is owned by backenders
// (CTO-D2: W1m `GET /v1/jeeb/wallet`), sourced from `jeeb-mind-map`
// 05_WALLET_SCREENS + decisions D1/D42/D43. Until W1m lands the DI default is an
// INTEGRATOR-STUB (`injection_container.dart`) so the wallet UI shell builds in
// parallel (CTO-D2); the data-bound ACs validate once W1m is live.

/// The affordability of the Jeeber's wallet expressed as a STATE, not a derived
/// capacity number (D43). Maps 1:1 to W1m's `affordabilityState` enum so the
/// UI renders copy ("enough to bid" / "top up to bid") rather than a count.
enum WalletAffordability { enough, low, empty, allReserved }

/// The Jeeber wallet snapshot (W1m). `availableBalance` and `reservedNow`
/// (sum of live 10% reserves, D1) are amounts; `affordabilityState` is the
/// D43 state; `giftCredit` is the post-KYC fixed starter credit (D42).
class WalletBalance {
  const WalletBalance({
    required this.availableBalance,
    required this.affordabilityState,
    required this.reservedNow,
    required this.giftCredit,
    required this.currency,
  });

  final double availableBalance;
  final WalletAffordability affordabilityState;
  final double reservedNow;
  final double giftCredit;
  final String currency;
}

/// Typed failures the wallet data source can surface. The cubit maps these to
/// copy; the UI never sees a `DioException`.
enum WalletFailure { network, unauthorized, unknown }

/// Thrown by [WalletRepository] implementations; carries the typed
/// [WalletFailure] so `application/` stays Dio-free.
class WalletRepositoryException implements Exception {
  const WalletRepositoryException(this.failure, [this.message]);

  final WalletFailure failure;
  final String? message;

  @override
  String toString() => 'WalletRepositoryException($failure, $message)';
}

/// Domain contract for the Wallet Hub read model (JM-053 AC1).
///
/// Backed by W1m `GET /v1/jeeb/wallet` (CTO-D2, backend-owned). PURE Dart.
abstract class WalletRepository {
  /// Fetch the Jeeber wallet snapshot (balance / affordability / reserved-now /
  /// gift). Throws [WalletRepositoryException] on failure.
  Future<WalletBalance> fetchBalance();
}
