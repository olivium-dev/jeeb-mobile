import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/earnings_repository.dart';
import 'earnings_state.dart';

class EarningsCubit extends Cubit<EarningsState> {
  EarningsCubit({
    required EarningsRepository repository,
    required this.jeeberId,
  })  : _repository = repository,
        super(const EarningsState()) {
    loadEarnings();
  }

  final EarningsRepository _repository;
  final String jeeberId;

  Future<void> loadEarnings() async {
    emit(state.copyWith(mode: EarningsViewMode.loading, clearError: true));
    try {
      final summary = await _repository.fetchEarnings(jeeberId: jeeberId);
      emit(state.copyWith(mode: EarningsViewMode.ready, summary: summary));
    } on EarningsRepositoryException catch (e) {
      emit(state.copyWith(
        mode: EarningsViewMode.error,
        errorMessage: _mapError(e.kind),
      ));
    }
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
