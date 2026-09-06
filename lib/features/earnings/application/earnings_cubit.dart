import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/app_failure_mapper.dart';
import '../../wallet/domain/wallet_repository.dart';
import '../domain/earnings_repository.dart';
import 'earnings_state.dart';

class EarningsCubit extends Cubit<EarningsState> {
  EarningsCubit({
    required EarningsRepository repository,
    WalletRepository? walletRepository,
    this.jeeberId = '',
  }) : _repository = repository,
       _walletRepository = walletRepository ?? _resolveWalletRepository(),
       super(const EarningsState()) {
    loadEarnings();
    // Fire-and-forget, once per mount: the footer's wallet pill is a nicety,
    // so it must never gate or delay the earnings load it sits under.
    _loadWalletBalance();
  }

  /// Same DI seam as `offer_submission_screen.dart` — a host (or a test) that
  /// registers no wallet repository resolves null and never fetches, so every
  /// existing `EarningsCubit(repository: …)` call site keeps its exact
  /// emission sequence.
  static WalletRepository? _resolveWalletRepository() =>
      sl.isRegistered<WalletRepository>() ? sl<WalletRepository>() : null;

  final EarningsRepository _repository;
  final WalletRepository? _walletRepository;

  final String jeeberId;

  bool _inFlight = false;

  /// The cold load and the period change — the only two reads allowed to blank
  /// the dashboard to a skeleton (LR-16).
  Future<void> loadEarnings({EarningsPeriod? period}) async {
    if (_inFlight) return;
    final activePeriod = period ?? state.period;
    emit(
      state.copyWith(
        mode: EarningsViewMode.loading,
        clearError: true,
        clearRefreshError: true,
        period: activePeriod,
      ),
    );
    await _read(activePeriod, warm: false);
  }

  /// The pull-to-refresh target: keeps `ready` and the current summary, and
  /// raises a dismissible note when it fails.
  Future<void> refresh() async {
    if (_inFlight) return;
    await _read(state.period, warm: true);
  }

  Future<void> _read(EarningsPeriod period, {required bool warm}) async {
    _inFlight = true;
    try {
      final summary = await _repository.fetchEarnings(
        jeeberId: jeeberId,
        period: period,
      );
      emit(
        state.copyWith(
          mode: EarningsViewMode.ready,
          summary: summary,
          clearError: true,
          clearRefreshError: true,
        ),
      );
    } catch (e) {
      final failure = classifyEarningsFailure(e);
      emit(
        warm
            ? state.copyWith(refreshError: failure)
            : state.copyWith(mode: EarningsViewMode.error, failure: failure),
      );
    } finally {
      _inFlight = false;
    }
  }

  void clearRefreshError() {
    if (state.refreshError == null) return;
    emit(state.copyWith(clearRefreshError: true));
  }

  Future<void> exportPdf() async {
    // A double-tap on the export CTA would otherwise start two downloads.
    if (state.exportMode == EarningsExportMode.exporting) return;
    emit(
      state.copyWith(
        exportMode: EarningsExportMode.exporting,
        clearExportError: true,
      ),
    );
    try {
      final path = await _repository.exportEarningsPdf(
        jeeberId: jeeberId,
        period: state.period,
      );
      emit(
        state.copyWith(
          exportMode: EarningsExportMode.done,
          exportedFilePath: path,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          exportMode: EarningsExportMode.error,
          exportFailure: classifyEarningsFailure(e),
        ),
      );
    }
  }

  Future<void> _loadWalletBalance() async {
    final repo = _walletRepository;
    if (repo == null) return;
    try {
      final balance = await repo.fetchBalance();
      if (!isClosed) emit(state.copyWith(walletBalance: balance));
    } catch (e) {
      // A wallet read must never degrade the earnings screen: no error state,
      // no retry — but the swallow leaves evidence.
      Diag.event('earnings.wallet_read_failed', <String, Object?>{
        'kind': AppFailure.of(e).kind.name,
      });
    }
  }

  void resetExport() {
    emit(
      state.copyWith(
        exportMode: EarningsExportMode.idle,
        clearExportError: true,
      ),
    );
  }
}

/// Unwraps the repository's own classification so the kind survives.
AppFailure classifyEarningsFailure(Object error) {
  if (error is EarningsRepositoryException) {
    return error.failure ??
        switch (error.kind) {
          EarningsErrorKind.network => networkFailureFromReachability(),
          EarningsErrorKind.server => const ServerFailure(status: 500),
          EarningsErrorKind.parse => const UnknownFailure(parse: true),
        };
  }
  return AppFailure.of(error);
}
