import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/customer_profile_repository.dart';
import '../domain/customer_profile_view_data.dart';

enum CustomerProfileStatus { initial, loading, loaded, failed }

class CustomerProfileState extends Equatable {
  const CustomerProfileState({
    required this.data,
    this.status = CustomerProfileStatus.initial,
    this.error,
    this.appFailure,
    this.refreshError,
  });

  final CustomerProfileViewData data;

  final CustomerProfileStatus status;

  final CustomerProfileFailure? error;

  /// The classified cold-read failure.
  final AppFailure? appFailure;

  /// A refresh that failed over a profile already on screen.
  final AppFailure? refreshError;

  CustomerProfileState copyWith({
    CustomerProfileViewData? data,
    CustomerProfileStatus? status,
    CustomerProfileFailure? error,
    AppFailure? appFailure,
    AppFailure? refreshError,
    bool clearRefreshError = false,
    bool clearError = false,
  }) {
    return CustomerProfileState(
      data: data ?? this.data,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      appFailure: clearError ? null : (appFailure ?? this.appFailure),
      refreshError: clearRefreshError
          ? null
          : (refreshError ?? this.refreshError),
    );
  }

  @override
  List<Object?> get props => [data, status, error, appFailure, refreshError];
}
