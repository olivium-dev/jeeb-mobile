import 'package:equatable/equatable.dart';

import '../domain/address_form_repository.dart';

/// Lifecycle of the JM-050 address-detail-form save action.
///
/// The form itself is local (controllers own the text); the only async surface
/// is the save, so the state machine tracks the SAVE, not a fetch:
///   [editing] → [saving] → [saved] (terminal, nav fires) | [failed] (banner).
enum AddressFormStatus { editing, saving, saved, failed }

class AddressFormState extends Equatable {
  const AddressFormState({
    this.status = AddressFormStatus.editing,
    this.error,
  });

  final AddressFormStatus status;
  final AddressFormFailure? error;

  bool get isSaving => status == AddressFormStatus.saving;

  AddressFormState copyWith({
    AddressFormStatus? status,
    AddressFormFailure? error,
    bool clearError = false,
  }) {
    return AddressFormState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, error];
}
