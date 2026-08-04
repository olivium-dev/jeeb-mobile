import 'package:equatable/equatable.dart';

import '../domain/wallet_ledger_repository.dart';

enum WalletLedgerStatus {
  initial,

  loading,

  loaded,

  failed,
}

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

  final List<WalletLedgerEntry> entries;

  final int page;

  final bool hasMore;

  final bool loadingMore;

  final WalletLedgerFailure? error;

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
