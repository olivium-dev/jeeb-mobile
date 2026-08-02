import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../catalog_models.dart';

// ── escalate (dispute-open-evidence) ─────────────────────────────────────────
import '../../../features/escalate/application/escalate_cubit.dart';
import '../../../features/escalate/domain/escalate_repository.dart';
import '../../../features/escalate/presentation/escalate_screen.dart';
import '../fixtures/escalate_screen_fixtures.dart';

// ── goods_cost ────────────────────────────────────────────────────────────────
import '../../../features/goods_cost/presentation/goods_cost_screen.dart';
import '../fixtures/goods_cost_screen_fixtures.dart';

// ── home_client ───────────────────────────────────────────────────────────────
import '../../../features/home_client/application/client_home_cubit.dart';
import '../../../features/home_client/application/client_home_state.dart';
import '../../../features/home_client/domain/client_home_repository.dart';
import '../../../features/home_client/presentation/client_home_screen.dart';
import '../fixtures/client_home_screen_fixtures.dart';

// ── jeeber_active_deliveries ──────────────────────────────────────────────────
import '../../../features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../../../features/jeeber_active_deliveries/application/active_deliveries_cubit.dart';
import '../../../features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import '../../../features/jeeber_active_deliveries/domain/active_delivery_summary.dart';
import '../../../features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart';

// ── jeeber_home ───────────────────────────────────────────────────────────────
import '../../../features/jeeber_home/application/availability_cubit.dart';
import '../../../features/jeeber_home/presentation/jeeber_home_screen.dart';
import '../../../features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../fixtures/jeeber_home_screen_fixtures.dart';

// ── jeeber_onboarding ─────────────────────────────────────────────────────────
import '../../../features/jeeber_onboarding/presentation/dm_onboarding_screen.dart';
import '../fixtures/dm_onboarding_screen_fixtures.dart';

/// Batch 04 catalog entries — DT-04 / F2 Screen Catalog.
///
/// Covers: escalate, goods_cost, home_client, jeeber_active_deliveries,
/// jeeber_home, jeeber_onboarding — verified against the REBASED v2 source
/// under `lib/features/<feature>/` (constructors, cubit/repository contracts,
/// `*_state.dart`). Every state renders the REAL screen with an explicit local
/// fake/stub collaborator — no GetIt, no network.
List<CatalogEntry> get batch04Entries => <CatalogEntry>[
  _escalateEntry,
  _goodsCostEntry,
  _clientHomeEntry,
  _jeeberActiveDeliveriesEntry,
  _jeeberHomeEntry,
  _jeeberOnboardingEntry,
];

// ═════════════════════════════════════════════════════════════════════════
// escalate — dispute-open-evidence (JM-060)
// ═════════════════════════════════════════════════════════════════════════

/// The four designed states below are named once in
/// [EscalateScreenPreviewFixtures] and shared verbatim with the JEEB PREVIEWS
/// section at the bottom of
/// `features/escalate/presentation/escalate_screen.dart`, so the designer's
/// in-app browser and the preview canvas cannot drift into showing two
/// different "designed states" of the same screen. The scripted repository and
/// the cubit pre-drive both live there; this entry only says which state goes
/// under which label.
///
/// [preSubmit] fires `setReason → submit` before the first frame, which is what
/// separates the submitting/error states from the two evidence ones — nothing
/// here taps anything.
Widget _escalateScreen(EscalateRepository repository, {bool preSubmit = false}) {
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
      (_) => _escalateScreen(EscalateScreenPreviewFixtures.evidenceLoaded()),
    ),
    CatalogState(
      'Evidence degraded (chat/timeline unavailable)',
      (_) => _escalateScreen(EscalateScreenPreviewFixtures.evidenceDegraded()),
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
  ],
);

// ═════════════════════════════════════════════════════════════════════════
// goods_cost — "Enter Goods Cost"
// ═════════════════════════════════════════════════════════════════════════

/// The three designed states below are named once in
/// [GoodsCostScreenPreviewFixtures] and shared verbatim with the JEEB PREVIEWS
/// section at the bottom of
/// `features/goods_cost/presentation/goods_cost_screen.dart`, so the designer's
/// in-app browser and the preview canvas cannot drift into showing two
/// different "designed states" of the same screen. `repository:` is the
/// screen's ONLY seam — it builds its own cubit and calls `loadCurrency()` at
/// mount — so a state here is described entirely by what that collaborator
/// answers.
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
  ],
);

// ═════════════════════════════════════════════════════════════════════════
// home_client — Client Home (Requests tab: In Progress / Pending / Replies)
// ═════════════════════════════════════════════════════════════════════════

/// Wraps [ClientHomeScreen] in the [BlocProvider] + [Scaffold] it expects
/// from its host shell. The
/// screen's own `initState` calls `cubit.load()`, so no manual trigger is
/// needed here.
///
/// The fakes and their canned data live in
/// [ClientHomeScreenPreviewFixtures] — shared verbatim with the JEEB PREVIEWS
/// section at the bottom of `client_home_screen.dart`, so the catalog and the
/// preview canvas cannot drift into showing two different "designed states".
Widget _clientHome({
  required ClientHomeRepository repository,
  required ClientHomeTab initialTab,
  String? name = ClientHomeScreenPreviewFixtures.greetingName,
}) {
  return Scaffold(
    body: BlocProvider<ClientHomeCubit>(
      create: (_) => ClientHomeScreenPreviewFixtures.cubit(
        repository,
        name: name,
      ),
      child: ClientHomeScreen(
        initialTab: initialTab,
        onCreateRequest: () {},
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
  ],
);

// ═════════════════════════════════════════════════════════════════════════
// jeeber_active_deliveries — the jeeber Dashboard's "active deliveries" banner
// ═════════════════════════════════════════════════════════════════════════

class _CatalogActiveDeliveriesRepository implements ActiveDeliveriesRepository {
  _CatalogActiveDeliveriesRepository(this._deliveries);

  final List<ActiveDeliverySummary> _deliveries;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async => _deliveries;
}

/// The million-day `pollInterval` this used to pass — the long-lived
/// preview-cubit convention for keeping a `Timer.periodic` from firing during a
/// preview session — is gone with the poll itself (N2). `start()` is now a
/// single mount read against the in-memory catalog repository and schedules
/// nothing.
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
  ],
);

// ═════════════════════════════════════════════════════════════════════════
// jeeber_home — the jeeber Dashboard tab (unregistered / available / feed)
// ═════════════════════════════════════════════════════════════════════════

/// Registered-path wrapper: provides the [AvailabilityCubit] the screen reads
/// from `didChangeDependencies` (which calls `.load()`).
///
/// The collaborators behind every state below live in
/// [JeeberHomeScreenPreviewFixtures] — shared verbatim with the JEEB PREVIEWS
/// section at the bottom of
/// `features/jeeber_home/presentation/jeeber_home_screen.dart`, so the
/// designer's in-app browser and the preview canvas cannot drift into showing
/// two different "designed states" of the same screen. This entry only says
/// which state goes under which label.
///
/// Both inert collaborators come from there too: the availability cubit's empty
/// inactivity ticker (the 8 h auto-offline rule never schedules a timer) and a
/// feed cubit seeded in its constructor rather than `start()`ed (no
/// subscriptions, no 1 s expiry sweep behind a catalog page).
Widget _jeeberHomeRegistered({
  required AvailabilityCubit availability,
  RequestFeedCubit? feedCubit,
}) {
  return BlocProvider<AvailabilityCubit>.value(
    value: availability,
    child: JeeberHomeScreen(
      profileName: JeeberHomeScreenPreviewFixtures.profileName,
      requestFeedCubit: feedCubit,
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
  ],
);

// ═════════════════════════════════════════════════════════════════════════
// jeeber_onboarding — delivery-man onboarding wizard (photo → address → area)
// ═════════════════════════════════════════════════════════════════════════

/// The three wizard steps, each seated on a cubit from
/// [DmOnboardingScreenPreviewFixtures] and shared verbatim with the JEEB
/// PREVIEWS section at the bottom of `dm_onboarding_screen.dart`.
///
/// The states used to be `const DmOnboardingScreen(initialStep: …)` with no
/// cubit, which makes the screen resolve its own gateway out of GetIt — inside
/// the app that is the live `DioDmOnboardingGateway`. Seating an explicit cubit
/// keeps the catalog inert and keeps it from drifting away from the canvas.
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
  ],
);
