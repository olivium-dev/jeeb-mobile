import '../domain/notifications_repository.dart';

/// In-memory empty [NotificationsRepository] — a presentation FALLBACK / test
/// seam only, NEVER registered in DI (40_GUARDRAILS_ARCH §6 / §12: fakes are a
/// constructor seam, not a DI default; the LIVE `DioNotificationsRepository` is
/// the registered binding).
///
/// Used by [NotificationsListScreen] when `sl<NotificationsRepository>()` is
/// not registered (e.g. the router-resolution widget tests, which build the
/// route tree without `configureDependencies()`) — mirrors
/// `ClientOffersScreen._resolveRepository()` falling back to
/// `FakeOffersRepository`. It returns an empty inbox so the screen renders its
/// empty state instead of throwing on an unconfigured GetIt.
class EmptyNotificationsRepository implements NotificationsRepository {
  const EmptyNotificationsRepository();

  @override
  Future<List<NotificationItem>> fetchNotifications() async =>
      const <NotificationItem>[];

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> confirmReceipt(String deliveryId) async {}
}
