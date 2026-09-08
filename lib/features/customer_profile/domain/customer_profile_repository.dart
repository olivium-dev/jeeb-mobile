import '../../../core/network/app_failure.dart';
import 'customer_profile_view_data.dart';

enum CustomerProfileFailure { network, unauthorized, unknown }

class CustomerProfileRepositoryException implements Exception {
  const CustomerProfileRepositoryException(this.failure, [this.message])
    : appFailure = null;

  const CustomerProfileRepositoryException.classified(
    this.failure, {
    this.message,
    required this.appFailure,
  });

  final CustomerProfileFailure failure;

  /// DIAGNOSTIC ONLY — never rendered.
  final String? message;

  /// The classified transport failure, when the thrower could produce one.
  final AppFailure? appFailure;

  @override
  String toString() => 'CustomerProfileRepositoryException($failure, $message)';
}

abstract class CustomerProfileRepository {
  Future<CustomerProfileViewData> fetchProfile();
}
