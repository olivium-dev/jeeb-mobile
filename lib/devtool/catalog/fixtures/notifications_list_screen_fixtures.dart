// Shared dev-only fixtures for `NotificationsListScreen` (JM-057, D84).

import 'dart:async';

import '../../../features/notifications/domain/notifications_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────

/// Answers one canned list, with no latency and no drip-feed.
/// [markRead] is recorded rather than sent, so a designer tapping a row in the
/// Screen Catalog gets the optimistic badge clear the real screen gives and
class NotificationsListScreenSeededRepository
    implements NotificationsRepository {
  NotificationsListScreenSeededRepository(this.items);

  /// What `GET /v1/notifications` resolves to. Order does not matter — the
  /// cubit re-sorts newest-first and rows with an unparseable or empty
  final List<NotificationItem> items;

  /// Ids passed to [markRead], newest last.
  final List<String> markedRead = <String>[];

  @override
  Future<List<NotificationItem>> fetchNotifications() async =>
      List<NotificationItem>.unmodifiable(items);

  @override
  Future<void> markRead(String id) async => markedRead.add(id);
}

/// A read that never lands, holding the screen on
/// [NotificationsListStatus.loading] for as long as the surface is open.
/// A [Completer] that is never completed holds no timer and no subscription; it
class NotificationsListScreenStalledRepository
    implements NotificationsRepository {
  const NotificationsListScreenStalledRepository();

  @override
  Future<List<NotificationItem>> fetchNotifications() =>
      Completer<List<NotificationItem>>().future;

  @override
  Future<void> markRead(String id) => Completer<void>().future;
}

/// Every read throws [failure] — the COLD-load failure that reaches the
/// full-body `OmdsErrorState`.
/// The failure is typed because the screen's `_errorCopy` branches on it:
class NotificationsListScreenFailingRepository
    implements NotificationsRepository {
  const NotificationsListScreenFailingRepository({
    this.failure = NotificationsFailure.network,
  });

  final NotificationsFailure failure;

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    throw NotificationsRepositoryException(failure);
  }

  @override
  Future<void> markRead(String id) async {
    throw NotificationsRepositoryException(failure);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// The casts and the repositories behind every mocked state of
/// `NotificationsListScreen`.
/// The screen takes a REPOSITORY, not a state — it builds its own
class NotificationsListScreenPreviewFixtures {
  const NotificationsListScreenPreviewFixtures._();

  /// An ISO-8601 UTC instant [age] before the read.
  /// UTC and zone-suffixed on purpose: `NotificationsL10n.relativeTime`
  static String ago(Duration age) =>
      DateTime.now().toUtc().subtract(age).toIso8601String();

  /// One row, with the fields the list actually renders.
  static NotificationItem row({
    required String id,
    required NotificationKind kind,
    required String title,
    required String body,
    required Duration age,
    bool read = false,
    String? ref,
  }) {
    return NotificationItem(
      id: id,
      kind: kind,
      title: title,
      body: body,
      timestamp: ago(age),
      read: read,
      ref: ref,
    );
  }

  // ────────────────────────────── the casts ───────────────────────────────

  /// Catalog "Populated": three rows spanning three D84 dispatch classes, one
  /// of them already read.
  static List<NotificationItem> get inbox => <NotificationItem>[
        row(
          id: 'n-1',
          kind: NotificationKind.offer,
          title: 'New offer received',
          body: 'A jeeber offered to deliver your package for 12.50 USD',
          age: const Duration(minutes: 12),
        ),
        row(
          id: 'n-2',
          kind: NotificationKind.status,
          title: 'Order picked up',
          body: 'Your order is on its way to Verdun, Beirut',
          age: const Duration(hours: 2),
          read: true,
          ref: 'conv-1',
        ),
        row(
          id: 'n-3',
          kind: NotificationKind.lowBalance,
          title: 'Low wallet balance',
          body: 'Top up to keep bidding on requests',
          age: const Duration(days: 3),
        ),
      ];

  /// The layout ceiling and the two degenerate payloads, in one list.
  /// Nothing on a row clamps — neither the title nor the body sets `maxLines` —
  static List<NotificationItem> get longestContent => <NotificationItem>[
        row(
          id: 'n-long',
          kind: NotificationKind.offerAccepted,
          title: 'Abdulrahman Al-Muhandis accepted your offer and is on the '
              'way to the pickup point',
          body: 'He will call when he reaches Hamra Street, Beirut — building '
              '42, third floor. Please have the package sealed and ready to '
              'hand over.',
          age: const Duration(minutes: 5),
          ref: 'conv-91',
        ),
        row(
          id: 'n-bg',
          kind: NotificationKind.newRequest,
          title: '',
          body: '',
          age: const Duration(hours: 1),
          ref: 'req-42',
        ),
        const NotificationItem(
          id: 'n-unknown',
          kind: NotificationKind.unknown,
          title: '',
          body: '',
          timestamp: '',
          read: false,
        ),
      ];

  // ───────────────────────────── the states ───────────────────────────────

  /// Catalog "Populated": a successful read carrying [inbox].
  static NotificationsRepository populated() =>
      NotificationsListScreenSeededRepository(inbox);

  /// Catalog "Empty": a read that SUCCEEDED and came back with zero rows.
  /// Not a fifth status — `loaded` with `hasItems == false` (§3).
  static NotificationsRepository emptyInbox() =>
      NotificationsListScreenSeededRepository(const <NotificationItem>[]);

  /// Catalog "Loading": the cold read, held open.
  static NotificationsRepository stalledLoad() =>
      const NotificationsListScreenStalledRepository();

  /// Catalog "Load Failed": the cold read fails with the one failure the
  /// screen has copy for.
  static NotificationsRepository networkFailure() =>
      const NotificationsListScreenFailingRepository();

  /// The same failed body, reached by an expired session.
  /// `_errorCopy` maps `unauthorized` onto the generic `loadError`, so this
  static NotificationsRepository unauthorizedFailure() =>
      const NotificationsListScreenFailingRepository(
        failure: NotificationsFailure.unauthorized,
      );

  /// The layout ceiling plus the two degenerate payloads — see
  /// [longestContent].
  static NotificationsRepository longestContentInbox() =>
      NotificationsListScreenSeededRepository(longestContent);
}
