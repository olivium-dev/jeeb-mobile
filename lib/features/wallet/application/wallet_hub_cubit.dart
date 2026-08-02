import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/wallet_repository.dart';
import 'wallet_hub_state.dart';

class WalletHubCubit extends Cubit<WalletHubState> {
  WalletHubCubit({required WalletRepository repository})
      : _repository = repository,
        super(const WalletHubState());

  final WalletRepository _repository;

  Future<void> load() async {
    if (state.status != WalletHubStatus.initial) return;
    emit(state.copyWith(status: WalletHubStatus.loading, clearError: true));
    try {
      final balance = await _repository.fetchBalance();
      emit(state.copyWith(status: WalletHubStatus.loaded, balance: balance));
    } on WalletRepositoryException catch (e) {
      emit(state.copyWith(status: WalletHubStatus.failed, error: e.failure));
    } catch (_) {
      emit(state.copyWith(
        status: WalletHubStatus.failed,
        error: WalletFailure.unknown,
      ));
    }
  }

  Future<void> refresh() async {
    try {
      final balance = await _repository.fetchBalance();
      emit(state.copyWith(
        status: WalletHubStatus.loaded,
        balance: balance,
        clearError: true,
      ));
    } on WalletRepositoryException catch (e) {
      emit(state.copyWith(error: e.failure));
    } catch (_) {
      emit(state.copyWith(error: WalletFailure.unknown));
    }
  }
}
