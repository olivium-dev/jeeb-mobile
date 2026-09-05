// Designed states for the Client Home screen — ONE source of truth, two

import 'dart:async';

import '../../../core/network/app_failure.dart';
import '../../../features/home_client/application/client_home_cubit.dart';
import '../../../features/home_client/data/dev_client_home_fixtures.dart';
import '../../../features/home_client/data/in_memory_client_home_repository.dart';
import '../../../features/home_client/domain/client_home_repository.dart';
import '../../../features/home_client/domain/client_home_request.dart';

/// Fake [ClientHomeRepository] whose cold load always throws.
/// A COLD failure is the only way to reach [ClientHomeStatus.failed]:
/// `ClientHomeCubit._fetch` deliberately swallows a failed *refresh* when data
class FailingClientHomeRepository implements ClientHomeRepository {
  const FailingClientHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    throw StateError('fixture: simulated client-home load failure');
  }
}

/// Fake [ClientHomeRepository] whose read never resolves, freezing the cubit on
/// [ClientHomeStatus.loading] for as long as the host is open.
/// A [Completer] that is never completed holds no timer and no subscription; it
class StalledClientHomeRepository implements ClientHomeRepository {
  const StalledClientHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() =>
      Completer<ClientHomeSnapshot>().future;
}

/// Answers exactly one canned [ClientHomeSnapshot], with no latency.
class SeededClientHomeRepository implements ClientHomeRepository {
  const SeededClientHomeRepository(this.snapshot);

  final ClientHomeSnapshot snapshot;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async => snapshot;
}

/// One bucket dead, the rest healthy — the partial-failure render (ES-10/F7).
class PartialFailureClientHomeRepository implements ClientHomeRepository {
  const PartialFailureClientHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async => ClientHomeSnapshot(
    replies: DevClientHomeFixtures.snapshot().replies,
    inProgressFailure: const NetworkFailure(offline: true),
  );
}

/// First load succeeds; every later read throws — the warm refresh band.
class RefreshFailingClientHomeRepository implements ClientHomeRepository {
  RefreshFailingClientHomeRepository();

  bool _loaded = false;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    if (_loaded) throw const NetworkFailure(offline: true);
    _loaded = true;
    return DevClientHomeFixtures.snapshot();
  }
}

/// Cold load fails unrecoverably — the exit-CTA path (403).
class ForbiddenClientHomeRepository implements ClientHomeRepository {
  const ForbiddenClientHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      throw const ForbiddenFailure();
}

/// The designed states of `ClientHomeScreen`, as repositories + a cubit factory.
/// Deliberately NOT a widget builder: the two consumers need different chrome
/// around the same screen, and a shared builder that took a `wrapInScaffold`
class ClientHomeScreenPreviewFixtures {
  const ClientHomeScreenPreviewFixtures._();

  /// The signed-in customer's first name, as the greeting header receives it.
  static const String greetingName = 'Layla';

  /// A name long enough to contest the header row with the filled "+" button.
  static const String longGreetingName = 'Abdulrahman Al-Muhandis Al-Trabulsi';

  /// The customer's own free-text "What do you need?" line on a request that
  /// never got a server order id — the longest header a pending row can carry.
  static const String longRequestTitle =
      'Pharmacy pickup on Rue Gouraud, then the bakery two streets down, '
      'then drop everything at the clinic on Independence Street';

  /// The longest plausible summary line (`maxLines: 2` on the card).
  static const String longItemsSummary =
      'Two boxes of paracetamol, one bottle of cough syrup, a digital '
      'thermometer, four manoushe zaatar and a bag of vitamin C';

  /// Order id of the single reply in [repliesOnly] — the row that proves the
  /// screen landed on the Replies sub-tab by itself.
  static const String autoAdvanceReplyId = 'ORD-98120';

  /// All three lists populated, mirroring the Figma mock data for screens
  /// 13/14/15 verbatim.
  static ClientHomeRepository populated() =>
      InMemoryClientHomeRepository.fromSnapshot(
        DevClientHomeFixtures.snapshot(),
        latency: Duration.zero,
      );

  /// A fresh account: the load succeeds and every list comes back empty.
  static ClientHomeRepository empty() =>
      InMemoryClientHomeRepository(latency: Duration.zero);

  /// Cold load throws — the full-screen retry state.
  static ClientHomeRepository failing() => const FailingClientHomeRepository();

  /// Cold load never returns — the spinner state.
  static ClientHomeRepository stalled() => const StalledClientHomeRepository();

  /// In-Progress dead, Replies healthy — rows AND a per-bucket error.
  static ClientHomeRepository partialFailureRepository() =>
      const PartialFailureClientHomeRepository();

  /// Load OK, refresh throws — `client_home_refresh_failed_note` over rows.
  static ClientHomeRepository refreshFailingRepository() =>
      RefreshFailingClientHomeRepository();

  /// 403 cold load — the unrecoverable branch, no inert Retry.
  static ClientHomeRepository forbiddenRepository() =>
      const ForbiddenClientHomeRepository();

  /// Pending EMPTY, Replies POPULATED — the one-shot "land where the content
  /// is" affordance in `_resolveInitialTab`, which must advance to Replies and
  static ClientHomeRepository repliesOnly() =>
      const SeededClientHomeRepository(
        ClientHomeSnapshot(
          replies: <ClientHomeRequest>[
            ClientHomeRequest(
              id: 'rep-auto',
              title: autoAdvanceReplyId,
              displayId: autoAdvanceReplyId,
              status: ClientRequestStatus.offersReceived,
              destinationLabel: 'Hamra, Beirut',
              itemsSummary: '1 kilo potato, water gallon, coffee blend',
              tier: ClientRequestTier.express,
              offerCount: 5,
              // Empty strings on purpose: the avatar falls back to its initials
              offerAvatarUrls: <String>['', '', ''],
              conversationId: 'conv-rep-auto',
            ),
          ],
        ),
      );

  /// The layout ceiling: a long greeting name over a pending row with no order
  /// id, a free-text header, a two-line summary and an untruncatable tier badge.
  static ClientHomeRepository longContent() => const SeededClientHomeRepository(
    ClientHomeSnapshot(
      pending: <ClientHomeRequest>[
        ClientHomeRequest(
          id: 'pen-long',
          title: longRequestTitle,
          status: ClientRequestStatus.searching,
          destinationLabel: 'Achrafieh, Sassine Square, building 12, 4th floor',
          itemsSummary: longItemsSummary,
          tier: ClientRequestTier.flash,
        ),
      ],
    ),
  );

  /// The cubit both hosts mount above the screen.
  /// No `load()` here on purpose — `ClientHomeScreen.initState` posts its own
  static ClientHomeCubit cubit(
    ClientHomeRepository repository, {
    String? name = greetingName,
  }) => ClientHomeCubit(
    repository: repository,
    greetingNameProvider: () => name,
  );
}
