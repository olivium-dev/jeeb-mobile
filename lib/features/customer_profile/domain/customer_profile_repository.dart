import 'customer_profile_view_data.dart';

enum CustomerProfileFailure { network, unauthorized, unknown }

class CustomerProfileRepositoryException implements Exception {
  const CustomerProfileRepositoryException(this.failure, [this.message]);

  final CustomerProfileFailure failure;
  final String? message;

  @override
  String toString() =>
      'CustomerProfileRepositoryException($failure, $message)';
}

abstract class CustomerProfileRepository {
  Future<CustomerProfileViewData> fetchProfile();
}
