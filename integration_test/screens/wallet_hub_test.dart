// Isolated native UI test — WalletHubScreen (wallet-hub, JM-053). Mirrors
// test/features/wallet/wallet_hub_screen_test.dart: the screen owns its
// BlocProvider and takes both a WalletRepository and a JeeberKycStatusGate seam,
// so injecting scripted fakes needs no DI/network. The affordability card copy
// is STATE-driven off WalletBalance.affordabilityState (D43).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_hub_screen.dart';

import '../support/screen_harness.dart';

class _ScriptedWalletRepository implements WalletRepository {
  const _ScriptedWalletRepository(this._balance);
  final WalletBalance _balance;
  @override
  Future<WalletBalance> fetchBalance() async => _balance;
}

class _FakeKycGate implements JeeberKycStatusGate {
  const _FakeKycGate(this.status);
  @override
  final JeeberKycStatus status;
  @override
  bool get isApproved => status == JeeberKycStatus.approved;
}

WalletBalance _balance({
  double available = 40,
  WalletAffordability affordability = WalletAffordability.enough,
  double reserved = 4,
  double gift = 5,
  String currency = 'USD',
}) =>
    WalletBalance(
      availableBalance: available,
      affordabilityState: affordability,
      reservedNow: reserved,
      giftCredit: gift,
      currency: currency,
    );

WalletHubScreen _wallet(
  WalletBalance balance, {
  JeeberKycStatus kyc = JeeberKycStatus.approved,
}) =>
    WalletHubScreen(
      repository: _ScriptedWalletRepository(balance),
      kycStatusGate: _FakeKycGate(kyc),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('wallet: sufficient balance + gift badge (en)', (tester) async {
    await pumpAndShoot(tester, binding, _wallet(_balance()), 'wallet__sufficient');
  });

  testWidgets('wallet: running-low affordability state (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _wallet(_balance(affordability: WalletAffordability.low, gift: 0)),
      'wallet__low',
    );
  });

  testWidgets('wallet: KYC-pending banner (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _wallet(_balance(), kyc: JeeberKycStatus.pending),
      'wallet__kyc-pending-ar',
      locale: const Locale('ar'),
    );
  });
}
