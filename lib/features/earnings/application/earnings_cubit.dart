import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../wallet/domain/wallet_repository.dart';
import '../domain/earnings_repository.dart';
import 'earnings_state.dart';

class EarningsCubit extends Cubit<EarningsState> {
  EarningsCubit({
    required EarningsRepository repository,
    WalletRepository? walletRepository,
    this.jeeberId = '',
  })  : _repository = repository,
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

  Future<void> loadEarnings({EarningsPeriod? period}) async {
    final activePeriod = period ?? state.period;
    emit(state.copyWith(
      mode: EarningsViewMode.loading,
      clearError: true,
      period: activePeriod,
    ));
    try {
      final summary = await _repository.fetchEarnings(
        jeeberId: jeeberId,
        period: activePeriod,
      );
      emit(state.copyWith(mode: EarningsViewMode.ready, summary: summary));
    } on EarningsRepositoryException catch (e) {
      emit(state.copyWith(
        mode: EarningsViewMode.error,
        errorMessage: _mapError(e.kind),
      ));
    }
  }

  Future<void> exportPdf() async {
    emit(state.copyWith(
      exportMode: EarningsExportMode.exporting,
      clearExportError: true,
    ));
    try {
      final path = await _repository.exportEarningsPdf(
        jeeberId: jeeberId,
        period: state.period,
      );
      emit(state.copyWith(
        exportMode: EarningsExportMode.done,
        exportedFilePath: path,
      ));
    } on EarningsRepositoryException catch (e) {
      emit(state.copyWith(
        exportMode: EarningsExportMode.error,
        exportError: _mapError(e.kind),
      ));
    }
  }

  Future<void> _loadWalletBalance() async {
    final repo = _walletRepository;
    if (repo == null) return;
    try {
      final balance = await repo.fetchBalance();
      if (!isClosed) emit(state.copyWith(walletBalance: balance));
    } on WalletRepositoryException {
      // A wallet read must never degrade the earnings screen: no error state,
      // no retry — the footer pill simply renders without the balance suffix.
    }
  }

  void resetExport() {
    emit(state.copyWith(
      exportMode: EarningsExportMode.idle,
      clearExportError: true,
    ));
  }

  String _mapError(EarningsErrorKind kind) {
    switch (kind) {
      case EarningsErrorKind.network:
        return 'Unable to connect. Check your internet.';
      case EarningsErrorKind.server:
        return 'Server error. Please try again later.';
      case EarningsErrorKind.parse:
        return 'Unexpected response format.';
    }
  }
}
