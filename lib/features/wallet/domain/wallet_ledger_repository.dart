// PURE Dart. No Flutter / Dio / GetIt imports (40_GUARDRAILS_ARCH §1 layer rules).
//
// Wallet ledger domain contract (JM-055). The wire format is owned by backenders
// (CTO-D2: W2m `GET /v1/jeeb/wallet/ledger`), sourced from decisions
// D41/D1/D37/D2. W2m is LIVE on :4010 (42_GUARDRAILS_MOCK "W2 mock closeout"),
// so the DI default is the real `DioWalletLedgerRepository`.

/// The typed kind of a wallet ledger movement (JM-055, D41/D1/D37/D2). Maps 1:1
/// to W2m's `type` enum so the UI renders the per-type icon/sign/copy.
enum WalletLedgerType {
  reserve,
  feeWon,
  released,
  refund,
  penalty,
  topup,
  gift,
  unknown,
}

/// A single ledger row (W2m row shape `{ id, type, amount, sign, ref, ts }`).
class WalletLedgerEntry {
  const WalletLedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.sign,
    required this.ref,
    required this.timestamp,
    this.currency,
  });

  final String id;
  final WalletLedgerType type;
  final double amount;

  /// `+1` credit / `-1` debit (W2m `sign`).
  final int sign;

  /// The originating reference (offer id, dispute id, …) — W2m `ref`.
  final String ref;

  /// ISO-8601 timestamp string (W2m `ts`).
  final String timestamp;

  final String? currency;
}

/// One page of the paginated ledger (W2m envelope
/// `{ items, page, pageSize, totalCount, totalPages, cursor }`).
class WalletLedgerPage {
  const WalletLedgerPage({
    required this.entries,
    required this.page,
    required this.totalPages,
  });

  final List<WalletLedgerEntry> entries;
  final int page;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

/// Typed failures the ledger data source can surface.
enum WalletLedgerFailure { network, unauthorized, unknown }

class WalletLedgerRepositoryException implements Exception {
  const WalletLedgerRepositoryException(this.failure, [this.message]);

  final WalletLedgerFailure failure;
  final String? message;

  @override
  String toString() =>
      'WalletLedgerRepositoryException($failure, $message)';
}

/// Domain contract for the wallet activity list (JM-055).
abstract class WalletLedgerRepository {
  /// Fetch one page of the jeeber's ledger (W2m). Throws
  /// [WalletLedgerRepositoryException] on failure.
  Future<WalletLedgerPage> fetchLedger({int page, int pageSize});
}
