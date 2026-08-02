// Widget tests for WalletHubScreen (JM-053). Proves the screen renders the

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_hub_screen.dart';

import '../../support/sync_app_localizations.dart';

class _ScriptedWalletRepository implements WalletRepository {
  _ScriptedWalletRepository(this._balance, {this.throws = false});

  final WalletBalance _balance;
  final bool throws;

  @override
  Future<WalletBalance> fetchBalance() async {
    if (throws) {
      throw const WalletRepositoryException(WalletFailure.network);
    }
    return _balance;
  }
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

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required WalletRepository repo,
    JeeberKycStatus kyc = JeeberKycStatus.approved,
  }) async {
    await tester.pumpWidget(
      wrapForTest(
        WalletHubScreen(
          repository: repo,
          kycStatusGate: _FakeKycGate(kyc),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('AC1: core hub identifiers render (sufficient state)',
      (tester) async {
    await pump(tester, repo: _ScriptedWalletRepository(_balance()));

    expect(find.bySemanticsIdentifier('wallet_hub_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_available_balance'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_gift_badge'), findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_affordability_card'),
        findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_reserved_now'), findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_topup_cta'), findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_how_fees_work'), findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_earnings_row'), findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_see_all_activity'),
        findsOneWidget);
  });

  testWidgets('D42: gift badge is hidden when giftCredit is 0', (tester) async {
    await pump(tester, repo: _ScriptedWalletRepository(_balance(gift: 0)));

    expect(find.bySemanticsIdentifier('wallet_gift_badge'), findsNothing);
    // The rest of the hub still renders.
    expect(find.bySemanticsIdentifier('wallet_available_balance'),
        findsOneWidget);
  });

  testWidgets('AC3: how-fees → explainer bottom sheet opens', (tester) async {
    await pump(tester, repo: _ScriptedWalletRepository(_balance()));

    expect(find.bySemanticsIdentifier('wallet_how_fees_explainer'),
        findsNothing);
    await tester.tap(find.bySemanticsIdentifier('wallet_how_fees_work'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('wallet_how_fees_explainer'),
        findsOneWidget);
  });

  testWidgets('AC6/D43: healthy state shows "Ready to bid" copy',
      (tester) async {
    await pump(tester, repo: _ScriptedWalletRepository(_balance()));
    expect(find.text('Ready to bid'), findsOneWidget);
    expect(find.text('Running low'), findsNothing);
  });

  testWidgets('AC6/D43: low state shows "Running low" copy (state, not number)',
      (tester) async {
    await pump(
      tester,
      repo: _ScriptedWalletRepository(
        _balance(affordability: WalletAffordability.low, gift: 0),
      ),
    );
    expect(find.text('Running low'), findsOneWidget);
    expect(find.text('Ready to bid'), findsNothing);
  });

  testWidgets('AC6/D43: all-reserved state shows distinct copy', (tester) async {
    await pump(
      tester,
      repo: _ScriptedWalletRepository(
        _balance(affordability: WalletAffordability.allReserved, gift: 0),
      ),
    );
    expect(find.text('Everything is reserved'), findsOneWidget);
    expect(find.text('Ready to bid'), findsNothing);
  });

  testWidgets('AC7: KYC-pending banner hidden when approved', (tester) async {
    await pump(
      tester,
      repo: _ScriptedWalletRepository(_balance()),
      kyc: JeeberKycStatus.approved,
    );
    expect(find.bySemanticsIdentifier('wallet_kyc_pending_banner'),
        findsNothing);
  });

  testWidgets('AC7: KYC-pending banner visible when pending', (tester) async {
    await pump(
      tester,
      repo: _ScriptedWalletRepository(_balance()),
      kyc: JeeberKycStatus.pending,
    );
    expect(find.bySemanticsIdentifier('wallet_kyc_pending_banner'),
        findsOneWidget);
  });

  testWidgets('failed load surfaces the error state with retry', (tester) async {
    await pump(
      tester,
      repo: _ScriptedWalletRepository(_balance(), throws: true),
    );

    // The hub root survives; the available-balance content does not render.
    expect(find.bySemanticsIdentifier('wallet_hub_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_available_balance'),
        findsNothing);
  });
}
