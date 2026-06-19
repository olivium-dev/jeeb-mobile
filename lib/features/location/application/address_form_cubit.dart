import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/address_form_repository.dart';
import 'address_form_state.dart';

/// Drives the JM-050 address-detail-form save (create when [editId] is null,
/// update otherwise). Imports `domain/` only (40_GUARDRAILS_ARCH §1).
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

  /// Persists [draft]. On success emits [AddressFormStatus.saved] (the screen's
  /// `listener` fires the one-shot nav to `saved-addresses`).
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
    } on AddressFormException catch (e) {
      emit(state.copyWith(status: AddressFormStatus.failed, error: e.failure));
    } catch (_) {
      emit(state.copyWith(
        status: AddressFormStatus.failed,
        error: AddressFormFailure.unknown,
      ));
    }
  }

  /// One-shot error acknowledgement so a banner/snackbar replay doesn't loop.
  void acknowledgeError() {
    emit(state.copyWith(status: AddressFormStatus.editing, clearError: true));
  }
}
