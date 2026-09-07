import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/app_failure.dart';
import '../catalog_models.dart';
import '../fixtures/first_group_transition_fixtures.dart';
import '../fixtures/jeeber_active_deliveries_fixtures.dart';

import '../../../features/escalate/application/escalate_cubit.dart';
import '../../../features/escalate/domain/escalate_repository.dart';
import '../../../features/escalate/presentation/escalate_screen.dart';
import '../fixtures/escalate_screen_fixtures.dart';
import '../../../features/goods_cost/presentation/goods_cost_screen.dart';
import '../fixtures/goods_cost_screen_fixtures.dart';
import '../../../features/home_client/application/client_home_cubit.dart';
import '../../../features/home_client/application/client_home_state.dart';
import '../../../features/home_client/domain/client_home_repository.dart';
import '../../../features/home_client/presentation/client_home_screen.dart';
import '../fixtures/client_home_screen_fixtures.dart';
import '../../../features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../../../features/jeeber_active_deliveries/application/active_deliveries_cubit.dart';
import '../../../features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import '../../../features/jeeber_active_deliveries/domain/active_delivery_summary.dart';
import '../../../features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart';
import '../../../features/jeeber_home/application/availability_cubit.dart';
import '../../../features/jeeber_home/presentation/jeeber_home_screen.dart';
import '../../../features/jeeber_home/presentation/widgets/jeeber_feed_empty_view.dart';
import '../../../features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../fixtures/jeeber_home_screen_fixtures.dart';
import '../../../features/jeeber_onboarding/presentation/dm_onboarding_screen.dart';
import '../fixtures/dm_onboarding_screen_fixtures.dart';

/// Batch 04: escalate, goods_cost, home_client, jeeber_active_deliveries,
/// jeeber_home, jeeber_onboarding — each state renders the real screen with
List<CatalogEntry> get batch04Entries => <CatalogEntry>[
  _escalateEntry,
  _goodsCostEntry,
  _clientHomeEntry,
  _jeeberActiveDeliveriesEntry,
  _jeeberHomeEntry,
  _jeeberOnboardingEntry,
];

/// [preSubmit] fires setReason → submit before first frame to drive submitting/error states.
Widget _escalateScreen(
  EscalateRepository repository, {
  bool preSubmit = false,
}) {
  return BlocProvider<EscalateCubit>(
    create: (_) => EscalateScreenPreviewFixtures.cubit(
      repository,
      reason: preSubmit ? EscalateReason.damaged : null,
      submit: preSubmit,
    ),
    child: const EscalateScreen(),
  );
}

final CatalogEntry _escalateEntry = CatalogEntry(
  feature: 'escalate',
  screen: 'Dispute Open + Evidence',
  states: [
    CatalogState(
      'Reason picker (evidence loaded)',
      (_) => _escalatePreview(EscalateScreenPreviewFixtures.richPreview()),
    ),
    CatalogState(
      'Evidence degraded (chat/timeline unavailable)',
      (_) => _escalatePreview(EscalateScreenPreviewFixtures.failingPreview()),
    ),
    CatalogState(
      'Submitting',
      (_) => _escalateScreen(
        EscalateScreenPreviewFixtures.stalledSubmit(),
        preSubmit: true,
      ),
    ),
    CatalogState(
      'Error (network)',
      (_) => _escalateScreen(
        EscalateScreenPreviewFixtures.failingSubmit(),
        preSubmit: true,
      ),
    ),
    CatalogState(
      'Evidence preview — empty (ES-15)',
      (_) => _escalatePreview(EscalateScreenPreviewFixtures.emptyPreview()),
    ),
    CatalogState(
      'Evidence preview — failed (ESC-08)',
      (_) => _escalatePreview(EscalateScreenPreviewFixtures.failingPreview()),
    ),
    CatalogState(
      'Evidence preview — in flight',
      (_) => _escalatePreview(EscalateScreenPreviewFixtures.stalledPreview()),
    ),
    CatalogState(
      'Evidence preview — rich',
      (_) => _escalatePreview(EscalateScreenPreviewFixtures.richPreview()),
    ),
    CatalogState(
      'Error — dispute not found (exit CTA, no Retry)',
      (_) => _escalateScreen(
        EscalateScreenPreviewFixtures.notFoundSubmit(),
        preSubmit: true,
      ),
    ),
  ],
);

/// The three ES-15 rungs only light when the repository implements the preview
/// interface, which the shipped Dio one deliberately does not.
Widget _escalatePreview(EscalateRepository repository) =>
    BlocProvider<EscalateCubit>(
      create: (_) =>
          EscalateScreenPreviewFixtures.cubit(repository)..loadEvidence(),
      child: const EscalateScreen(),
    );

/// `repository` is the only seam; it builds its own cubit and calls loadCurrency() at mount.
final CatalogEntry _goodsCostEntry = CatalogEntry(
  feature: 'goods_cost',
  screen: 'Enter Goods Cost',
  states: [
    CatalogState(
      'Currency loaded (USD)',
      (_) => GoodsCostScreen(
        deliveryId: GoodsCostScreenPreviewFixtures.deliveryId,
        repository: GoodsCostScreenPreviewFixtures.usd(),
      ),
    ),
    CatalogState(
      'Currency loaded (LBP)',
      (_) => GoodsCostScreen(
        deliveryId: GoodsCostScreenPreviewFixtures.deliveryId,
        repository: GoodsCostScreenPreviewFixtures.lbp(),
      ),
    ),
    CatalogState(
      'Currency read degraded (label falls back neutral)',
      (_) => GoodsCostScreen(
        deliveryId: GoodsCostScreenPreviewFixtures.deliveryId,
        repository: GoodsCostScreenPreviewFixtures.currencyUnavailable(),
      ),
    ),
    CatalogState(
      'Currency absent — neutral label + inline retry',
      (_) => GoodsCostScreen(
        deliveryId: GoodsCostScreenPreviewFixtures.deliveryId,
        repository: GoodsCostScreenPreviewFixtures.currencyAbsent(),
      ),
    ),
    CatalogState(
      'Amount unconfirmed — the server confirmed nothing',
      (_) => catalogGoodsUnconfirmed(GoodsCostScreen(
        deliveryId: GoodsCostScreenPreviewFixtures.deliveryId,
        repository: GoodsCostScreenPreviewFixtures.amountUnconfirmed(),
      )),
    ),
  ],
);

/// Wraps ClientHomeScreen in BlocProvider + Scaffold. initState calls cubit.load().
Widget _clientHome({
  required ClientHomeRepository repository,
  required ClientHomeTab initialTab,
  String? name = ClientHomeScreenPreviewFixtures.greetingName,
  bool failWarmRefresh = false,
}) {
  return Scaffold(
    body: BlocProvider<ClientHomeCubit>(
      create: (_) {
        final cubit = ClientHomeScreenPreviewFixtures.cubit(
          repository,
          name: name,
        );
        if (failWarmRefresh) {
          // This repository only fails its SECOND read. Drive that real
          // transition so the catalog displays the state its label promises.
          unawaited(() async {
            await cubit.load();
            if (!cubit.isClosed) await cubit.refresh();
          }());
        }
        return cubit;
      },
      child: ClientHomeScreen(
        initialTab: initialTab,
        onCreateRequest: (_) {},
        onTrack: (_) {},
      ),
    ),
  );
}

final CatalogEntry _clientHomeEntry = CatalogEntry(
  feature: 'home_client',
  screen: 'Client Home (Requests tab)',
  states: [
    CatalogState(
      'In Progress (populated)',
      (_) => _clientHome(
        repository: ClientHomeScreenPreviewFixtures.populated(),
        initialTab: ClientHomeTab.inProgress,
      ),
    ),
    CatalogState(
      'Pending Requests (populated)',
      (_) => _clientHome(
        repository: ClientHomeScreenPreviewFixtures.populated(),
        initialTab: ClientHomeTab.pendingRequests,
      ),
    ),
    CatalogState(
      'Replies (populated)',
      (_) => _clientHome(
        repository: ClientHomeScreenPreviewFixtures.populated(),
        initialTab: ClientHomeTab.replies,
      ),
    ),
    CatalogState(
      'Empty (no requests)',
      (_) => _clientHome(
        repository: ClientHomeScreenPreviewFixtures.empty(),
        initialTab: ClientHomeTab.pendingRequests,
      ),
    ),
    CatalogState(
      'Load failed (retry)',
      (_) => _clientHome(
        repository: ClientHomeScreenPreviewFixtures.failing(),
        initialTab: ClientHomeTab.inProgress,
      ),
    ),
    // M4: "Empty (no requests)" pins the Pending tab, so the In Progress empty
    // arm had no capture until this entry. Appended so no index shifts.
    CatalogState(
      'Empty (no active deliveries)',
      (_) => _clientHome(
        repository: ClientHomeScreenPreviewFixtures.empty(),
        initialTab: ClientHomeTab.inProgress,
      ),
    ),
    CatalogState(
      'In Progress unavailable — isolated bucket (replies retained in state)',
      (_) => _clientHome(
        repository: ClientHomeScreenPreviewFixtures.partialFailureRepository(),
        initialTab: ClientHomeTab.inProgress,
      ),
    ),
    CatalogState(
      'Refresh failed over rows',
      (_) => _clientHome(
        repository: ClientHomeScreenPreviewFixtures.refreshFailingRepository(),
        initialTab: ClientHomeTab.pendingRequests,
        failWarmRefresh: true,
      ),
    ),
    CatalogState(
      'Forbidden — no inert retry',
      (_) => _clientHome(
        repository: ClientHomeScreenPreviewFixtures.forbiddenRepository(),
        initialTab: ClientHomeTab.inProgress,
      ),
    ),
    CatalogState(
      "Cold load failed — can't reach Jeeb (host unresolved)",
      (_) => _clientHome(
        repository: ClientHomeScreenPreviewFixtures.unreachableRepository(),
        initialTab: ClientHomeTab.inProgress,
      ),
    ),
  ],
);

class _CatalogActiveDeliveriesRepository implements ActiveDeliveriesRepository {
  _CatalogActiveDeliveriesRepository(this._deliveries);

  final List<ActiveDeliverySummary> _deliveries;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async => _deliveries;
}

/// start() is a single mount read against the in-memory catalog repository (polls are gone per N2).
Widget _activeDeliveriesBanner(List<ActiveDeliverySummary> deliveries) {
  final cubit = ActiveDeliveriesCubit(
    repository: _CatalogActiveDeliveriesRepository(deliveries),
  )..start();
  return Scaffold(
    body: SafeArea(
      child: BlocProvider<ActiveDeliveriesCubit>.value(
        value: cubit,
        child: ActiveDeliveriesBanner(
          onOpenChat: (_) {},
          onManageDelivery: (_) {},
        ),
      ),
    ),
  );
}

final CatalogEntry _jeeberActiveDeliveriesEntry = CatalogEntry(
  feature: 'jeeber_active_deliveries',
  screen: 'Jeeber Active Deliveries Banner',
  states: [
    CatalogState(
      'Populated (multiple statuses)',
      (_) => _activeDeliveriesBanner(const [
        ActiveDeliverySummary(
          id: 'delivery-9001',
          status: JeeberDeliveryStatus.picked,
          title: 'Sami Fawaz — Hamra → Achrafieh',
          dropoffAddress: 'Achrafieh, Beirut',
          conversationId: 'conv-9001',
        ),
        ActiveDeliverySummary(
          id: 'delivery-9002',
          status: JeeberDeliveryStatus.inTransit,
          title: 'Rania Kassem — Verdun → Jnah',
          dropoffAddress: 'Jnah, Beirut',
          conversationId: 'conv-9002',
        ),
      ]),
    ),
    CatalogState(
      'Empty (no active deliveries — banner self-hides)',
      (_) => _activeDeliveriesBanner(const []),
    ),
    // Appended, not inserted: two deliveries trip the disclosure threshold and
    // collapse to a row with ZERO cards, so only ONE renders the card itself.
    CatalogState(
      'One delivery (pinned card — under the disclosure threshold)',
      (_) => _activeDeliveriesBanner(const [
        ActiveDeliverySummary(
          id: 'delivery-9003',
          status: JeeberDeliveryStatus.atDoor,
          title: 'Nadia Haddad — Mar Mikhael → Badaro',
          dropoffAddress: 'Badaro, Beirut',
          conversationId: 'conv-9003',
        ),
      ]),
    ),
    CatalogState(
      'Load failed — compact failure block',
      (_) => _activeDeliveriesSeated(
        failedActiveDeliveriesCubit(const NetworkFailure()),
      ),
    ),
    CatalogState(
      'Loading — the banner hides itself',
      (_) => _activeDeliveriesSeated(
        ActiveDeliveriesCubit(
          repository: const StalledActiveDeliveriesRepository(),
        )..start(),
      ),
    ),
  ],
);

/// Seats a pre-built cubit, for the rungs a canned repository cannot reach.
Widget _activeDeliveriesSeated(ActiveDeliveriesCubit cubit) => Scaffold(
  body: SafeArea(
    child: BlocProvider<ActiveDeliveriesCubit>.value(
      value: cubit,
      child: ActiveDeliveriesBanner(
        onOpenChat: (_) {},
        onManageDelivery: (_) {},
      ),
    ),
  ),
);

/// Provides AvailabilityCubit the screen reads from didChangeDependencies (calls load()).
/// Feed cubit seeded in constructor (no subscriptions or timers).
Widget _jeeberHomeRegistered({
  required AvailabilityCubit availability,
  RequestFeedCubit? feedCubit,
  VoidCallback? onRegister,
}) {
  return BlocProvider<AvailabilityCubit>.value(
    value: availability,
    child: JeeberHomeScreen(
      profileName: JeeberHomeScreenPreviewFixtures.profileName,
      requestFeedCubit: feedCubit,
      onRegister: onRegister,
      submittedOffersCubitFactory:
          JeeberHomeScreenPreviewFixtures.submittedOffersCubit,
    ),
  );
}

final CatalogEntry _jeeberHomeEntry = CatalogEntry(
  feature: 'jeeber_home',
  screen: 'Jeeber Home (Dashboard tab)',
  states: [
    CatalogState(
      'State 1 — Unregistered upsell',
      (_) => const JeeberHomeScreen(
        isRegistered: false,
        profileName: JeeberHomeScreenPreviewFixtures.profileName,
      ),
    ),
    CatalogState(
      'State 2 — Registered, offline, no requests',
      (_) => _jeeberHomeRegistered(
        availability: JeeberHomeScreenPreviewFixtures.offlineAvailability(),
      ),
    ),
    CatalogState(
      'State 2 — Registered, online, no requests',
      (_) => _jeeberHomeRegistered(
        availability: JeeberHomeScreenPreviewFixtures.onlineAvailability(),
      ),
    ),
    CatalogState(
      'State 3 — Registered, online, live feed',
      (_) => _jeeberHomeRegistered(
        availability: JeeberHomeScreenPreviewFixtures.onlineAvailability(),
        feedCubit: JeeberHomeScreenPreviewFixtures.feed(
          JeeberHomeScreenPreviewFixtures.incomingFeed(),
        ),
      ),
    ),
    CatalogState(
      'Load error (retry)',
      (_) => _jeeberHomeRegistered(
        availability: JeeberHomeScreenPreviewFixtures.failingAvailability(),
      ),
    ),
    // M4: appended, not inserted — the capture filenames are index-keyed. This
    // is the ONLY mount of `JeeberFeedEmptyView` and it had no capture.
    CatalogState(
      'Dev feed — empty view (JeeberFeedEmptyView)',
      (_) => const Scaffold(
        // Its `OmdsSwitchTile` needs a Material ancestor; the capture harness
        // mounts a builder directly, not inside a screen.
        body: JeeberFeedEmptyView(
          profileName: JeeberHomeScreenPreviewFixtures.profileName,
        ),
      ),
    ),
    CatalogState(
      'Feed load failed (503)',
      (_) => _jeeberHomeRegistered(
        availability: JeeberHomeScreenPreviewFixtures.onlineAvailability(),
        feedCubit: JeeberHomeScreenPreviewFixtures.failedFeed(
          const ServerFailure(status: 503),
        ),
      ),
    ),
    CatalogState(
      'Feed refresh failed — stale rows stay up',
      (_) => _jeeberHomeRegistered(
        availability: JeeberHomeScreenPreviewFixtures.onlineAvailability(),
        feedCubit: JeeberHomeScreenPreviewFixtures.refreshFailedFeed(
          JeeberHomeScreenPreviewFixtures.incomingFeed(),
          const NetworkFailure(offline: true),
        ),
      ),
    ),
    CatalogState(
      'Not registered — availability answered 404',
      (context) => _jeeberHomeRegistered(
        availability:
            JeeberHomeScreenPreviewFixtures.notRegisteredAvailability(),
        onRegister: () => context.pushNamed('jeeber-onboarding'),
      ),
    ),
    CatalogState(
      'Availability forbidden — KYC exit, no inert retry',
      (_) => _jeeberHomeRegistered(
        availability: JeeberHomeScreenPreviewFixtures.failingAvailabilityOf(
          const ForbiddenFailure(),
        ),
      ),
    ),
  ],
);

/// Each step seated on a cubit from fixtures to keep the catalog inert (avoids GetIt).
final CatalogEntry _jeeberOnboardingEntry = CatalogEntry(
  feature: 'jeeber_onboarding',
  screen: 'Delivery-Man Onboarding Wizard',
  states: [
    CatalogState(
      'Step 1 — Photo',
      (_) => DmOnboardingScreen(
        cubit: DmOnboardingScreenPreviewFixtures.photoStep(),
      ),
    ),
    CatalogState(
      'Step 2 — Address',
      (_) => DmOnboardingScreen(
        cubit: DmOnboardingScreenPreviewFixtures.addressStep(),
      ),
    ),
    CatalogState(
      'Step 3 — Service area',
      (_) => DmOnboardingScreen(
        cubit: DmOnboardingScreenPreviewFixtures.serviceAreaStep(),
      ),
    ),
    CatalogState(
      'Step 3 — Checking coverage',
      (_) => DmOnboardingScreen(
        cubit: DmOnboardingScreenPreviewFixtures.checkingCoverage(),
      ),
    ),
    CatalogState(
      'Step 3 — Coverage check failed',
      (_) => DmOnboardingScreen(
        cubit: DmOnboardingScreenPreviewFixtures.coverageFailed(),
      ),
    ),
  ],
);
