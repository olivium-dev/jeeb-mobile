// PURE Dart. No Flutter / Dio / GetIt imports (40_GUARDRAILS_ARCH §1 layer rules).
//
// Wallet transaction-by-id domain contract (JM-056). The wire format is owned by
// backenders (CTO-D2: W3m `GET /v1/jeeb/wallet/ledger/:id`), sourced from
// decisions D37/D1/D2/D41. W3m is now LIVE on :4010 (42_GUARDRAILS_MOCK "FINAL
// WAVE (W3+W4) mock closeout"); the data-bound ACs validate once DI repoints the
// default from the INTEGRATOR-STUB to `DioWalletTransactionRepository`
// (REQUESTED in 50_ROUTE_REQUESTS.md, "JM-056 DI SWAP").
//
// W3m row shape (a SUPERSET of the W2m list row):
//   { id, type, category, title, amount, sign, ref, ts, currency,
//     feeRate?, pinnedPrice?, offerId?, orderId?, disputeId? }

import 'wallet_ledger_repository.dart' show WalletLedgerType;

/// The per-type detail of a single ledger row (W3m). Re-uses the
/// [WalletLedgerType] enum so the activity list (JM-055) and the detail screen
/// (JM-056) classify rows identically.
///
/// Per-type extras (mirroring the W3m wire, 42_GUARDRAILS_MOCK §4):
///   * fee_won            — [feeRate] (exact 0.1 = 10%, D37) + [pinnedPrice]
///                          (the accepted offer price the 10% was taken from) +
///                          [offerId] + [orderId] (→ `txn_detail_order_link`).
///   * reserve / released — [offerId] + [orderId] (→ `txn_detail_order_link`).
///   * refund / penalty   — [disputeId] (→ `txn_detail_dispute_link`, D2).
///   * topup / gift       — no extras; [title] + the row carry the copy.
class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.sign,
    required this.currency,
    required this.timestamp,
    this.title,
    this.ref,
    this.offerId,
    this.orderId,
    this.disputeId,
    this.pinnedPrice,
    this.feeRate,
  });

  final String id;
  final WalletLedgerType type;
  final double amount;

  /// `+1` credit / `-1` debit (W3m `sign`).
  final int sign;
  final String currency;

  /// ISO-8601 timestamp string (W3m `ts`).
  final String timestamp;

  /// A human-readable (mock-dev) title; the app localizes off [type] but keeps
  /// this as a fallback when no localized copy exists for an `unknown` row.
  final String? title;

  /// The originating reference (offer id, dispute id, …) — W3m `ref`.
  final String? ref;

  /// reserve / fee_won / released — the offer this row is tied to (W3m `offerId`).
  final String? offerId;

  /// reserve / fee_won / released — the order/request the offer belongs to, for
  /// `txn_detail_order_link` → order-summary-pinned (W3m `orderId`). Null if the
  /// offer's request could not be resolved.
  final String? orderId;

  /// refund / penalty — the dispute this adjustment resolves, for
  /// `txn_detail_dispute_link` → dispute-open-evidence (W3m `disputeId`, D2).
  final String? disputeId;

  /// fee_won — the pinned accepted offer price the 10% was taken from (D37).
  final double? pinnedPrice;

  /// fee_won — the platform fee RATE as a fraction (0.1 == 10%, W3m `feeRate`,
  /// D37/D44). The view renders it as a percent.
  final double? feeRate;

  /// Whether this row carries an order/summary link (reserve/fee_won/released
  /// with a resolved [orderId]).
  bool get hasOrderLink => orderId != null && orderId!.isNotEmpty;

  /// Whether this row carries a dispute link (refund/penalty with a [disputeId]).
  bool get hasDisputeLink => disputeId != null && disputeId!.isNotEmpty;

  /// fee_won — the exact platform fee percent (e.g. `10.0`), derived from
  /// [feeRate]. Null for non-fee rows.
  double? get feePercent => feeRate == null ? null : feeRate! * 100;
}

enum WalletTransactionFailure { network, notFound, unauthorized, unknown }

class WalletTransactionRepositoryException implements Exception {
  const WalletTransactionRepositoryException(this.failure, [this.message]);

  final WalletTransactionFailure failure;
  final String? message;

  @override
  String toString() =>
      'WalletTransactionRepositoryException($failure, $message)';
}

/// Domain contract for the transaction-detail screen (JM-056).
abstract class WalletTransactionRepository {
  /// Fetch a single ledger row by id (W3m). Throws
  /// [WalletTransactionRepositoryException] on failure.
  Future<WalletTransaction> fetchTransaction(String id);
}
