import '../domain/dispute_status_repository.dart';

/// Presentation FALLBACK / test seam for [DisputeStatusRepository] — NEVER
/// registered in DI (40_GUARDRAILS_ARCH §6 / §12: fakes are a constructor seam,
/// not a DI default; the LIVE `DioDisputeStatusRepository` is the registered
/// binding).
///
/// Used by `DisputeStatusScreen` when `sl<DisputeStatusRepository>()` is not
/// registered (e.g. the router-resolution widget tests, which build the route
/// tree without `configureDependencies()`) — mirrors
/// `NotificationsListScreen._resolveRepository()` falling back to
/// `EmptyNotificationsRepository`. It always raises a `notFound` failure so the
/// screen renders its D30 error state (`dispute_status_error`) instead of
/// throwing on an unconfigured GetIt.
class EmptyDisputeStatusRepository implements DisputeStatusRepository {
  const EmptyDisputeStatusRepository();

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async {
    throw const DisputeStatusRepositoryException(
      DisputeStatusFailure.notFound,
      'No DisputeStatusRepository registered',
    );
  }
}
