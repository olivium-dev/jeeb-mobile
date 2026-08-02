// Shared dev-only fixtures for `TransactionDetailScreen` (JM-056).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_11_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/wallet/presentation/transaction_detail_screen.dart`.
//
// The catalog owned two private fakes (`_PendingWalletTransactionRepository`,
// `_FailingWalletTransactionRepository`) and got its two "loaded" rows from the
// SHIPPED [StubWalletTransactionRepository] — the DI default, whose branch is
// keyed off the id containing "refund"/"penalty". Leaning on shipping code for
// a fixture is the drift this file exists to prevent twice over: the rows the
// catalog shows would change the day the DI swap to
// `DioWalletTransactionRepository` lands (CTO-D2, REQUESTED in
// 50_ROUTE_REQUESTS.md) and the stub is deleted, and a preview section copying
// those rows by hand would then disagree with the catalog. Both surfaces now
// build from the rows below, plus the four states the stub cannot express.
//
// The rows reproduce the stub field for field, with ONE deliberate difference.
// The stub derives its reference fields from the id it is handed —
// `ref: 'off-stub-$id'`, `orderId: 'req-stub-$id'` — and the catalog handed it
// `transactionId: 'off-stub-1001'`, an id that already carried that prefix. The
// fee-won row therefore rendered `off-stub-off-stub-1001` and
// `req-stub-off-stub-1001` on screen: a doubled prefix, an artifact of the
// call site rather than anything a gateway would return. [transactionDetailScreenFeeWonRow]
// carries the un-doubled `off-stub-1001` / `req-stub-1001` instead. Nothing the
// screen branches on changed — type, amount, sign, currency, timestamp, title,
// pinnedPrice and feeRate are the stub's values exactly, and every outbound
// edge is gated on a field being non-null rather than on its text.
// [transactionDetailScreenRefundRow] needed no such correction and IS
// byte-for-byte the stub's refund branch for `txn-refund-001`.
//
// Everything here is a LOCAL fake: `TransactionDetailScreen` takes a
// `repository:` seam, so neither surface reaches `_resolveRepository()`'s
// `sl<>()` branch. Network-free by construction, not merely by the guard the
// hosts install.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import 'package:jeeb_mobile/core/jeeb_commission.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_ledger_repository.dart'
    show WalletLedgerType;
import 'package:jeeb_mobile/features/wallet/domain/wallet_transaction_repository.dart';

/// Canned [WalletTransactionRepository] — every id resolves to [transaction],
/// with no latency. No Dio, no GetIt, no network.
///
/// Deliberately id-BLIND, unlike the shipped stub it replaces: a fixture that
/// switches rows on a substring of the id is a fixture whose state depends on
/// the route argument, and both hosts pass an id that reads like a label.
///
/// `const`-constructible so the catalog can keep building
/// `const TransactionDetailScreen(repository: ...)`.
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
///
/// [TransactionDetailCubit.load] emits `loading` and only leaves it when the
/// future completes, so an unsettleable [Completer] is the only way to inspect
/// the spinner without a real slow connection. It holds no timer and no
/// subscription — it simply never settles.
class TransactionDetailScreenStalledRepository
    implements WalletTransactionRepository {
  const TransactionDetailScreenStalledRepository();

  @override
  Future<WalletTransaction> fetchTransaction(String id) =>
      Completer<WalletTransaction>().future;
}

/// A read that always throws a TYPED [WalletTransactionFailure], which is how
/// the live repository fails — not a null and not a synthetic empty row.
///
/// The specific value picks which of the two error strings the screen renders:
/// `notFound` → "This transaction could not be found.", everything else →
/// "We couldn't load this transaction. Please try again."
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
/// pinned accepted price the 10% was taken from (D37) plus a resolved order id,
/// so `txn_detail_fee_rate`, `txn_detail_pinned_price` and
/// `txn_detail_order_link` are all on screen at once.
///
/// [feeRate] is [kJeebCommissionRate], not a literal `0.1`: this row is what a
/// Jeeber reads on a fee row, and the app-wide constant exists precisely so the
/// number cannot drift per surface.
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
///
/// Mirrors the shipped stub's refund branch EXACTLY, `orderId` included — and
/// that field is the point. The screen gates each outbound edge on the DATA
/// (`hasOrderLink` / `hasDisputeLink`), not on the row's type, so a refund that
/// happens to carry an order id renders BOTH `txn_detail_dispute_link` and
/// `txn_detail_order_link`. The screen's own doc comment says the order link is
/// "shown for reserve / fee_won / released rows with an order", and
/// `test/features/wallet/transaction_detail_screen_test.dart` asserts a refund
/// shows no order link — but its fixture omits `orderId`, so the assertion
/// passes while the row that actually ships does the opposite.
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
///
/// `ref` is the W3m field the screen prints verbatim, and the gateway is .NET —
/// a 36-character GUID behind a short prefix is the ordinary shape of a real
/// id, not a contrived one. `_DetailRow` lays its value out with NO width
/// constraint (only the label is `Expanded`), so this is the row that starves
/// the label and then overflows.
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
///
/// The approval starter credit carries no reference, no offer, no order and no
/// dispute, and this fixture also drops the timestamp — a field the screen
/// guards with `if (txn.timestamp.isNotEmpty)`, so the date row disappears too.
/// What is left is a heading, a paragraph and one amount: the closest thing
/// this screen has to an empty state, and the only fixture that exercises the
/// timestamp guard.
const WalletTransaction transactionDetailScreenMinimalRow = WalletTransaction(
  id: 'led-gift-001',
  type: WalletLedgerType.gift,
  amount: 50.0,
  sign: 1,
  currency: 'USD',
  timestamp: '',
);

/// A ledger type this build's enum does not know (`unknown`).
///
/// W3m is free to add ledger kinds without the app shipping, and
/// `WalletLedgerType.unknown` is where every unmapped `type` lands. The row
/// carries a server-supplied [title] — which the screen NEVER reads — so this
/// fixture also shows what a user gets instead: the generic "Transaction"
/// heading over the generic `txnDetailBody` paragraph.
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
