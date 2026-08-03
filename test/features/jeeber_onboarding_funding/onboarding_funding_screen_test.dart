// Widget tests for OnboardingFundingScreen (JM-041), added with the
// redesign-2026-08 re-skin: the screen had no widget coverage, and the re-skin
// moved every element it owns (OMDSAppBar → JeebTopBar, section cards → navy
// hero + info note, OMDS buttons → kit CTAs). These pin what the restyle must
// never break.
//
//   AC1: the four frozen identifiers render — funding_explainer,
//        funding_topup_cta, funding_continue_cta (+ funding_back).
//   FAIL-SAFE (40_GUARDRAILS_ARCH §3): a failed wallet fetch hides only the
//        enrichment amounts; the explainer and both CTAs still render.
//   Enrichment: funding_starter_credit_amount / funding_reserved_now_amount
//        appear only when their amounts are non-zero.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_onboarding_funding/presentation/onboarding_funding_screen.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';

import '../../support/sync_app_localizations.dart';

class _ScriptedWalletRepository implements WalletRepository {
  const _ScriptedWalletRepository(this._balance, {this.throws = false});

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

const WalletBalance _enriched = WalletBalance(
  availableBalance: 40,
  affordabilityState: WalletAffordability.enough,
  reservedNow: 4,
  giftCredit: 5,
  currency: 'USD',
);

const WalletBalance _empty = WalletBalance(
  availableBalance: 0,
  affordabilityState: WalletAffordability.empty,
  reservedNow: 0,
  giftCredit: 0,
  currency: 'USD',
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required WalletRepository repo,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      wrapForTest(
        OnboardingFundingScreen(repository: repo),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('AC1: explainer, both CTAs and the back circle render',
      (tester) async {
    await pump(tester, repo: const _ScriptedWalletRepository(_enriched));

    expect(find.bySemanticsIdentifier('funding_explainer'), findsOneWidget);
    expect(find.bySemanticsIdentifier('funding_topup_cta'), findsOneWidget);
    expect(find.bySemanticsIdentifier('funding_continue_cta'), findsOneWidget);
    expect(find.bySemanticsIdentifier('funding_back'), findsOneWidget);
  });

  testWidgets('enrichment: both live amounts render when non-zero',
      (tester) async {
    await pump(tester, repo: const _ScriptedWalletRepository(_enriched));

    expect(
      find.bySemanticsIdentifier('funding_starter_credit_amount'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('funding_reserved_now_amount'),
      findsOneWidget,
    );
  });

  testWidgets('zero amounts drop the enrichment, never the explainer',
      (tester) async {
    await pump(tester, repo: const _ScriptedWalletRepository(_empty));

    expect(find.bySemanticsIdentifier('funding_explainer'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('funding_starter_credit_amount'),
      findsNothing,
    );
    expect(
      find.bySemanticsIdentifier('funding_reserved_now_amount'),
      findsNothing,
    );
  });

  testWidgets('fail-safe: a failed wallet fetch keeps the explainer + CTAs',
      (tester) async {
    await pump(
      tester,
      repo: const _ScriptedWalletRepository(_enriched, throws: true),
    );

    expect(find.bySemanticsIdentifier('funding_explainer'), findsOneWidget);
    expect(find.bySemanticsIdentifier('funding_topup_cta'), findsOneWidget);
    expect(find.bySemanticsIdentifier('funding_continue_cta'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('funding_starter_credit_amount'),
      findsNothing,
    );
  });

  testWidgets('RTL smoke: the Arabic locale lays out without overflow',
      (tester) async {
    await pump(
      tester,
      repo: const _ScriptedWalletRepository(_enriched),
      locale: const Locale('ar'),
    );

    expect(find.bySemanticsIdentifier('funding_explainer'), findsOneWidget);
    expect(find.bySemanticsIdentifier('funding_continue_cta'), findsOneWidget);
  });
}
