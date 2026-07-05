// Isolated native UI test — OnboardingFundingScreen (onboarding-funding,
// JM-041). The static starter-credit explainer is enriched with a live wallet
// snapshot read from the `repository` seam (which the screen resolves eagerly,
// so we inject an in-memory fake rather than fall through to unconfigured DI).
// Covers the enriched explainer (with live amounts), the fail-safe static
// explainer (repo throws → no enrichment), and the enriched explainer in Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/jeeber_onboarding_funding/presentation/onboarding_funding_screen.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';

import '../support/screen_harness.dart';

/// In-memory wallet repo serving one fixed snapshot (or throwing). Inlined so
/// the integration test never reaches into test/support/.
class _FakeWalletRepository implements WalletRepository {
  const _FakeWalletRepository(this._balance, {this.throws = false});

  final WalletBalance _balance;
  final bool throws;

  @override
  Future<WalletBalance> fetchBalance() async {
    if (throws) throw const WalletRepositoryException(WalletFailure.network);
    return _balance;
  }
}

const _balance = WalletBalance(
  availableBalance: 25.00,
  affordabilityState: WalletAffordability.enough,
  reservedNow: 3.00,
  giftCredit: 10.00,
  currency: 'USD',
);

OnboardingFundingScreen _screen({bool throws = false}) => OnboardingFundingScreen(
      repository: _FakeWalletRepository(_balance, throws: throws),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding-funding: enriched explainer (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(),
      'onboarding-funding__populated',
    );
  });

  testWidgets('onboarding-funding: fail-safe static explainer (en)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(throws: true),
      'onboarding-funding__static',
    );
  });

  testWidgets('onboarding-funding: enriched explainer (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _screen(),
      'onboarding-funding__ar',
      locale: const Locale('ar'),
    );
  });
}
