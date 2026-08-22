import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dev_seam/dev_seam.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/lifecycle/polling_visibility_gate.dart';
import '../../../core/lifecycle/route_visibility.dart';
import '../../../core/session/greeting_profile_cubit.dart';
import '../../../core/session/profile_refresh_signals.dart';
import '../../customer_profile/data/dev_customer_profile_fixtures.dart';
import '../../customer_profile/data/dio_customer_profile_repository.dart';
import '../../customer_profile/domain/customer_profile_repository.dart';
import '../../home_client/application/client_home_cubit.dart';
import '../../home_client/application/client_home_state.dart';
import '../../home_client/data/dev_client_home_fixtures.dart';
import '../../home_client/data/in_memory_client_home_repository.dart';
import '../../home_client/domain/client_home_repository.dart';
import '../../home_client/domain/client_home_request.dart';
import '../../home_client/presentation/client_home_screen.dart';
import '../tab_visibility.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'dart:async';
import '../../../core/previews/jeeb_preview.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, this.repository, this.greetingNameProvider});

  final ClientHomeRepository? repository;

  final String? Function()? greetingNameProvider;

  @override
  Widget build(BuildContext context) {
    final devTab = _devSeamTab();
    final devSeed = devTab != null;
    return MultiBlocProvider(
      key: const Key('home-tab-cubit'),
      providers: [
        BlocProvider(
          create: (_) => ClientHomeCubit(
            repository: repository ?? _resolveRepository(devSeed),
            greetingNameProvider: greetingNameProvider ?? _resolveGreetingName,
            refreshSignals: resolvePushRefreshStream(
              topics: const {RefreshTopic.order, RefreshTopic.offers},
            ),
          ),
        ),
        // real `GET /users/me` (the same getMe the Profile tab reads), so the
        BlocProvider(
          create: (_) => GreetingProfileCubit(
            repository: _resolveGreetingRepository(devSeed),
            seed: _greetingSeed(devSeed),
            refreshSignals: _profileRefreshStream(),
          )..load(),
        ),
      ],
      child: Builder(
        builder: (innerContext) => PollingVisibilityGate(
          // b02 READ ECONOMICS. `isVisible` must AND every condition that makes
          isVisible:
              (TabVisibility.maybeOf(innerContext)?.isVisible ?? true) &&
              RouteVisibilityScope.isOnTop(innerContext),
          target: innerContext.read<ClientHomeCubit>(),
          child: ClientHomeScreen(
            key: const Key('home-tab-root'),
            initialTab: devTab ?? ClientHomeTab.pendingRequests,
            onCreateRequest: (_) => _openCreateRequest(context),
            onOpenRequest: (request) => _openChat(context, request),
            onTrack: (request) => _openTracking(context, request),
          ),
        ),
      ),
    );
  }

  Stream<void>? _profileRefreshStream() {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<ProfileRefreshSignals>()) return null;
    return getIt<ProfileRefreshSignals>().stream;
  }

  CustomerProfileRepository? _resolveGreetingRepository(bool devSeed) {
    if (devSeed) return null;
    final getIt = GetIt.instance;
    if (getIt.isRegistered<CustomerProfileRepository>()) {
      return getIt<CustomerProfileRepository>();
    }
    if (getIt.isRegistered<Dio>()) {
      return DioCustomerProfileRepository(getIt<Dio>());
    }
    return null;
  }

  GreetingProfileState _greetingSeed(bool devSeed) {
    if (!devSeed) return const GreetingProfileState();
    return GreetingProfileState(
      name: DevCustomerProfileFixtures.sample.name,
      avatarUrl: DevCustomerProfileFixtures.sample.avatarUrl,
    );
  }

  ClientHomeRepository _resolveRepository(bool devSeed) {
    if (devSeed) {
      return InMemoryClientHomeRepository.fromSnapshot(
        DevClientHomeFixtures.snapshot(),
      );
    }
    final getIt = GetIt.instance;
    if (getIt.isRegistered<ClientHomeRepository>()) {
      return getIt<ClientHomeRepository>();
    }
    return InMemoryClientHomeRepository();
  }

  String? _resolveGreetingName() => _devSeamTab() != null ? 'Sami' : null;

  ClientHomeTab? _devSeamTab() {
    if (!kDebugMode) return null;
    final raw = DevSeam.current.homeTab;
    switch (raw) {
      case 'in_progress':
        return ClientHomeTab.inProgress;
      case 'pending':
        return ClientHomeTab.pendingRequests;
      case 'replies':
        return ClientHomeTab.replies;
      default:
        return null;
    }
  }

  /// ONE door into the create flow. The tier is chosen on "Choose your
  /// request", never seeded behind the customer on the way past it.
  void _openCreateRequest(BuildContext context) {
    GoRouter.of(context).pushNamed('request-type');
  }

  void _openChat(BuildContext context, ClientHomeRequest request) {
    final target = request.id.isNotEmpty
        ? request.id
        : (request.conversationId ?? '');
    if (target.isEmpty) return;
    GoRouter.of(
      context,
    ).pushNamed('chat-detail', pathParameters: {'id': target});
  }

  void _openTracking(BuildContext context, ClientHomeRequest request) {
    if (request.trackingId.isEmpty) return;
    GoRouter.of(context).pushNamed(
      'live-tracking',
      pathParameters: {'id': request.trackingId},
      queryParameters: {
        if (request.deliveryId != null && request.deliveryId!.isNotEmpty)
          'deliveryId': request.deliveryId!,
      },
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// A whole shell tab, so the canvas box is a phone body: 390 dp wide and tall
/// enough that the greeting, the chip row and the first cards are all visible
const Size _homeTabBox = Size(390, 780);

/// The two screen-level layouts that replace the body with a single centred
/// block. Shorter on purpose: at [_homeTabBox] height they are mostly empty
const Size _homeTabStateBox = Size(390, 420);

/// The longest free-text title the gateway can hand this tab: a request with no
/// `displayId` falls back to the customer's own typed description, which is
const String _homeTabLongTitle =
    'Pharmacy pickup on Rue Gouraud, then the bakery two streets down, then '
    'drop everything at the clinic on Independence Street before it closes';

/// Answers one canned snapshot on the next microtask, so `load()` passes through
/// `loading` and lands on `ready`. No latency, no second read, no socket.
class _HomeTabSeededRepository implements ClientHomeRepository {
  const _HomeTabSeededRepository({
    this.pending = const <ClientHomeRequest>[],
    this.replies = const <ClientHomeRequest>[],
  });

  final List<ClientHomeRequest> pending;
  final List<ClientHomeRequest> replies;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      ClientHomeSnapshot(pending: pending, replies: replies);
}

/// Fails the COLD load — the only way to reach `ClientHomeStatus.failed`, since
/// [ClientHomeCubit] deliberately swallows a failed REFRESH while data is
/// already painted.
class _HomeTabFailingRepository implements ClientHomeRepository {
  const _HomeTabFailingRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      throw Exception('preview: home summary unreachable');
}

/// Never answers, so the tab stays in `ClientHomeStatus.loading` for as long as
/// the canvas is open. A [Completer] that is never completed holds no timer and
/// no subscription — it simply never settles.
class _HomeTabStalledRepository implements ClientHomeRepository {
  const _HomeTabStalledRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() =>
      Completer<ClientHomeSnapshot>().future;
}

/// The real tab over a fake repository. [greetingName] feeds the same
/// `greetingNameProvider` seam DI uses; `null` is the honest default (the live
Widget _homeTabHosted(
  ClientHomeRepository repository, {
  String? greetingName,
}) {
  return HomeTab(
    repository: repository,
    greetingNameProvider: () => greetingName,
  );
}

/// A pending row exactly as the gateway returns one: searching, no offers.
ClientHomeRequest _homeTabPendingRow({
  required String orderId,
  ClientRequestTier tier = ClientRequestTier.express,
}) => ClientHomeRequest(
  id: orderId.toLowerCase(),
  displayId: orderId,
  title: orderId,
  status: ClientRequestStatus.searching,
  destinationLabel: '1 kilo potato, water gallon, coffee blend',
  itemsSummary: '1 kilo potato, water gallon, coffee blend',
  tier: tier,
);

/// A replies row. The avatar URLs are EMPTY strings on purpose: [RepliesCard]
/// renders offerers through `OmdsProfileAvatar` → `CachedNetworkImage`, and a
ClientHomeRequest _homeTabReplyRow({
  required String orderId,
  required int offerCount,
}) => ClientHomeRequest(
  id: orderId.toLowerCase(),
  displayId: orderId,
  title: orderId,
  status: ClientRequestStatus.offersReceived,
  destinationLabel: '1 kilo potato, water gallon, coffee blend',
  itemsSummary: '1 kilo potato, water gallon, coffee blend',
  tier: ClientRequestTier.express,
  offerCount: offerCount,
  offerAvatarUrls: const <String>['', '', ''],
  conversationId: 'conv-${orderId.toLowerCase()}',
);

/// The default landing: a named sender with two requests out for bids.
/// The composed shape the sub-tab previews cannot show — personalized greeting,
@JeebPreview(group: 'shell', name: 'Pending · two requests', size: _homeTabBox)
Widget homeTabPendingPreview() => _homeTabHosted(
  _HomeTabSeededRepository(
    pending: <ClientHomeRequest>[
      _homeTabPendingRow(orderId: 'ORD-23470'),
      _homeTabPendingRow(orderId: 'ORD-23471', tier: ClientRequestTier.flash),
    ],
  ),
  greetingName: 'Layla',
);

/// Nothing pending and nothing replied — a brand-new account, and the state a
/// sender returns to after every order closes.
@JeebPreview(group: 'shell', name: 'Empty · new account', size: _homeTabBox)
Widget homeTabEmpty() => _homeTabHosted(const _HomeTabSeededRepository());

/// Pending is empty but Replies is not, so the tab MOVES the selection.
/// `ClientHomeScreen._resolveInitialTab` is a one-shot "land where the content
@JeebPreview(group: 'shell', name: 'Auto-advance to Replies', size: _homeTabBox)
Widget homeTabAdvancesToReplies() => _homeTabHosted(
  _HomeTabSeededRepository(
    replies: <ClientHomeRequest>[
      _homeTabReplyRow(orderId: 'ORD-23480', offerCount: 9),
    ],
  ),
  greetingName: 'Layla',
);

/// Cold load in flight: greeting, then a bare spinner.
/// The whole chip row is GONE — `_ClientHomeBody` swaps the ready layout out
@JeebPreview(group: 'shell', name: 'Loading · cold', size: _homeTabStateBox)
Widget homeTabLoading() =>
    _homeTabHosted(const _HomeTabStalledRepository(), greetingName: 'Layla');

/// Cold load failed: the full-tab connection error and its Retry CTA.
/// Only a COLD failure reaches here — a failed background refresh keeps the
@JeebPreview(group: 'shell', name: 'Failed · cold load', size: _homeTabStateBox)
Widget homeTabFailed() =>
    _homeTabHosted(const _HomeTabFailingRepository(), greetingName: 'Layla');

/// The layout ceiling, everything long at once.
/// A full name long enough to test the header's `Expanded` against the "+"
@JeebPreview(group: 'shell', name: 'Longest content', size: _homeTabBox)
Widget homeTabLongContent() => _homeTabHosted(
  const _HomeTabSeededRepository(
    pending: <ClientHomeRequest>[
      ClientHomeRequest(
        id: 'pen-long',
        title: _homeTabLongTitle,
        status: ClientRequestStatus.searching,
        destinationLabel: 'Rue Gouraud, Gemmayzeh, Beirut',
        itemsSummary:
            'Two boxes of paracetamol, one bottle of cough syrup, a digital '
            'thermometer, four manoushe zaatar and a bag of vitamin C',
        tier: ClientRequestTier.flash,
      ),
    ],
  ),
  greetingName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
);
