import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/home_client/application/client_home_cubit.dart';
import '../../../features/home_client/data/dev_client_home_fixtures.dart';
import '../../../features/home_client/data/in_memory_client_home_repository.dart';
import '../../../features/home_client/domain/client_home_repository.dart';
import '../../../features/home_client/presentation/client_home_screen.dart';
import '../../../features/jeeber_home/application/availability_cubit.dart';
import '../../../features/jeeber_home/domain/entities/availability_status.dart';
import '../../../features/jeeber_home/domain/entities/feed_request.dart';
import '../../../features/jeeber_home/domain/services/availability_gateway.dart';
import '../../../features/jeeber_home/presentation/jeeber_home_screen.dart';
import '../../../features/jeeber_onboarding/application/dm_onboarding_cubit.dart';
import '../../../features/jeeber_onboarding/application/dm_onboarding_state.dart';
import '../../../features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';
import '../../../features/jeeber_onboarding/presentation/dm_onboarding_screen.dart';
import '../../../features/jeeber_onboarding_funding/presentation/onboarding_funding_screen.dart';
import '../../../features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart';
import '../../../features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import '../../../features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart';
import '../../../features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart';
import '../../../features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../../../features/jeeber_request_feed/data/dev_jeeber_feed_fixtures.dart';
import '../../../features/jeeber_request_feed/data/request_feed_repository.dart';
import '../../../features/jeeber_request_feed/domain/submitted_offer.dart';
import '../../../features/jeeber_request_feed/domain/submitted_offers_repository.dart';
import '../../../features/photo_attachment/data/stub_photo_picker_service.dart';
import '../../../features/wallet/data/stub_wallet_repository.dart';
import '../../../features/wallet/domain/wallet_repository.dart';
import '../catalog_models.dart';

/// Batch 04 — home_client, jeeber_home, jeeber_onboarding,
/// jeeber_onboarding_funding, jeeber_pending_offers, jeeber_request_detail.
///
/// Every state below passes an explicit LOCAL fake/stub (no live gateway) so
/// the real screen renders its DESIGNED state with no network round-trip.
List<CatalogEntry> get batch04Entries => <CatalogEntry>[
      const CatalogEntry(
        feature: 'home_client',
        screen: 'ClientHomeScreen',
        states: [
          CatalogState('Ready — populated (all tabs)', _clientHomeReady),
          CatalogState('Empty — no orders yet', _clientHomeEmpty),
          CatalogState('Failed to load', _clientHomeFailed),
        ],
      ),
      const CatalogEntry(
        feature: 'jeeber_home',
        screen: 'JeeberHomeScreen',
        states: [
          CatalogState('State 1 — Unregistered', _jeeberHomeUnregistered),
          CatalogState(
            'State 2 — Available, no requests',
            _jeeberHomeAvailableEmpty,
          ),
          CatalogState('State 2 — Load error', _jeeberHomeLoadError),
          CatalogState(
            'State 3 — Available, feed with requests',
            _jeeberHomeFeedPopulated,
          ),
        ],
      ),
      const CatalogEntry(
        feature: 'jeeber_onboarding',
        screen: 'DmOnboardingScreen',
        states: [
          CatalogState('Step 1 — Photo', _dmOnboardingPhoto),
          CatalogState('Step 2 — Address', _dmOnboardingAddress),
          CatalogState('Step 3 — Service area', _dmOnboardingServiceArea),
        ],
      ),
      const CatalogEntry(
        feature: 'jeeber_onboarding_funding',
        screen: 'OnboardingFundingScreen',
        states: [
          CatalogState('Starter credit explainer', _fundingDefault),
          CatalogState('With active reserve', _fundingWithReserve),
        ],
      ),
      const CatalogEntry(
        feature: 'jeeber_pending_offers',
        screen: 'JeeberPendingOffersScreen',
        states: [
          CatalogState('Populated', _pendingOffersPopulated),
          CatalogState('Empty', _pendingOffersEmpty),
          CatalogState('Error', _pendingOffersError),
        ],
      ),
      const CatalogEntry(
        feature: 'jeeber_request_detail',
        screen: 'JeeberRequestDetailScreen',
        states: [
          CatalogState('Request summary', _requestDetail),
        ],
      ),
      const CatalogEntry(
        feature: 'jeeber_request_detail',
        screen: 'JeeberRequestUnavailableScreen',
        states: [
          CatalogState('Unavailable', _requestUnavailable),
        ],
      ),
    ];

// ───────────────────────── home_client ─────────────────────────

Widget _clientHomeReady(BuildContext _) => BlocProvider<ClientHomeCubit>(
      create: (_) => ClientHomeCubit(
        repository: InMemoryClientHomeRepository.fromSnapshot(
          DevClientHomeFixtures.snapshot(),
        ),
        greetingNameProvider: () => 'Alex',
      ),
      child: const ClientHomeScreen(),
    );

Widget _clientHomeEmpty(BuildContext _) => BlocProvider<ClientHomeCubit>(
      create: (_) => ClientHomeCubit(
        repository: InMemoryClientHomeRepository(),
        greetingNameProvider: () => 'Alex',
      ),
      child: const ClientHomeScreen(),
    );

Widget _clientHomeFailed(BuildContext _) => BlocProvider<ClientHomeCubit>(
      create: (_) => ClientHomeCubit(
        repository: const _FailingClientHomeRepository(),
        greetingNameProvider: () => 'Alex',
      ),
      child: const ClientHomeScreen(),
    );

/// Local fake — always throws so the cubit surfaces [ClientHomeStatus.failed].
class _FailingClientHomeRepository implements ClientHomeRepository {
  const _FailingClientHomeRepository();

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    throw Exception('client home load failed (catalog fixture)');
  }
}

// ───────────────────────── jeeber_home ─────────────────────────

Widget _jeeberHomeUnregistered(BuildContext _) => const JeeberHomeScreen(
      isRegistered: false,
      profileName: 'Karim Abou Chakra',
    );

Widget _jeeberHomeAvailableEmpty(BuildContext _) =>
    BlocProvider<AvailabilityCubit>(
      create: (_) => AvailabilityCubit(
        gateway: InMemoryAvailabilityGateway(
          initial: AvailabilityStatus.initial.copyWith(
            state: AvailabilityState.online,
          ),
        ),
      ),
      child: const JeeberHomeScreen(
        isRegistered: true,
        profileName: 'Karim Abou Chakra',
      ),
    );

Widget _jeeberHomeLoadError(BuildContext _) => BlocProvider<AvailabilityCubit>(
      create: (_) => AvailabilityCubit(
        gateway: InMemoryAvailabilityGateway(respondWithError: true),
      ),
      child: const JeeberHomeScreen(
        isRegistered: true,
        profileName: 'Karim Abou Chakra',
      ),
    );

Widget _jeeberHomeFeedPopulated(BuildContext _) =>
    BlocProvider<AvailabilityCubit>(
      create: (_) => AvailabilityCubit(
        gateway: InMemoryAvailabilityGateway(
          initial: AvailabilityStatus.initial.copyWith(
            state: AvailabilityState.online,
          ),
        ),
      ),
      child: JeeberHomeScreen(
        isRegistered: true,
        profileName: 'Karim Abou Chakra',
        requestFeedCubit: RequestFeedCubit(
          repository: SeededRequestFeedRepository(
            DevJeeberFeedFixtures.incoming(),
          ),
        )..start(),
      ),
    );

// ───────────────────────── jeeber_onboarding ─────────────────────────

Widget _dmOnboardingPhoto(BuildContext _) =>
    _dmOnboarding(DmOnboardingStep.photo);

Widget _dmOnboardingAddress(BuildContext _) =>
    _dmOnboarding(DmOnboardingStep.address);

Widget _dmOnboardingServiceArea(BuildContext _) =>
    _dmOnboarding(DmOnboardingStep.serviceArea);

Widget _dmOnboarding(DmOnboardingStep step) => DmOnboardingScreen(
      cubit: DmOnboardingCubit(
        pickerService: StubPhotoPickerService(),
        gateway: FakeDmOnboardingGateway(),
        initialStep: step,
      ),
    );

// ───────────────────────── jeeber_onboarding_funding ─────────────────────────

Widget _fundingDefault(BuildContext _) => const OnboardingFundingScreen(
      repository: StubWalletRepository(),
    );

Widget _fundingWithReserve(BuildContext _) => const OnboardingFundingScreen(
      repository: _FakeWalletRepository(
        WalletBalance(
          availableBalance: 80,
          affordabilityState: WalletAffordability.low,
          reservedNow: 15,
          giftCredit: 50,
          currency: 'SAR',
        ),
      ),
    );

/// Local fake — returns a fixed snapshot so the enrichment amounts render
/// without a live `GET /v1/jeeb/wallet` call.
class _FakeWalletRepository implements WalletRepository {
  const _FakeWalletRepository(this._balance);
  final WalletBalance _balance;

  @override
  Future<WalletBalance> fetchBalance() async => _balance;
}

// ───────────────────────── jeeber_pending_offers ─────────────────────────

Widget _pendingOffersPopulated(BuildContext _) => const JeeberPendingOffersScreen(
      repository: _FakeSubmittedOffersRepository([
        SubmittedOffer(
          id: 'offer-1',
          requestId: 'req-1',
          price: 12.5,
          currency: 'USD',
          etaMinutes: 25,
          note: 'Can pick up in 10 minutes',
        ),
        SubmittedOffer(
          id: 'offer-2',
          requestId: 'req-2',
          price: 8,
          currency: 'USD',
          etaMinutes: 15,
        ),
      ]),
    );

Widget _pendingOffersEmpty(BuildContext _) => const JeeberPendingOffersScreen(
      repository: _FakeSubmittedOffersRepository([]),
    );

Widget _pendingOffersError(BuildContext _) => const JeeberPendingOffersScreen(
      repository: _FakeSubmittedOffersRepository(
        [],
        shouldFail: true,
      ),
    );

/// Local fake — returns a canned list (or throws), never touches the network.
class _FakeSubmittedOffersRepository implements SubmittedOffersRepository {
  const _FakeSubmittedOffersRepository(this._offers, {this.shouldFail = false});

  final List<SubmittedOffer> _offers;
  final bool shouldFail;

  @override
  Future<List<SubmittedOffer>> listSubmitted() async {
    if (shouldFail) {
      throw Exception('submitted offers load failed (catalog fixture)');
    }
    return _offers;
  }

  @override
  Future<bool> withdraw(String offerId) async => true;
}

// ───────────────────────── jeeber_request_detail ─────────────────────────

Widget _requestDetail(BuildContext _) => JeeberRequestDetailScreen(
      request: const FeedRequest(id: 'req-123', shortLabel: 'Hamra, Beirut'),
      reportService: const ProhibitedItemReportService(),
      onDeclined: (_) {},
    );

Widget _requestUnavailable(BuildContext _) => JeeberRequestUnavailableScreen(
      requestId: 'req-999',
      onBack: () {},
    );
