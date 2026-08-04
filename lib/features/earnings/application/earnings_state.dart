import 'package:equatable/equatable.dart';

import '../../wallet/domain/wallet_repository.dart';
import '../domain/earnings_repository.dart';
import '../domain/earnings_summary.dart';

enum EarningsViewMode { loading, ready, error }

enum EarningsExportMode { idle, exporting, done, error }

class EarningsState extends Equatable {
  const EarningsState({
    this.mode = EarningsViewMode.loading,
    this.summary,
    this.errorMessage,
    this.period = EarningsPeriod.week,
    this.exportMode = EarningsExportMode.idle,
    this.exportError,
    this.exportedFilePath,
    this.walletBalance,
  });

  final EarningsViewMode mode;
  final EarningsSummary? summary;
  final String? errorMessage;
  final EarningsPeriod period;
  final EarningsExportMode exportMode;
  final String? exportError;
  final String? exportedFilePath;

  /// The Jeeber's wallet snapshot (W1m), fetched once per mount so the footer
  /// pill can show a REAL balance. Stays null when the wallet read is
  /// unavailable or fails — the pill then renders without the balance suffix
  /// rather than showing a fabricated `$0.00`.
  final WalletBalance? walletBalance;

  EarningsState copyWith({
    EarningsViewMode? mode,
    EarningsSummary? summary,
    String? errorMessage,
    bool clearError = false,
    EarningsPeriod? period,
    EarningsExportMode? exportMode,
    String? exportError,
    bool clearExportError = false,
    String? exportedFilePath,
    WalletBalance? walletBalance,
  }) {
    return EarningsState(
      mode: mode ?? this.mode,
      summary: summary ?? this.summary,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      period: period ?? this.period,
      exportMode: exportMode ?? this.exportMode,
      exportError: clearExportError ? null : (exportError ?? this.exportError),
      exportedFilePath: exportedFilePath ?? this.exportedFilePath,
      walletBalance: walletBalance ?? this.walletBalance,
    );
  }

  @override
  List<Object?> get props => [
        mode,
        summary,
        errorMessage,
        period,
        exportMode,
        exportError,
        exportedFilePath,
        walletBalance,
      ];
}
