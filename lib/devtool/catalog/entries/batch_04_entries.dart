import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../catalog_models.dart';

import '../../../features/escalate/application/escalate_cubit.dart';
import '../../../features/escalate/domain/escalate_repository.dart';
import '../../../features/escalate/presentation/escalate_screen.dart';

import '../../../features/goods_cost/data/fake_goods_cost_repository.dart';
import '../../../features/goods_cost/domain/goods_cost_repository.dart';
import '../../../features/goods_cost/presentation/goods_cost_screen.dart';

import '../../../features/home_client/application/client_home_cubit.dart';
import '../../../features/home_client/application/client_home_state.dart';
import '../../../features/home_client/data/dev_client_home_fixtures.dart';
import '../../../features/home_client/data/in_memory_client_home_repository.dart';
import '../../../features/home_client/domain/client_home_repository.dart';
import '../../../features/home_client/presentation/client_home_screen.dart';

import '../../../features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import '../../../features/jeeber_active_deliveries/application/active_deliveries_cubit.dart';
import '../../../features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import '../../../features/jeeber_active_deliveries/domain/active_delivery_summary.dart';
import '../../../features/jeeber_active_deliveries/presentation/active_deliveries_banner.dart';

import '../../../features/jeeber_home/application/availability_cubit.dart';
import '../../../features/jeeber_home/domain/entities/availability_status.dart';
import '../../../features/jeeber_home/domain/services/availability_gateway.dart';
import '../../../features/jeeber_home/presentation/jeeber_home_screen.dart';
import '../../../features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../../../features/jeeber_request_feed/cubit/submitted_offers_cubit.dart';
import '../../../features/jeeber_request_feed/data/dev_jeeber_feed_fixtures.dart';
import '../../../features/jeeber_request_feed/data/request_feed_repository.dart';
import '../../../features/jeeber_request_feed/domain/submitted_offers_repository.dart';
import '../../../features/jeeber_request_feed/domain/submitted_offer.dart';

import '../../../features/jeeber_onboarding/application/dm_onboarding_state.dart';
import '../../../features/jeeber_onboarding/presentation/dm_onboarding_screen.dart';

List<CatalogEntry> get batch04Entries => <CatalogEntry>[
  _escalateEntry,
  _goodsCostEntry,
  _clientHomeEntry,
  _jeeberActiveDeliveriesEntry,
  _jeeberHomeEntry,
  _jeeberOnboardingEntry,
];


enum _EscalateFixture {
  evidenceLoaded,
  evidenceDegraded,
  submitting,
  submitError,
}

class _CatalogEscalateRepository implements EscalateRepository {
  _CatalogEscalateRepository(this.fixture);

  final _EscalateFixture fixture;

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) async {
    if (fixture == _EscalateFixture.evidenceDegraded) {
      throw const EscalateException(EscalateErrorKind.network);
    }
    return const EscalateEvidence(
      chatSnapshotUrl: 'https://cdn.example.com/dispute/snapshot.png',
      chatMessageCount: 12,
      timeline: [
        EscalateTimelineEntry(status: 'Ordered'),
        EscalateTimelineEntry(status: 'Picked'),
        EscalateTimelineEntry(status: 'InTransit'),
      ],
    );
  }

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const [],
    String? voicePath,
    EscalateEvidence evidence = EscalateEvidence.empty,
  }) {
    switch (fixture) {
      case _EscalateFixture.submitting:
        return Completer<EscalateResult>().future;
      case _EscalateFixture.submitError:
        throw const EscalateException(EscalateErrorKind.network);
      case _EscalateFixture.evidenceLoaded:
      case _EscalateFixture.evidenceDegraded:
        return Future<EscalateResult>.value(
          const EscalateResult(caseId: 'DSP-1001', status: 'open'),
        );
    }
  }
}

Widget _escalateScreen(_EscalateFixture fixture, {bool preSubmit = false}) {
  return BlocProvider<EscalateCubit>(
    create: (_) {
      final cubit = EscalateCubit(
        repository: _CatalogEscalateRepository(fixture),
        deliveryId: 'DEL-1001',
      );
      if (preSubmit) {
        cubit
          ..setReason(EscalateReason.damaged)
          ..submit();
      }
      return cubit;
    },
    child: const EscalateScreen(),
  );
}

final CatalogEntry _escalateEntry = CatalogEntry(
  feature: 'escalate',
  screen: 'Dispute Open + Evidence',
  states: [
    CatalogState(
      'Reason picker (evidence loaded)',
      (_) => _escalateScreen(_EscalateFixture.evidenceLoaded),
    ),
    CatalogState(
      'Evidence degraded (chat/timeline unavailable)',
      (_) => _escalateScreen(_EscalateFixture.evidenceDegraded),
    ),
    CatalogState(
      'Submitting',
      (_) => _escalateScreen(_EscalateFixture.submitting, preSubmit: true),
    ),
    CatalogState(
      'Error (network)',
      (_) => _escalateScreen(_EscalateFixture.submitError, preSubmit: true),
    ),
  ],
);


final CatalogEntry _goodsCostEntry = CatalogEntry(
  feature: 'goods_cost',
  screen: 'Enter Goods Cost',
  states: [
    CatalogState(
      'Currency loaded (USD)',
      (_) => GoodsCostScreen(
        deliveryId: 'DEL-2001',
        repository: FakeGoodsCostRepository(currency: 'USD'),
      ),
    ),
    CatalogState(
      'Currency loaded (LBP)',
      (_) => GoodsCostScreen(
        deliveryId: 'DEL-2002',
        repository: FakeGoodsCostRepository(currency: 'LBP'),
      ),
    ),
    CatalogState(
      'Currency read degraded (label falls back neutral)',
      (_) => GoodsCostScreen(
        deliveryId: 'DEL-2003',
        repository: FakeGoodsCostRepository(
          fetchFailure: GoodsCostFailure.network,
        ),
      ),
    ),
  ],
);


class _FailingClientHomeRepository implements ClientHomeRepository {
  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    throw StateError('catalog: simulated load failure');
  }
}

Widget _clientHome({
  required ClientHomeRepository repository,
  required ClientHomeTab initialTab,
  String? name = 'Layla',
}) {
  return Scaffold(
    body: BlocProvider<ClientHomeCubit>(
      create: (_) => ClientHomeCubit(
        repository: repository,
        greetingNameProvider: () => name,
      ),
      child: ClientHomeScreen(
        initialTab: initialTab,
        onCreateRequest: () {},
        onTrack: (_) {},
      ),
    ),
  );
}

ClientHomeRepository _populatedClientHomeRepo() =>
    InMemoryClientHomeRepository.fromSnapshot(
      DevClientHomeFixtures.snapshot(),
      latency: Duration.zero,
    );

final CatalogEntry _clientHomeEntry = CatalogEntry(
  feature: 'home_client',
  screen: 'Client Home (Requests tab)',
  states: [
    CatalogState(
      'In Progress (populated)',
      (_) => _clientHome(
        repository: _populatedClientHomeRepo(),
        initialTab: ClientHomeTab.inProgress,
      ),
    ),
    CatalogState(
      'Pending Requests (populated)',
      (_) => _clientHome(
        repository: _populatedClientHomeRepo(),
        initialTab: ClientHomeTab.pendingRequests,
      ),
    ),
    CatalogState(
      'Replies (populated)',
      (_) => _clientHome(
        repository: _populatedClientHomeRepo(),
        initialTab: ClientHomeTab.replies,
      ),
    ),
    CatalogState(
      'Empty (no requests)',
      (_) => _clientHome(
        repository: InMemoryClientHomeRepository(latency: Duration.zero),
        initialTab: ClientHomeTab.pendingRequests,
      ),
    ),
    CatalogState(
      'Load failed (retry)',
      (_) => _clientHome(
        repository: _FailingClientHomeRepository(),
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


class _EmptySubmittedOffersRepository implements SubmittedOffersRepository {
  @override
  Future<List<SubmittedOffer>> listSubmitted() async => const [];

  @override
  Future<bool> withdraw(String offerId) async => true;
}

SubmittedOffersCubit _catalogSubmittedOffersCubit() =>
    SubmittedOffersCubit(repository: _EmptySubmittedOffersRepository());

Widget _jeeberHomeRegistered({
  required AvailabilityGateway gateway,
  RequestFeedCubit? feedCubit,
}) {
  final availability = AvailabilityCubit(
    gateway: gateway,
    tickerFactory: () => const Stream<DateTime>.empty(),
  );
  final body = BlocProvider<AvailabilityCubit>.value(
    value: availability,
    child: JeeberHomeScreen(
      profileName: 'Kamal',
      requestFeedCubit: feedCubit,
      submittedOffersCubitFactory: _catalogSubmittedOffersCubit,
    ),
  );
  return body;
}

final CatalogEntry _jeeberHomeEntry = CatalogEntry(
  feature: 'jeeber_home',
  screen: 'Jeeber Home (Dashboard tab)',
  states: [
    CatalogState(
      'State 1 — Unregistered upsell',
      (_) => const JeeberHomeScreen(isRegistered: false, profileName: 'Kamal'),
    ),
    CatalogState(
      'State 2 — Registered, offline, no requests',
      (_) => _jeeberHomeRegistered(gateway: InMemoryAvailabilityGateway()),
    ),
    CatalogState(
      'State 2 — Registered, online, no requests',
      (_) => _jeeberHomeRegistered(
        gateway: InMemoryAvailabilityGateway(
          initial: const AvailabilityStatus(
            state: AvailabilityState.online,
            activeDeliveryCount: 0,
          ),
        ),
      ),
    ),
    CatalogState(
      'State 3 — Registered, online, live feed',
      (_) => _jeeberHomeRegistered(
        gateway: InMemoryAvailabilityGateway(
          initial: const AvailabilityStatus(
            state: AvailabilityState.online,
            activeDeliveryCount: 0,
          ),
        ),
        feedCubit: RequestFeedCubit(
          repository: SeededRequestFeedRepository(
            DevJeeberFeedFixtures.incoming(),
          ),
        )..start(),
      ),
    ),
    CatalogState(
      'Load error (retry)',
      (_) => _jeeberHomeRegistered(
        gateway: InMemoryAvailabilityGateway(respondWithError: true),
      ),
    ),
  ],
);


final CatalogEntry _jeeberOnboardingEntry = CatalogEntry(
  feature: 'jeeber_onboarding',
  screen: 'Delivery-Man Onboarding Wizard',
  states: [
    CatalogState(
      'Step 1 — Photo',
      (_) => const DmOnboardingScreen(initialStep: DmOnboardingStep.photo),
    ),
    CatalogState(
      'Step 2 — Address',
      (_) => const DmOnboardingScreen(initialStep: DmOnboardingStep.address),
    ),
    CatalogState(
      'Step 3 — Service area',
      (_) =>
          const DmOnboardingScreen(initialStep: DmOnboardingStep.serviceArea),
    ),
  ],
);
