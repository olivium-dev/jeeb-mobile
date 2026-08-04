import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/customer_profile_repository.dart';
import '../domain/customer_profile_view_data.dart';
import 'customer_profile_state.dart';

class CustomerProfileCubit extends Cubit<CustomerProfileState> {
  CustomerProfileCubit({
    required CustomerProfileViewData seed,
    CustomerProfileRepository? repository,
  })  : _repository = repository,
        super(CustomerProfileState(data: seed));

  final CustomerProfileRepository? _repository;

  Future<void> load() async {
    if (state.status != CustomerProfileStatus.initial) return;
    final repo = _repository;
    if (repo == null) {
      emit(state.copyWith(status: CustomerProfileStatus.loaded));
      return;
    }
    emit(state.copyWith(status: CustomerProfileStatus.loading, clearError: true));
    await _fetch(repo);
  }

  Future<void> refresh() async {
    final repo = _repository;
    if (repo == null) return;
    await _fetch(repo);
  }

  Future<void> _fetch(CustomerProfileRepository repo) async {
    try {
      final fresh = await repo.fetchProfile();
      emit(state.copyWith(
        data: fresh,
        status: CustomerProfileStatus.loaded,
        clearError: true,
      ));
    } on CustomerProfileRepositoryException catch (e) {
      emit(state.copyWith(
        status: CustomerProfileStatus.loaded,
        error: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: CustomerProfileStatus.loaded,
        error: CustomerProfileFailure.unknown,
      ));
    }
  }
}
