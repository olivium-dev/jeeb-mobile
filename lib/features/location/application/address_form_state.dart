import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/address_form_repository.dart';

enum AddressFormStatus { editing, saving, saved, failed }

class AddressFormState extends Equatable {
  const AddressFormState({
    this.status = AddressFormStatus.editing,
    this.error,
    this.appFailure,
  });

  final AddressFormStatus status;
  final AddressFormFailure? error;

  /// The classified save failure. [error] stays for the fixture.
  final AppFailure? appFailure;

  /// Per-field messages from a 422, bound onto the offending inputs.
  Map<String, List<String>> get fieldErrors =>
      appFailure is ValidationFailure
          ? (appFailure! as ValidationFailure).fieldErrors
          : const <String, List<String>>{};

  bool get isSaving => status == AddressFormStatus.saving;

  AddressFormState copyWith({
    AddressFormStatus? status,
    AddressFormFailure? error,
    bool clearError = false,
    AppFailure? appFailure,
  }) {
    return AddressFormState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      appFailure: clearError ? null : (appFailure ?? this.appFailure),
    );
  }

  @override
  List<Object?> get props => [status, error, appFailure];
}
