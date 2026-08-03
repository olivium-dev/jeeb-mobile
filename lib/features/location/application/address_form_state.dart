import 'package:equatable/equatable.dart';

import '../domain/address_form_repository.dart';

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
