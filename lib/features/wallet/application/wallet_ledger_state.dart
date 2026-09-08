import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/wallet_ledger_repository.dart';

enum WalletLedgerStatus { initial, loading, loaded, failed }

class WalletLedgerState extends Equatable {
  const WalletLedgerState({
    this.status = WalletLedgerStatus.initial,
    this.entries = const <WalletLedgerEntry>[],
    this.page = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.error,
    this.failure,
    this.refreshError,
    this.loadMoreError = false,
    this.loadMoreFailure,
    this.unrenderableCount = 0,
  });

  final WalletLedgerStatus status;

  final List<WalletLedgerEntry> entries;

  final int page;

  final bool hasMore;

  final bool loadingMore;

  final WalletLedgerFailure? error;

  /// The classified cold-load failure the error rung renders.
  final AppFailure? failure;

  /// A failed refresh over rows still on screen (LR-08).
  final AppFailure? refreshError;

  final bool loadMoreError;

  /// The classified page-append failure, so the footer copy is kind-aware.
  final AppFailure? loadMoreFailure;

  /// Rows the gateway sent that could not be read as money (UX-17).
  final int unrenderableCount;

  bool get hasEntries => entries.isNotEmpty;

  WalletLedgerState copyWith({
    WalletLedgerStatus? status,
    List<WalletLedgerEntry>? entries,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    WalletLedgerFailure? error,
    AppFailure? failure,
    bool clearError = false,
    AppFailure? refreshError,
    bool clearRefreshError = false,
    bool? loadMoreError,
    AppFailure? loadMoreFailure,
    int? unrenderableCount,
  }) {
    return WalletLedgerState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      failure: clearError ? null : (failure ?? this.failure),
      refreshError: clearRefreshError
          ? null
          : (refreshError ?? this.refreshError),
      loadMoreError: loadMoreError ?? this.loadMoreError,
      loadMoreFailure: (loadMoreError ?? this.loadMoreError)
          ? (loadMoreFailure ?? this.loadMoreFailure)
          : null,
      unrenderableCount: unrenderableCount ?? this.unrenderableCount,
    );
  }

  @override
  List<Object?> get props => [
    status,
    entries,
    page,
    hasMore,
    loadingMore,
    error,
    failure,
    refreshError,
    loadMoreError,
    loadMoreFailure,
    unrenderableCount,
  ];
}
