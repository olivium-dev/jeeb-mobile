// Shared dev-only fixtures for `WalletHubScreen`.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_11_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/wallet/presentation/wallet_hub_screen.dart`.
//
// The catalog owned a private `_StaticWalletHubRepository` /
// `_PendingWalletHubRepository` / `_FailingWalletHubRepository` /
// `_StaticKycStatusGate` plus four inline [WalletBalance] literals. Copying
// those into the preview section would have given the two surfaces two
// different wallets, free to drift — and the wallet is the one screen where the
// designed state IS the numbers. Both surfaces now import this file, so a
// change to the fixture wallet shows up in the catalog and in the canvas
// together.
//
// Everything here is a LOCAL fake: `WalletHubScreen` takes `repository:` and
// `kycStatusGate:` seams (40_GUARDRAILS_ARCH §5.4), so neither surface ever
// resolves the DI `sl<WalletRepository>()` / `sl<JeeberKycStatusGate>()`.
// Network-free by construction, not merely by the guard the hosts install.
//
// Every class here is `const`-constructible so the catalog can keep building
// `const WalletHubScreen(...)`.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

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
///
/// `WalletHubCubit.load()` emits `loading` and only leaves it when the future
/// completes, so this is the only way to inspect the spinner without a real
/// slow connection.
class WalletHubScreenPendingRepository implements WalletRepository {
  const WalletHubScreenPendingRepository();

  @override
  Future<WalletBalance> fetchBalance() => Completer<WalletBalance>().future;
}

/// A read that throws the way the data source is contracted to fail: a typed
/// [WalletRepositoryException], not a null and not a zeroed balance.
///
/// The cubit maps every failure onto the same `failed` status, so [failure]
/// changes nothing the user sees — it exists so a fixture can say WHICH failure
/// it is describing.
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
//
// One wallet per band, with amounts that are distinct ACROSS bands: the render
// tests pin a state by the number it shows, and two fixtures sharing `40.00`
// would let a preview wired to the wrong fake pass.

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
/// decided. `availableBalance == reservedNow` is what makes the band honest.
const WalletBalance walletHubScreenAllReserved = WalletBalance(
  availableBalance: 20.0,
  affordabilityState: WalletAffordability.allReserved,
  reservedNow: 20.0,
  giftCredit: 0,
  currency: 'USD',
);

/// The offline wallet (D35): funded and healthy, so the ONLY thing that differs
/// from [walletHubScreenHealthy] is the ambient connectivity — which is exactly
/// the point of the state. A distinct amount keeps the two tellable apart.
const WalletBalance walletHubScreenOfflineFunded = WalletBalance(
  availableBalance: 63.0,
  affordabilityState: WalletAffordability.enough,
  reservedNow: 7.0,
  giftCredit: 0,
  currency: 'USD',
);

/// The layout ceiling: a Lebanese-pound wallet.
///
/// Not a stress test for its own sake — LBP is a live currency for this app and
/// its amounts are 8 digits before the decimal point. `_fmt` renders
/// `toStringAsFixed(2)` with no grouping, so this is literally what a jeeber
/// paid in LBP sees: `89750000.00`. Combined with a starter credit and the
/// KYC-pending banner it is the tallest, widest content the hub can hold.
///
/// Preview-only today; the catalog is free to adopt it.
const WalletBalance walletHubScreenLbpCeiling = WalletBalance(
  availableBalance: 89750000.0,
  affordabilityState: WalletAffordability.enough,
  reservedNow: 8975000.0,
  giftCredit: 4500000.0,
  currency: 'LBP',
);
