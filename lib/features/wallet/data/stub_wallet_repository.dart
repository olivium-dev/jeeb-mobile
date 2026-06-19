import '../domain/wallet_repository.dart';

/// INTEGRATOR-STUB(JM-053/046): the wallet balance/affordability/reserved-now
/// endpoint (W1m) is backend-owned and NOT live on `:4010` yet (CTO-D2). This
/// in-memory stub is the DI default so the wallet UI shell (`WalletHubScreen`,
/// JM-053) + every "+ Top up" CTA that routes through it build and render NOW,
/// before W1m lands. The data-bound ACs validate once the real endpoint exists
/// and DI is repointed to [DioWalletRepository].
///
/// This is DELIBERATELY a non-fake, DI-registerable stub (not a `Fake*` test
/// seam, which DO-NOT forbids in DI — 40_GUARDRAILS_ARCH §6). It returns a
/// deterministic "enough to bid" snapshot so the hub renders its healthy state;
/// the JM-053 engineer drives the other state variants (low/empty/all-reserved)
/// via the cubit + the `jeeb.seam.wallet_state` Maestro seam once W1m is wired.
///
/// SWAP WHEN W1m LANDS: replace the `injection_container.dart` registration's
/// `StubWalletRepository()` with `DioWalletRepository(sl<Dio>())`.
class StubWalletRepository implements WalletRepository {
  const StubWalletRepository();

  @override
  Future<WalletBalance> fetchBalance() async {
    // A single deterministic snapshot. No timers, no network — fail-safe so the
    // shell never spins or errors on the stub path.
    return const WalletBalance(
      availableBalance: 120.0,
      affordabilityState: WalletAffordability.enough,
      reservedNow: 0.0,
      giftCredit: 50.0,
      currency: 'SAR',
    );
  }
}
