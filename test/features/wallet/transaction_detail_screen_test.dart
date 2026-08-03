import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/wallet/domain/wallet_ledger_repository.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_transaction_repository.dart';
import 'package:jeeb_mobile/features/wallet/presentation/transaction_detail_screen.dart';

import '../../support/sync_app_localizations.dart';

class _ScriptedTxnRepository implements WalletTransactionRepository {
  _ScriptedTxnRepository(this._txn, {this.failure});

  final WalletTransaction _txn;
  final WalletTransactionFailure? failure;

  @override
  Future<WalletTransaction> fetchTransaction(String id) async {
    final f = failure;
    if (f != null) {
      throw WalletTransactionRepositoryException(f);
    }
    return _txn;
  }
}

WalletTransaction _txn({
  required WalletLedgerType type,
  int sign = -1,
  double amount = 1.5,
  String? offerId,
  String? orderId,
  String? disputeId,
  double? pinnedPrice,
  double? feeRate,
}) =>
    WalletTransaction(
      id: 'led-1',
      type: type,
      amount: amount,
      sign: sign,
      currency: 'USD',
      timestamp: '2026-06-19T10:00:00Z',
      ref: offerId ?? disputeId,
      offerId: offerId,
      orderId: orderId,
      disputeId: disputeId,
      pinnedPrice: pinnedPrice,
      feeRate: feeRate,
    );

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required WalletTransactionRepository repo,
  }) async {
    await tester.pumpWidget(
      wrapForTest(
        TransactionDetailScreen(transactionId: 'led-1', repository: repo),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('AC: txn_detail_root renders for a loaded row', (tester) async {
    await pump(
      tester,
      repo: _ScriptedTxnRepository(
        _txn(
          type: WalletLedgerType.feeWon,
          orderId: 'req-1',
          offerId: 'off-1',
          pinnedPrice: 15,
          feeRate: 0.1,
        ),
      ),
    );

    expect(find.bySemanticsIdentifier('txn_detail_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('txn_detail_amount'), findsOneWidget);
  });

  testWidgets('D37: fee_won shows exact 10% rate + pinned price + order link',
      (tester) async {
    await pump(
      tester,
      repo: _ScriptedTxnRepository(
        _txn(
          type: WalletLedgerType.feeWon,
          orderId: 'req-1',
          offerId: 'off-1',
          pinnedPrice: 15,
          feeRate: 0.1,
        ),
      ),
    );

    expect(find.bySemanticsIdentifier('txn_detail_fee_rate'), findsOneWidget);
    expect(
        find.bySemanticsIdentifier('txn_detail_pinned_price'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
    expect(find.bySemanticsIdentifier('txn_detail_order_link'), findsOneWidget);
    expect(find.bySemanticsIdentifier('txn_detail_dispute_link'), findsNothing);
  });

  testWidgets('D2: refund shows the dispute link, not the order link',
      (tester) async {
    await pump(
      tester,
      repo: _ScriptedTxnRepository(
        _txn(
          type: WalletLedgerType.refund,
          sign: 1,
          amount: 9,
          disputeId: 'dispute-1',
        ),
      ),
    );

    expect(
        find.bySemanticsIdentifier('txn_detail_dispute_link'), findsOneWidget);
    expect(find.bySemanticsIdentifier('txn_detail_order_link'), findsNothing);
    expect(find.bySemanticsIdentifier('txn_detail_fee_rate'), findsNothing);
    expect(find.bySemanticsIdentifier('txn_detail_pinned_price'), findsNothing);
  });

  testWidgets('D2: penalty shows the dispute link', (tester) async {
    await pump(
      tester,
      repo: _ScriptedTxnRepository(
        _txn(
          type: WalletLedgerType.penalty,
          sign: -1,
          amount: 2,
          disputeId: 'dispute-2',
        ),
      ),
    );

    expect(
        find.bySemanticsIdentifier('txn_detail_dispute_link'), findsOneWidget);
    expect(find.bySemanticsIdentifier('txn_detail_order_link'), findsNothing);
  });

  testWidgets('reserve shows the order link, no fee breakdown, no dispute link',
      (tester) async {
    await pump(
      tester,
      repo: _ScriptedTxnRepository(
        _txn(
          type: WalletLedgerType.reserve,
          orderId: 'req-9',
          offerId: 'off-9',
        ),
      ),
    );

    expect(find.bySemanticsIdentifier('txn_detail_order_link'), findsOneWidget);
    expect(find.bySemanticsIdentifier('txn_detail_dispute_link'), findsNothing);
    expect(find.bySemanticsIdentifier('txn_detail_fee_rate'), findsNothing);
  });

  testWidgets('top-up shows neither the order link nor the dispute link',
      (tester) async {
    await pump(
      tester,
      repo: _ScriptedTxnRepository(
        _txn(type: WalletLedgerType.topup, sign: 1, amount: 40),
      ),
    );

    expect(find.bySemanticsIdentifier('txn_detail_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('txn_detail_order_link'), findsNothing);
    expect(find.bySemanticsIdentifier('txn_detail_dispute_link'), findsNothing);
  });

  testWidgets('failed load surfaces the error state; root survives',
      (tester) async {
    await pump(
      tester,
      repo: _ScriptedTxnRepository(
        _txn(type: WalletLedgerType.feeWon),
        failure: WalletTransactionFailure.notFound,
      ),
    );

    expect(find.bySemanticsIdentifier('txn_detail_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('txn_detail_amount'), findsNothing);
    expect(find.bySemanticsIdentifier('txn_detail_order_link'), findsNothing);
  });
}
