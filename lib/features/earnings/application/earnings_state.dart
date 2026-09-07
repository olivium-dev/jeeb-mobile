import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../../wallet/domain/wallet_repository.dart';
import '../domain/earnings_repository.dart';
import '../domain/earnings_summary.dart';

enum EarningsViewMode { loading, ready, error }

enum EarningsExportMode { idle, exporting, done, error }

class EarningsState extends Equatable {
  const EarningsState({
    this.mode = EarningsViewMode.loading,
    this.summary,
    this.failure,
    this.refreshError,
    this.period = EarningsPeriod.week,
    this.exportMode = EarningsExportMode.idle,
    this.exportFailure,
    this.exportedFilePath,
    this.walletBalance,
  });

  final EarningsViewMode mode;
  final EarningsSummary? summary;

  /// The classified cold-load failure; the screen resolves its copy.
  final AppFailure? failure;

  /// A refresh that failed over a dashboard still on screen (LR-16).
  final AppFailure? refreshError;

  final EarningsPeriod period;
  final EarningsExportMode exportMode;

  /// The classified export failure — never an English sentence from a cubit.
  final AppFailure? exportFailure;
  final String? exportedFilePath;

  /// The Jeeber's wallet snapshot (W1m), fetched once per mount so the footer
  /// pill can show a REAL balance. Stays null when the wallet read is
  /// unavailable or fails — the pill then renders without the balance suffix
  /// rather than showing a fabricated `$0.00`.
  final WalletBalance? walletBalance;

  EarningsState copyWith({
    EarningsViewMode? mode,
    EarningsSummary? summary,
    AppFailure? failure,
    bool clearError = false,
    AppFailure? refreshError,
    bool clearRefreshError = false,
    EarningsPeriod? period,
    EarningsExportMode? exportMode,
    AppFailure? exportFailure,
    bool clearExportError = false,
    String? exportedFilePath,
    WalletBalance? walletBalance,
  }) {
    return EarningsState(
      mode: mode ?? this.mode,
      summary: summary ?? this.summary,
      failure: clearError ? null : (failure ?? this.failure),
      refreshError: clearRefreshError
          ? null
          : (refreshError ?? this.refreshError),
      period: period ?? this.period,
      exportMode: exportMode ?? this.exportMode,
      exportFailure: clearExportError
          ? null
          : (exportFailure ?? this.exportFailure),
      exportedFilePath: exportedFilePath ?? this.exportedFilePath,
      walletBalance: walletBalance ?? this.walletBalance,
    );
  }

  @override
  List<Object?> get props => [
    mode,
    summary,
    failure,
    refreshError,
    period,
    exportMode,
    exportFailure,
    exportedFilePath,
    walletBalance,
  ];
}
