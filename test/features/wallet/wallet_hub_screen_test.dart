// Widget tests for WalletHubScreen (JM-053). Proves the screen renders the

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/jeeb_commission.dart';
import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
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

/// A read that never lands — holds the screen on `loading`.
class _NeverWalletRepository implements WalletRepository {
  const _NeverWalletRepository();

  @override
  Future<WalletBalance> fetchBalance() => Completer<WalletBalance>().future;
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
}) => WalletBalance(
  availableBalance: available,
  affordabilityState: affordability,
  reservedNow: reserved,
  giftCredit: gift,
  currency: currency,
);

void main() {
  // The loading/error states mount `JeebEmptyState`, whose illustration loops
  // ∞ by design (02-STUDY-NOTES M0-4) — `pumpAndSettle` settles only under
  // reduce motion, which is also the deterministic rest frame the board draws.
  Future<void> pump(
    WidgetTester tester, {
    required WalletRepository repo,
    JeeberKycStatus kyc = JeeberKycStatus.approved,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      wrapForTest(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: WalletHubScreen(
              repository: repo,
              kycStatusGate: _FakeKycGate(kyc),
            ),
          ),
        ),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('AC1: core hub identifiers render (sufficient state)', (
    tester,
  ) async {
    await pump(tester, repo: _ScriptedWalletRepository(_balance()));

    expect(find.bySemanticsIdentifier('wallet_hub_root'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('wallet_available_balance'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('wallet_gift_badge'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('wallet_affordability_card'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('wallet_reserved_now'), findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_topup_cta'), findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_how_fees_work'), findsOneWidget);
    expect(find.bySemanticsIdentifier('wallet_earnings_row'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('wallet_see_all_activity'),
      findsOneWidget,
    );
  });

  testWidgets('D42: gift badge is hidden when giftCredit is 0', (tester) async {
    await pump(tester, repo: _ScriptedWalletRepository(_balance(gift: 0)));

    expect(find.bySemanticsIdentifier('wallet_gift_badge'), findsNothing);
    // The rest of the hub still renders.
    expect(
      find.bySemanticsIdentifier('wallet_available_balance'),
      findsOneWidget,
    );
  });

  testWidgets('AC3: how-fees → explainer bottom sheet opens', (tester) async {
    await pump(tester, repo: _ScriptedWalletRepository(_balance()));

    expect(
      find.bySemanticsIdentifier('wallet_how_fees_explainer'),
      findsNothing,
    );
    await tester.tap(find.bySemanticsIdentifier('wallet_how_fees_work'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsIdentifier('wallet_how_fees_explainer'),
      findsOneWidget,
    );
  });

  testWidgets("AC6/D43: healthy state shows \"You're set to bid\" copy", (
    tester,
  ) async {
    await pump(tester, repo: _ScriptedWalletRepository(_balance()));
    expect(find.text("You're set to bid"), findsOneWidget);
    expect(find.text('Running low'), findsNothing);
  });

  testWidgets(
    'AC6/D43: low state shows "Running low" copy (state, not number)',
    (tester) async {
      await pump(
        tester,
        repo: _ScriptedWalletRepository(
          _balance(affordability: WalletAffordability.low, gift: 0),
        ),
      );
      expect(find.text('Running low'), findsOneWidget);
      expect(find.text("You're set to bid"), findsNothing);
    },
  );

  testWidgets('AC6/D43: all-reserved state shows distinct copy', (
    tester,
  ) async {
    await pump(
      tester,
      repo: _ScriptedWalletRepository(
        _balance(affordability: WalletAffordability.allReserved, gift: 0),
      ),
    );
    expect(find.text('Everything is reserved'), findsOneWidget);
    expect(find.text("You're set to bid"), findsNothing);
  });

  testWidgets('AC7: KYC-pending banner hidden when approved', (tester) async {
    await pump(
      tester,
      repo: _ScriptedWalletRepository(_balance()),
      kyc: JeeberKycStatus.approved,
    );
    expect(
      find.bySemanticsIdentifier('wallet_kyc_pending_banner'),
      findsNothing,
    );
  });

  testWidgets('AC7: KYC-pending banner visible when pending', (tester) async {
    await pump(
      tester,
      repo: _ScriptedWalletRepository(_balance()),
      kyc: JeeberKycStatus.pending,
    );
    expect(
      find.bySemanticsIdentifier('wallet_kyc_pending_banner'),
      findsOneWidget,
    );
  });

  testWidgets('failed load surfaces the error state with retry', (
    tester,
  ) async {
    await pump(
      tester,
      repo: _ScriptedWalletRepository(_balance(), throws: true),
    );

    // The hub root survives; the available-balance content does not render.
    expect(find.bySemanticsIdentifier('wallet_hub_root'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('wallet_available_balance'),
      findsNothing,
    );
  });

  // ── redesign-24 (23-wallet) ────────────────────────────────────────────────

  testWidgets('redesign-24: back circle + docked trust line resolve', (
    tester,
  ) async {
    // The board's own viewport (440x956). The default 800x600 test surface is
    // shorter than the hub's content, so the docked trust line would sit below
    // the fold and its sliver would never be built — that is the harness, not
    // the design (R1: the real screen ends with an empty lower third).
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(tester, repo: _ScriptedWalletRepository(_balance()));

    expect(find.bySemanticsIdentifier('wallet_back'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('wallet_cash_disclaimer'),
      findsOneWidget,
    );
  });

  testWidgets('redesign-24: the top bar renders in the FAILED state too', (
    tester,
  ) async {
    await pump(
      tester,
      repo: _ScriptedWalletRepository(_balance(), throws: true),
    );

    // The in-body bar is not a Scaffold appBar, so it survives the error state.
    expect(find.bySemanticsIdentifier('wallet_back'), findsOneWidget);
  });

  testWidgets('redesign-24: the 10% in the affordability copy derives from '
      'kJeebCommissionPercent', (tester) async {
    await pump(tester, repo: _ScriptedWalletRepository(_balance()));

    expect(
      find.textContaining('$kJeebCommissionPercent%'),
      findsWidgets,
      reason: 'the single-rate rule: no screen may spell the rate out',
    );
  });

  testWidgets(
    'redesign-24: RTL renders and the hero amount stays LTR-isolated',
    (tester) async {
      await pump(
        tester,
        repo: _ScriptedWalletRepository(_balance()),
        locale: const Locale('ar'),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsIdentifier('wallet_available_balance'),
        findsOneWidget,
      );
      // MoneyFormat wraps every amount in a Unicode LTR isolate (U+2066) so the
      // symbol does not migrate to the wrong side of the digits under RTL.
      expect(find.textContaining('\u2066'), findsWidgets);
    },
  );

  // \u2500\u2500 MIDNIGHT R4 \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

  testWidgets('R4: reserved-now is re-homed inside the balance card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(tester, repo: _ScriptedWalletRepository(_balance()));

    expect(
      find.descendant(
        of: find.bySemanticsIdentifier('wallet_available_balance'),
        matching: find.bySemanticsIdentifier('wallet_reserved_now'),
      ),
      findsOneWidget,
      reason: 'the board folds the reserve stat into the bank-card footer',
    );
    expect(find.text('Reserved now'), findsOneWidget);
  });

  testWidgets('R4: the gift pill carries the board\'s "included" clause', (
    tester,
  ) async {
    await pump(tester, repo: _ScriptedWalletRepository(_balance(gift: 5)));
    expect(find.textContaining('starter credit included'), findsOneWidget);
    expect(find.textContaining('non-cash, non-withdrawable'), findsOneWidget);
  });

  testWidgets('COD boundary: customer cash never enters Jeeber fee balance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pump(tester, repo: _ScriptedWalletRepository(_balance()));

    expect(find.text('Jeeber fee balance'), findsOneWidget);
    expect(
      find.text('Customer cash never enters this fee balance.'),
      findsOneWidget,
    );
    expect(find.text('Add fee balance'), findsOneWidget);
    expect(find.textContaining('card', findRichText: true), findsNothing);
    expect(find.textContaining('UPG', findRichText: true), findsNothing);
  });

  testWidgets('R4: Top up is the accent CTA and the fee link is not', (
    tester,
  ) async {
    await pump(tester, repo: _ScriptedWalletRepository(_balance()));

    JeebCtaButton cta(String id) => tester
        .widgetList<JeebCtaButton>(find.byType(JeebCtaButton))
        .firstWhere((b) => b.identifier == id);

    expect(cta('wallet_topup_cta').variant, JeebCtaVariant.accent);
    expect(
      cta('wallet_how_fees_work').variant,
      JeebCtaVariant.text,
      reason:
          'R4 draws the fee link periwinkle \u2014 Top up is the only orange',
    );
  });

  testWidgets('R4: the loading state is the JeebEmptyState family', (
    tester,
  ) async {
    await pump(tester, repo: const _NeverWalletRepository());
    expect(find.bySemanticsIdentifier('wallet_loading'), findsOneWidget);
  });

  testWidgets('R4: the error state is the JeebEmptyState family with a retry', (
    tester,
  ) async {
    await pump(
      tester,
      repo: _ScriptedWalletRepository(_balance(), throws: true),
    );
    expect(find.bySemanticsIdentifier('wallet_load_error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
