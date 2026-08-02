// Shared dev-only fixtures for `TransactionDetailScreen` (JM-056).

import 'dart:async';

import 'package:jeeb_mobile/core/jeeb_commission.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_ledger_repository.dart'
    show WalletLedgerType;
import 'package:jeeb_mobile/features/wallet/domain/wallet_transaction_repository.dart';

/// Canned [WalletTransactionRepository] — every id resolves to [transaction],
/// with no latency. No Dio, no GetIt, no network.
/// Deliberately id-BLIND, unlike the shipped stub it replaces: a fixture that
class TransactionDetailScreenFakeRepository
    implements WalletTransactionRepository {
  const TransactionDetailScreenFakeRepository(this.transaction);

  /// What `GET /v1/jeeb/wallet/ledger/:id` (W3m) resolves to.
  final WalletTransaction transaction;

  @override
  Future<WalletTransaction> fetchTransaction(String id) async => transaction;
}

/// A read that never lands, holding the screen on
/// `TransactionDetailStatus.loading` for as long as the surface is open.
/// [TransactionDetailCubit.load] emits `loading` and only leaves it when the
class TransactionDetailScreenStalledRepository
    implements WalletTransactionRepository {
  const TransactionDetailScreenStalledRepository();

  @override
  Future<WalletTransaction> fetchTransaction(String id) =>
      Completer<WalletTransaction>().future;
}

/// A read that always throws a TYPED [WalletTransactionFailure], which is how
/// the live repository fails — not a null and not a synthetic empty row.
/// The specific value picks which of the two error strings the screen renders:
class TransactionDetailScreenFailingRepository
    implements WalletTransactionRepository {
  const TransactionDetailScreenFailingRepository(this.failure);

  final WalletTransactionFailure failure;

  @override
  Future<WalletTransaction> fetchTransaction(String id) async {
    throw WalletTransactionRepositoryException(failure);
  }
}

/// The richest row the screen renders, and the one the JM-056 ACs are written
/// against: a won offer's platform fee, carrying the EXACT 10% rate and the
const WalletTransaction transactionDetailScreenFeeWonRow = WalletTransaction(
  id: 'off-stub-1001',
  type: WalletLedgerType.feeWon,
  amount: 1.5,
  sign: -1,
  currency: 'USD',
  timestamp: '2026-06-19T10:00:00Z',
  title: 'Platform fee ($kJeebCommissionPercent%)',
  ref: 'off-stub-1001',
  offerId: 'off-stub-1001',
  orderId: 'req-stub-1001',
  pinnedPrice: 15.0,
  feeRate: kJeebCommissionRate,
);

/// A resolved dispute credited back to the wallet (D2).
/// Mirrors the shipped stub's refund branch EXACTLY, `orderId` included — and
const WalletTransaction transactionDetailScreenRefundRow = WalletTransaction(
  id: 'txn-refund-001',
  type: WalletLedgerType.refund,
  amount: 6.0,
  sign: 1,
  currency: 'USD',
  timestamp: '2026-06-19T10:00:00Z',
  title: 'Dispute refund',
  ref: 'dispute-stub-txn-refund-001',
  disputeId: 'dispute-client-001',
  orderId: 'req-stub-txn-refund-001',
);

/// The layout ceiling: an offer reserve whose reference is a gateway GUID.
/// `ref` is the W3m field the screen prints verbatim, and the gateway is .NET —
const WalletTransaction transactionDetailScreenGuidRefRow = WalletTransaction(
  id: 'led-9f3c1d2e',
  type: WalletLedgerType.reserve,
  amount: 2.4,
  sign: -1,
  currency: 'USD',
  timestamp: '2026-07-30T21:45:00Z',
  title: 'Offer reserve held',
  ref: 'off-9f3c1d2e-4b7a-11f0-9cd6-0242ac120002',
  offerId: 'off-9f3c1d2e-4b7a-11f0-9cd6-0242ac120002',
  orderId: 'req-6b1d0c94-4b7a-11f0-9cd6-0242ac120002',
);

/// The floor: the leanest row W3m can return.
/// The approval starter credit carries no reference, no offer, no order and no
const WalletTransaction transactionDetailScreenMinimalRow = WalletTransaction(
  id: 'led-gift-001',
  type: WalletLedgerType.gift,
  amount: 50.0,
  sign: 1,
  currency: 'USD',
  timestamp: '',
);

/// A ledger type this build's enum does not know (`unknown`).
/// W3m is free to add ledger kinds without the app shipping, and
const WalletTransaction transactionDetailScreenUnknownTypeRow =
    WalletTransaction(
  id: 'led-adj-7781',
  type: WalletLedgerType.unknown,
  amount: 3.25,
  sign: -1,
  currency: 'USD',
  timestamp: '2026-07-28T06:05:00Z',
  title: 'Manual ops adjustment',
  ref: 'adj-manual-7781',
);
