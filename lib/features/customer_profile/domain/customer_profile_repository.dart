import 'customer_profile_view_data.dart';

/// Typed failures the customer-profile data source can surface (40_GUARDRAILS
/// §4). The cubit maps these to copy; the UI never sees a `DioException`.
enum CustomerProfileFailure { network, unauthorized, unknown }

/// Thrown by [CustomerProfileRepository] implementations; carries the typed
/// [CustomerProfileFailure] so `application/` stays Dio-free.
class CustomerProfileRepositoryException implements Exception {
  const CustomerProfileRepositoryException(this.failure, [this.message]);

  final CustomerProfileFailure failure;
  final String? message;

  @override
  String toString() =>
      'CustomerProfileRepositoryException($failure, $message)';
}

/// Domain contract for the Customer Profile header data (JM-035 AC1).
///
/// Backed by `GET /user-management/users/me` (the JM-035 AC's named endpoint).
/// PURE Dart — no Flutter / Dio / GetIt imports (Clean Architecture, deps point
/// inward).
abstract class CustomerProfileRepository {
  /// Fetch the signed-in user and project it onto the header read model
  /// (name / avatar / verified / per-role rating / isJeeber). Throws
  /// [CustomerProfileRepositoryException] on failure.
  Future<CustomerProfileViewData> fetchProfile();
}
