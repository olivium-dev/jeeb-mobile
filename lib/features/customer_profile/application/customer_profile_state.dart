import 'package:equatable/equatable.dart';

import '../domain/customer_profile_repository.dart';
import '../domain/customer_profile_view_data.dart';

/// Lifecycle of the customer-profile header data (40_GUARDRAILS §2).
///
/// Unlike a list screen, the profile is NEVER blank: it is always seeded with
/// the caller-supplied [CustomerProfileViewData] (the shell hands the fixture;
/// the router hands the real `extra`), so [data] is non-null in every status.
/// `loading`/`failed` only gate whether the live `getMe` refresh has resolved —
/// the header (avatar/name/rating) stays visible throughout (JM-035 AC1, which
/// asserts those ids immediately after the tab opens).
enum CustomerProfileStatus { initial, loading, loaded, failed }

class CustomerProfileState extends Equatable {
  const CustomerProfileState({
    required this.data,
    this.status = CustomerProfileStatus.initial,
    this.error,
  });

  /// The header read model — always present (seeded from the constructor).
  final CustomerProfileViewData data;

  final CustomerProfileStatus status;

  /// Typed failure of the last live fetch (never a raw exception/string).
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
