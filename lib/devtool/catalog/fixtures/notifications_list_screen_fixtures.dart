// Shared dev-only fixtures for `NotificationsListScreen` (JM-057, D84).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_07_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/notifications/presentation/notifications_list_screen.dart`.
//
// The catalog owned three private fakes (`_FakeNotificationsRepository`,
// `_NeverLoadingNotificationsRepository`, `_FailingNotificationsRepository`)
// and one `_sampleNotifications` cast, driving four states — Loading /
// Populated / Empty / Load Failed. Copying them into the preview section would
// have given the two surfaces two different notions of "the designed state",
// free to drift; both import this file instead. The catalog's four labels and
// their readings are unchanged.
//
// ## Everything here is local
//
// `NotificationsListScreen` takes a `repository:` seam (40_GUARDRAILS_ARCH
// §5.4) and only falls through to `sl<NotificationsRepository>()` — and then to
// `EmptyNotificationsRepository` — when it is null, so neither surface ever
// constructs the Dio-backed `DioNotificationsRepository`. Every repository below
// answers from a list, throws, or never completes: network-free by
// construction, not merely by the `CatalogNetworkGuard` both hosts install.
//
// ## Why the timestamps are offsets from `now` and not fixed instants
//
// `NotificationRow` takes an injectable `now` for its relative timestamp — and
// `_LoadedList` does not pass it, so every row on THIS screen ages against the
// wall clock. There is no clock seam on the screen to freeze, so a fixture
// carrying a literal instant (the catalog's `2026-07-05T10:00:00Z`) reads "28d
// ago" this month and "1y" later on, which is a designed state that decays.
// Expressing each row as an OFFSET from the read instead pins what the row
// says: [inbox] always reads 12m / 2h / 3d ago, in the canvas, in a render test
// and on a designer's device. See [ago].

import 'dart:async';

import '../../../features/notifications/domain/notifications_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Repositories
// ─────────────────────────────────────────────────────────────────────────────

/// Answers one canned list, with no latency and no drip-feed.
///
/// [markRead] is recorded rather than sent, so a designer tapping a row in the
/// Screen Catalog gets the optimistic badge clear the real screen gives and
/// nothing leaves the device.
class NotificationsListScreenSeededRepository
    implements NotificationsRepository {
  NotificationsListScreenSeededRepository(this.items);

  /// What `GET /v1/notifications` resolves to. Order does not matter — the
  /// cubit re-sorts newest-first and rows with an unparseable or empty
  /// timestamp sort last.
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
///
/// A [Completer] that is never completed holds no timer and no subscription; it
/// simply never settles. This is the only way to inspect the full-body
/// `OmdsLoadingState` without a real slow connection.
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
///
/// The failure is typed because the screen's `_errorCopy` branches on it:
/// [NotificationsFailure.network] is the ONLY branch with its own copy, and
/// `unauthorized` / `unknown` / null all collapse into the generic
/// "Could not load notifications.".
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
// The designed states
// ─────────────────────────────────────────────────────────────────────────────

/// The casts and the repositories behind every mocked state of
/// `NotificationsListScreen`.
///
/// The screen takes a REPOSITORY, not a state — it builds its own
/// [NotificationsListCubit] and calls `load()` at mount — so a state is
/// described here by what the repository answers, and the real cold-load path
/// runs in the catalog and in the canvas exactly as it does in production.
class NotificationsListScreenPreviewFixtures {
  const NotificationsListScreenPreviewFixtures._();

  /// An ISO-8601 UTC instant [age] before the read.
  ///
  /// UTC and zone-suffixed on purpose: `NotificationsL10n.relativeTime`
  /// re-stamps a zone-LESS string as UTC (the SW-03/G3 fix), and a fixture that
  /// leaned on that would stop testing the shape the notification service
  /// actually sends.
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
  ///
  /// The read row is the point of the middle entry — unread and read differ
  /// only by a font weight and a 12 pt dot, so a cast of three unread rows
  /// would never show whether that difference is legible.
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
  ///
  /// Nothing on a row clamps — neither the title nor the body sets `maxLines` —
  /// so the first row does not ellipsize, it GROWS, and the two below it are
  /// what is left when the payload carries almost nothing:
  ///
  ///  * `new_request` with an empty title and body is what the FCM background
  ///    isolate persists from a DATA-ONLY push; the render layer supplies the
  ///    localized G3 fallback so the row is never blank.
  ///  * `unknown` with an empty title, body AND timestamp is the same shape
  ///    with no fallback — a wire `type` the mobile enum does not know about,
  ///    projected by `_str` into three empty strings. All three
  ///    `if (…isNotEmpty)` guards fail and a bare category eyebrow is left.
  ///
  /// Ordered so the ceiling row is NEWEST and therefore first: a preview whose
  /// one interesting row is below the fold is a preview of a scrollbar. The
  /// `unknown` row has no timestamp at all, so the cubit's sort puts it last.
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
  ///
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
  ///
  /// `_errorCopy` maps `unauthorized` onto the generic `loadError`, so this
  /// renders as an anonymous "Could not load notifications." over a Retry that
  /// cannot succeed until the user signs in again — which nothing on this
  /// surface asks them to do.
  static NotificationsRepository unauthorizedFailure() =>
      const NotificationsListScreenFailingRepository(
        failure: NotificationsFailure.unauthorized,
      );

  /// The layout ceiling plus the two degenerate payloads — see
  /// [longestContent].
  static NotificationsRepository longestContentInbox() =>
      NotificationsListScreenSeededRepository(longestContent);
}
