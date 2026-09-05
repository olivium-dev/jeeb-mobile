// Shared dev-only fixtures for `WalletHubScreen`.

import 'dart:async';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';

/// Canned [WalletRepository] — `fetchBalance()` resolves to [balance]
/// immediately. No Dio, no GetIt, no network.
class WalletHubScreenFakeRepository implements WalletRepository {
  const WalletHubScreenFakeRepository(this.balance);

  /// What W1m `GET /v1/jeeb/wallet` resolves to for this state.
  final WalletBalance balance;

  @override
  Future<WalletBalance> fetchBalance() async => balance;
}

/// A read that never lands, holding the screen on [WalletHubStatus.loading] for
/// as long as the surface is open.
/// `WalletHubCubit.load()` emits `loading` and only leaves it when the future
class WalletHubScreenPendingRepository implements WalletRepository {
  const WalletHubScreenPendingRepository();

  @override
  Future<WalletBalance> fetchBalance() => Completer<WalletBalance>().future;
}

/// A read that throws the way the data source is contracted to fail: a typed
/// [WalletRepositoryException], not a null and not a zeroed balance.
/// The cubit maps every failure onto the same `failed` status, so [failure]
class WalletHubScreenFailingRepository implements WalletRepository {
  const WalletHubScreenFailingRepository({
    this.failure = WalletFailure.network,
  });

  final WalletFailure failure;

  @override
  Future<WalletBalance> fetchBalance() async {
    throw WalletRepositoryException(failure);
  }
}

/// A read whose body carries no `availableBalance` — the live repository now
/// throws rather than fabricate a broke wallet (UX-16), so this is the shape
/// the hub's error rung must show for a degenerate body.
class WalletHubScreenDegenerateRepository implements WalletRepository {
  const WalletHubScreenDegenerateRepository();

  @override
  Future<WalletBalance> fetchBalance() async {
    throw const WalletRepositoryException(
      WalletFailure.unknown,
      cause: UnknownFailure(parse: true),
    );
  }
}

/// A cold load that succeeds and every refresh after it that fails — the
/// warm-failure note over a balance still on screen (LR-09/UX-18).
class WalletHubScreenRefreshFailingRepository implements WalletRepository {
  WalletHubScreenRefreshFailingRepository(this.balance);

  final WalletBalance balance;

  bool _served = false;

  @override
  Future<WalletBalance> fetchBalance() async {
    if (_served) {
      throw const WalletRepositoryException(
        WalletFailure.network,
        cause: NetworkFailure(),
      );
    }
    _served = true;
    return balance;
  }
}

/// Scripted [JeeberKycStatusGate] — the AC7 pending-banner source, injected
/// instead of the DI gate so no state depends on a `jeeb.seam.kyc_status`
/// value or on a live `GET .../kyc`.
class WalletHubScreenKycGate implements JeeberKycStatusGate {
  const WalletHubScreenKycGate(this.status);

  /// The approved jeeber: no pending banner, offering allowed.
  const WalletHubScreenKycGate.approved()
      : status = JeeberKycStatus.approved;

  /// Registered, KYC submitted, not yet reviewed (D38/D39) — may top up, may
  /// not yet bid. Drives `wallet_kyc_pending_banner`.
  const WalletHubScreenKycGate.pending() : status = JeeberKycStatus.pending;

  @override
  final JeeberKycStatus status;

  @override
  bool get isApproved => status == JeeberKycStatus.approved;
}

// ── The designed wallets (D30 affordability bands, D42 gift). ───────────────

/// Healthy (D30 `enough`): funded, a small live reserve, no starter credit.
const WalletBalance walletHubScreenHealthy = WalletBalance(
  availableBalance: 145.0,
  affordabilityState: WalletAffordability.enough,
  reservedNow: 12.5,
  giftCredit: 0,
  currency: 'USD',
);

/// Low (D30 `low`) and still carrying the post-KYC starter credit (D42) — the
/// only fixture that renders `wallet_gift_badge`.
const WalletBalance walletHubScreenLowWithGift = WalletBalance(
  availableBalance: 8.0,
  affordabilityState: WalletAffordability.low,
  reservedNow: 5.0,
  giftCredit: 50.0,
  currency: 'USD',
);

/// Empty (D30 `empty`): a jeeber who has never topped up. Zero everywhere.
const WalletBalance walletHubScreenEmpty = WalletBalance(
  availableBalance: 0,
  affordabilityState: WalletAffordability.empty,
  reservedNow: 0,
  giftCredit: 0,
  currency: 'USD',
);

/// All-reserved (D30 `allReserved`): the balance is real but every cent of it
/// is held against live offers, so the jeeber cannot bid again until one is
const WalletBalance walletHubScreenAllReserved = WalletBalance(
  availableBalance: 20.0,
  affordabilityState: WalletAffordability.allReserved,
  reservedNow: 20.0,
  giftCredit: 0,
  currency: 'USD',
);

/// The offline wallet (D35): funded and healthy, so the ONLY thing that differs
/// from [walletHubScreenHealthy] is the ambient connectivity — which is exactly
const WalletBalance walletHubScreenOfflineFunded = WalletBalance(
  availableBalance: 63.0,
  affordabilityState: WalletAffordability.enough,
  reservedNow: 7.0,
  giftCredit: 0,
  currency: 'USD',
);

/// The layout ceiling: a Lebanese-pound wallet.
/// Not a stress test for its own sake — LBP is a live currency for this app and
const WalletBalance walletHubScreenLbpCeiling = WalletBalance(
  availableBalance: 89750000.0,
  affordabilityState: WalletAffordability.enough,
  reservedNow: 8975000.0,
  giftCredit: 4500000.0,
  currency: 'LBP',
);
