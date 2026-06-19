import 'package:equatable/equatable.dart';

import '../domain/wallet_ledger_repository.dart';

/// Top-level UI status for wallet-activity-list (JM-055) — the canonical
/// 4-state machine (40_GUARDRAILS_ARCH §2.1 / §3; the D30 contract,
/// 42_GUARDRAILS_MOCK §5.1). `empty` is NOT a fifth status: it is `loaded` + an
/// empty [WalletLedgerState.entries].
enum WalletLedgerStatus {
  /// Cold load — nothing fetched yet.
  initial,

  /// First page is on the wire (full-screen skeletons, D73).
  loading,

  /// At least the first page has landed. A refresh / load-more keeps us here.
  loaded,

  /// Cold load (page 1) failed and there is nothing to show.
  failed,
}

/// Immutable state for the wallet ledger (the typed activity list).
///
/// [entries] is the accumulated, paginated ledger (newest-first; the cubit owns
/// the order, W2m serves it newest-first). [page] is the last page fetched and
/// [hasMore] mirrors the W2m envelope's `page < totalPages` so the screen knows
/// whether to fetch the next page on scroll-end (infinite scroll, JM-055 AC).
/// [loadingMore] gates the in-list "load-more" skeleton (D73) and de-dupes
/// concurrent page fetches. [error] is a typed [WalletLedgerFailure] surfaced
/// from the last FOREGROUND action (cold load / refresh) — never a raw
/// exception or string (40_GUARDRAILS_ARCH §2.1). A background load-more failure
/// is held in [loadMoreError] (a soft, retryable footer error) so it does NOT
/// tear down the already-rendered list.
class WalletLedgerState extends Equatable {
  const WalletLedgerState({
    this.status = WalletLedgerStatus.initial,
    this.entries = const <WalletLedgerEntry>[],
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.error,
    this.loadMoreError = false,
  });

  final WalletLedgerStatus status;

  /// Accumulated ledger rows in display order (newest first).
  final List<WalletLedgerEntry> entries;

  /// The highest page index successfully fetched (1-based; 0 = none yet).
  final int page;

  /// Whether a further page exists (drives infinite scroll).
  final bool hasMore;

  /// A next-page fetch is in flight (drives the in-list skeleton, de-dupes).
  final bool loadingMore;

  /// One-shot typed error from the last cold load / refresh.
  final WalletLedgerFailure? error;

  /// A load-more page fetch failed — a soft, retryable footer state that leaves
  /// the already-loaded rows intact.
  final bool loadMoreError;

  bool get hasEntries => entries.isNotEmpty;

  WalletLedgerState copyWith({
    WalletLedgerStatus? status,
    List<WalletLedgerEntry>? entries,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    WalletLedgerFailure? error,
    bool clearError = false,
    bool? loadMoreError,
  }) {
    return WalletLedgerState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      loadMoreError: loadMoreError ?? this.loadMoreError,
    );
  }

  @override
  List<Object?> get props =>
      [status, entries, page, hasMore, loadingMore, error, loadMoreError];
}
