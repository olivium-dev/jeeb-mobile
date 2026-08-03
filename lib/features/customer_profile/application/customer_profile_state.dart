import 'package:equatable/equatable.dart';

import '../domain/customer_profile_repository.dart';
import '../domain/customer_profile_view_data.dart';

enum CustomerProfileStatus { initial, loading, loaded, failed }

class CustomerProfileState extends Equatable {
  const CustomerProfileState({
    required this.data,
    this.status = CustomerProfileStatus.initial,
    this.error,
  });

  final CustomerProfileViewData data;

  final CustomerProfileStatus status;

  final CustomerProfileFailure? error;

  CustomerProfileState copyWith({
    CustomerProfileViewData? data,
    CustomerProfileStatus? status,
    CustomerProfileFailure? error,
    bool clearError = false,
  }) {
    return CustomerProfileState(
      data: data ?? this.data,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [data, status, error];
}
