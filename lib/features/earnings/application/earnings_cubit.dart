import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/earnings_repository.dart';
import 'earnings_state.dart';

class EarningsCubit extends Cubit<EarningsState> {
  EarningsCubit({
    required EarningsRepository repository,
    this.jeeberId = '',
  })  : _repository = repository,
        super(const EarningsState()) {
    loadEarnings();
  }

  final EarningsRepository _repository;

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
