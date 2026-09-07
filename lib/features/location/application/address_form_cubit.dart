import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../domain/address_form_repository.dart';
import 'address_form_state.dart';

class AddressFormCubit extends Cubit<AddressFormState> {
  AddressFormCubit({
    required AddressFormRepository repository,
    required String userId,
    String? editId,
  })  : _repository = repository,
        _userId = userId,
        _editId = editId,
        super(const AddressFormState());

  final AddressFormRepository _repository;
  final String _userId;
  final String? _editId;

  Future<void> save(AddressFormDraft draft) async {
    if (state.isSaving) return;
    emit(state.copyWith(status: AddressFormStatus.saving, clearError: true));
    try {
      final editId = _editId;
      if (editId == null || editId.isEmpty) {
        await _repository.create(userId: _userId, draft: draft);
      } else {
        await _repository.update(userId: _userId, id: editId, draft: draft);
      }
      emit(state.copyWith(status: AddressFormStatus.saved));
    } catch (e) {
      final AppFailure failure = AppFailure.of(e);
      emit(state.copyWith(
        status: AddressFormStatus.failed,
        error: e is AddressFormException ? e.failure : _legacy(failure),
        appFailure: failure,
      ));
    }
  }

  AddressFormFailure _legacy(AppFailure failure) =>
      failure is NetworkFailure || failure is TimeoutFailure
          ? AddressFormFailure.network
          : AddressFormFailure.unknown;

  void acknowledgeError() {
    emit(state.copyWith(status: AddressFormStatus.editing, clearError: true));
  }
}
