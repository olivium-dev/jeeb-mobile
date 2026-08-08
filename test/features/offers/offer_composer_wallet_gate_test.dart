// F1 — CTA pre-check (disable + inline reason) and wallet refresh via the
// PushRefreshSignals bus. UX only; server 402 stays authoritative (D35).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/application/push_refresh_signals.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/features/offers/domain/offer_submission_repository.dart';
import 'package:jeeb_mobile/features/offers/presentation/offer_submission_screen.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _InertRepo implements OfferSubmissionRepository {
  const _InertRepo();

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async {
    throw UnimplementedError();
  }
}

class _ScriptedWallet implements WalletRepository {
  _ScriptedWallet(this._balances);

  final List<WalletBalance> _balances;
  int fetchCount = 0;

  @override
  Future<WalletBalance> fetchBalance() async {
    final idx = fetchCount < _balances.length ? fetchCount : _balances.length - 1;
    fetchCount += 1;
    return _balances[idx];
  }
}

WalletBalance _wallet(double available) => WalletBalance(
      availableBalance: available,
      affordabilityState: WalletAffordability.enough,
      reservedNow: 0,
      giftCredit: 0,
      currency: 'USD',
    );

Widget _harness({
  required WalletRepository wallet,
  Stream<void>? walletRefreshSignals,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: OfferSubmissionScreen(
      requestId: 'req-1',
      submissionService: null,
      repository: const _InertRepo(),
      walletRepository: wallet,
      walletRefreshSignals: walletRefreshSignals,
      onWithdrawn: _noop,
    ),
  );
}

void _noop() {}

JeebCtaButton _sendCta(WidgetTester tester) => tester
    .widgetList<JeebCtaButton>(find.byType(JeebCtaButton))
    .firstWhere((b) => b.identifier == 'offer_composer_send_cta');

Future<void> _enterPrice(WidgetTester tester, String value) async {
  await tester.enterText(find.byType(EditableText).first, value);
  await tester.pumpAndSettle();
}

void main() {
  group('F1: CTA pre-check + disabled reason', () {
    testWidgets(
        'balance below the reserve disables the CTA and shows the reason',
        (tester) async {
      final handle = tester.ensureSemantics();
      // $8 price -> $0.80 reserve; $0.50 available is short.
      await tester.pumpWidget(_harness(wallet: _ScriptedWallet([_wallet(0.5)])));
      await tester.pumpAndSettle();

      await _enterPrice(tester, '8');

      expect(_sendCta(tester).isEnabled, isFalse);
      expect(
        find.bySemanticsIdentifier('offer_composer_insufficient_reason'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('balance covering the reserve keeps the CTA enabled, no reason',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(wallet: _ScriptedWallet([_wallet(6.4)])));
      await tester.pumpAndSettle();

      await _enterPrice(tester, '8');

      expect(_sendCta(tester).isEnabled, isTrue);
      expect(
        find.bySemanticsIdentifier('offer_composer_insufficient_reason'),
        findsNothing,
      );

      handle.dispose();
    });

    testWidgets('exact boundary (available == reserve) stays enabled',
        (tester) async {
      final handle = tester.ensureSemantics();
      // $8 price -> $0.80 reserve; available exactly $0.80.
      await tester.pumpWidget(_harness(wallet: _ScriptedWallet([_wallet(0.8)])));
      await tester.pumpAndSettle();

      await _enterPrice(tester, '8');

      expect(_sendCta(tester).isEnabled, isTrue);

      handle.dispose();
    });

    testWidgets('the gate applies the same way via the +1/-1 stepper',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(wallet: _ScriptedWallet([_wallet(0.05)])));
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('offer_composer_price_increment'),
      );
      await tester.pumpAndSettle();

      // $1.00 price -> $0.10 reserve, $0.05 available is short.
      expect(_sendCta(tester).isEnabled, isFalse);
      expect(
        find.bySemanticsIdentifier('offer_composer_insufficient_reason'),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('a null wallet snapshot never disables the CTA (server 402 '
        'stays authoritative, D35)', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(wallet: _NeverWallet()));
      await tester.pumpAndSettle();

      await _enterPrice(tester, '8');

      expect(_sendCta(tester).isEnabled, isTrue);
      expect(
        find.bySemanticsIdentifier('offer_composer_insufficient_reason'),
        findsNothing,
      );

      handle.dispose();
    });
  });

  group('F1: wallet refresh via PushRefreshSignals', () {
    testWidgets(
        'a RefreshTopic.wallet signal re-fetches the balance and clears the gate',
        (tester) async {
      final handle = tester.ensureSemantics();
      final bus = PushRefreshSignals();
      addTearDown(bus.dispose);
      // First read: short. Second read (after the signal): covers the reserve.
      final wallet = _ScriptedWallet([_wallet(0.5), _wallet(6.4)]);

      await tester.pumpWidget(_harness(
        wallet: wallet,
        walletRefreshSignals: bus.streamFor(const {RefreshTopic.wallet}),
      ));
      await tester.pumpAndSettle();
      await _enterPrice(tester, '8');
      expect(_sendCta(tester).isEnabled, isFalse);
      expect(wallet.fetchCount, 1);

      bus.signal(const {RefreshTopic.wallet});
      await tester.pumpAndSettle();

      expect(wallet.fetchCount, 2);
      expect(_sendCta(tester).isEnabled, isTrue);

      handle.dispose();
    });

    testWidgets('an unrelated topic (offers) does NOT re-fetch the wallet',
        (tester) async {
      final handle = tester.ensureSemantics();
      final bus = PushRefreshSignals();
      addTearDown(bus.dispose);
      final wallet = _ScriptedWallet([_wallet(6.4), _wallet(6.4)]);

      await tester.pumpWidget(_harness(
        wallet: wallet,
        walletRefreshSignals: bus.streamFor(const {RefreshTopic.wallet}),
      ));
      await tester.pumpAndSettle();
      expect(wallet.fetchCount, 1);

      bus.signal(const {RefreshTopic.offers});
      await tester.pumpAndSettle();

      expect(wallet.fetchCount, 1, reason: 'offers is not a wallet signal');

      handle.dispose();
    });
  });
}

/// A read that never lands — the CTA must stay enabled while `_wallet` is
/// still null (D35: the pre-check never blocks on a missing snapshot).
class _NeverWallet implements WalletRepository {
  @override
  Future<WalletBalance> fetchBalance() => Completer<WalletBalance>().future;
}
