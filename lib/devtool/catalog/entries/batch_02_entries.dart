import 'package:flutter/material.dart';

import '../../../features/cancel_request/application/cancel_request_state.dart';
import '../../../features/cancel_request/data/fake_cancel_request_repository.dart';
import '../../../features/cancel_request/domain/cancel_request_repository.dart';
import '../../../features/cancel_request/presentation/cancel_request_sheet.dart';
import '../../../features/cancellation/domain/cancellation_result.dart';
import '../../../features/cancellation/presentation/cancellation_screen.dart';
import '../../../features/cancellation/presentation/widgets/cancellation_success_sheet.dart';
import '../../../features/chat/domain/chat_gateway.dart';
import '../../../features/chat/presentation/chat_screen.dart';
import '../../../features/client_offers/application/offer_accept_state.dart';
import '../../../features/client_offers/data/fake_offers_repository.dart';
import '../../../features/client_offers/domain/jeeber_vehicle.dart';
import '../../../features/client_offers/domain/offer.dart';
import '../../../features/client_offers/domain/offers_repository.dart';
import '../../../features/client_offers/presentation/client_offers_screen.dart';
import '../../../features/client_offers/presentation/widgets/offer_accept_sheet.dart';
import '../../../features/client_unreachable/presentation/client_unreachable_screen.dart';
import '../../../core/diagnostics/diagnostics_screen.dart';
import '../../../core/router/profile_unavailable_screen.dart';
import '../../../core/network/app_failure.dart';
import '../../../features/customer_profile/domain/customer_profile_repository.dart';
import '../../../features/customer_profile/domain/customer_profile_view_data.dart';
import '../../../features/customer_profile/presentation/customer_profile_screen.dart';
import '../catalog_models.dart';
import '../fixtures/first_group_transition_fixtures.dart';
import '../fixtures/cancellation_screen_fixtures.dart';
import '../fixtures/chat_screen_fixtures.dart';
import '../fixtures/client_offers_screen_fixtures.dart';
import '../fixtures/client_unreachable_screen_fixtures.dart';
import '../fixtures/customer_profile_screen_fixtures.dart';
import '../fixtures/diagnostics_screen_fixtures.dart';

// Batch 02: cancel_request, cancellation, chat, client_offers, etc — uses LOCAL fakes, never hit live gateway.
List<CatalogEntry> get batch02Entries => <CatalogEntry>[
  _cancelRequestSheetEntry,
  _cancellationScreenEntry,
  _cancellationSuccessSheetEntry,
  _chatScreenEntry,
  _clientOffersScreenEntry,
  _offerAcceptSheetEntry,
  _clientUnreachableScreenEntry,
  _customerProfileScreenEntry,
  _profileUnavailableScreenEntry,
  _diagnosticsScreenEntry,
];

// Wrap sheets in Scaffold to match showModalBottomSheet presentation.
Widget _sheetHost(Widget sheet) {
  return Builder(
    builder: (context) => Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Align(alignment: Alignment.bottomCenter, child: sheet),
    ),
  );
}

final CatalogEntry _cancelRequestSheetEntry = CatalogEntry(
  feature: 'cancel_request',
  screen: 'cancel_request_sheet',
  states: [
    CatalogState(
      'Idle — free cancel note',
      (_) => _sheetHost(
        CancelRequestSheet(
          requestId: 'req-demo-1',
          repository: FakeCancelRequestRepository(),
        ),
      ),
    ),
    CatalogState(
      'Confirming (in flight)',
      (_) => _sheetHost(
        CancelRequestSheet(
          requestId: 'req-demo-1',
          repository: FakeCancelRequestRepository(),
          initialState: const CancelRequestState(
            status: CancelRequestStatus.inFlight,
          ),
        ),
      ),
    ),
    CatalogState(
      'Failed — no longer cancellable (409)',
      (_) => _sheetHost(
        CancelRequestSheet(
          requestId: 'req-demo-1',
          repository: FakeCancelRequestRepository(),
          initialState: const CancelRequestState(
            status: CancelRequestStatus.failed,
            error: CancelRequestFailure.conflict,
          ),
        ),
      ),
    ),
  ],
);

CatalogState _cancellationScreenState(CancellationScreenDesignedState state) {
  return CatalogState(
    state.label,
    (_) => CancellationScreen(
      deliveryId: state.deliveryId,
      isJeeber: state.isJeeber,
      repository: state.repository,
      initialState: state.initialState,
      initialReason: state.initialReason,
    ),
  );
}

final CatalogEntry _cancellationScreenEntry = CatalogEntry(
  feature: 'cancellation',
  screen: 'cancellation_screen',
  states: [
    _cancellationScreenState(cancellationScreenClientPickerState),
    _cancellationScreenState(cancellationScreenJeeberPickerState),
    _cancellationScreenState(cancellationScreenSelectedState),
    _cancellationScreenState(cancellationScreenSubmittingState),
    // M3-04: both failure lanes are drawn states now, so they can be captured
    // instead of being an invisible snackbar.
    _cancellationScreenState(cancellationScreenRejectedState),
    _cancellationScreenState(cancellationScreenTooLateState),
    _cancellationScreenState(cancellationScreenReasonRequiredState),
    _cancellationScreenState(cancellationScreenNotAPartyState),
  ],
);

final CatalogEntry _cancellationSuccessSheetEntry = CatalogEntry(
  feature: 'cancellation',
  screen: 'cancellation_success_sheet',
  states: [
    CatalogState(
      'Cancellation success',
      (_) => _sheetHost(
        CancellationSuccessSheet(
          result: const CancellationResult(
            deliveryId: 'delivery-demo-1',
            weeklyCount: 1,
          ),
          onDone: () {},
        ),
      ),
    ),
  ],
);

final CatalogEntry _chatScreenEntry = CatalogEntry(
  feature: 'chat',
  screen: 'chat_screen',
  states: [
    CatalogState(
      'Client — sending initial request',
      (_) => ChatScreenPreviewFixtures.clientSending(),
    ),
    CatalogState(
      'Client — broadcasting (offer cards)',
      (_) => ChatScreenPreviewFixtures.clientBroadcasting(),
    ),
    CatalogState(
      'Client — accepted 1:1 thread',
      (_) => ChatScreenPreviewFixtures.clientAccepted(),
    ),
    CatalogState(
      'Jeeber — accepted thread',
      (_) => ChatScreenPreviewFixtures.jeeberAccepted(),
    ),
    CatalogState(
      'Jeeber — order picked banner',
      (_) => ChatScreenPreviewFixtures.jeeberOrderPicked(),
    ),
    CatalogState(
      'Jeeber — confirm picking sheet',
      (_) => ChatScreenPreviewFixtures.jeeberConfirmPicking(),
    ),
    CatalogState(
      'Jeeber — confirm heading-off sheet',
      (_) => ChatScreenPreviewFixtures.jeeberConfirmHeadingOff(),
    ),
    CatalogState(
      'Failed outgoing message — tap to retry (OFF-05)',
      (_) => _chatThread(ChatScreenPreviewFixtures.failedOutgoingMessage()),
    ),
    CatalogState(
      'Image load failed — reload the attachment (F36)',
      (_) => _chatThread(ChatScreenPreviewFixtures.imageLoadFailed()),
    ),
    CatalogState(
      'Connection lost — reconnect banner',
      (_) => _chatThread(ChatScreenPreviewFixtures.connectionOffline()),
    ),
  ],
);

/// Mounts the raw thread over a fixture gateway, for the states the seven
/// Figma frames cannot reach.
Widget _chatThread(ChatGateway gateway) => ChatScreen(
  deliveryId: 'catalog-thread',
  counterpartName: ChatScreenPreviewFixtures.counterpartName,
  gateway: gateway,
);

Widget _clientOffersScreen(OffersRepository repository) => ClientOffersScreen(
  requestId: ClientOffersScreenPreviewFixtures.requestId,
  repository: repository,
  cancelRepositoryOverride:
      ClientOffersScreenPreviewFixtures.cancelRepository(),
  cubitFactory: ClientOffersScreenPreviewFixtures.inertCubit,
);

final CatalogEntry _clientOffersScreenEntry = CatalogEntry(
  feature: 'client_offers',
  screen: 'client_offers_screen',
  states: [
    CatalogState(
      'Loaded — 3 offers',
      (_) => _clientOffersScreen(
        ClientOffersScreenPreviewFixtures.freshWindow(),
      ),
    ),
    CatalogState(
      'Empty — no offers yet',
      (_) => _clientOffersScreen(ClientOffersScreenPreviewFixtures.noBidsYet()),
    ),
    CatalogState(
      'Offer window expired',
      (_) => _clientOffersScreen(
        ClientOffersScreenPreviewFixtures.elapsedWindow(),
      ),
    ),
    CatalogState(
      'Request closed',
      (_) => _clientOffersScreen(
        ClientOffersScreenPreviewFixtures.closedRequest(),
      ),
    ),
    CatalogState(
      'Error — network',
      (_) =>
          _clientOffersScreen(ClientOffersScreenPreviewFixtures.failingLoad()),
    ),
  ],
);

final Offer _sampleOffer = Offer(
  id: 'offer-demo-1',
  jeeberId: 'jeeber-demo-1',
  jeeberName: 'Karim',
  fee: 35,
  currency: 'USD',
  etaMinutes: 15,
  vehicle: JeeberVehicle.scooter,
  rating: 4.6,
  ratingCount: 52,
  submittedAt: DateTime.now(),
);

final CatalogEntry _offerAcceptSheetEntry = CatalogEntry(
  feature: 'client_offers',
  screen: 'offer_accept_sheet',
  states: [
    CatalogState(
      'Idle — confirm offer',
      (_) => _sheetHost(
        OfferAcceptSheet(
          offer: _sampleOffer,
          requestId: 'req-demo-1',
          repository: FakeOffersRepository(),
        ),
      ),
    ),
    CatalogState(
      'Submitting',
      (_) => _sheetHost(
        OfferAcceptSheet(
          offer: _sampleOffer,
          requestId: 'req-demo-1',
          repository: FakeOffersRepository(),
          initialState: const OfferAcceptState(
            status: OfferAcceptStatus.submitting,
          ),
        ),
      ),
    ),
    CatalogState(
      'Failed — Jeeber at capacity',
      (_) => _sheetHost(
        OfferAcceptSheet(
          offer: _sampleOffer,
          requestId: 'req-demo-1',
          repository: FakeOffersRepository(),
          initialState: const OfferAcceptState(
            status: OfferAcceptStatus.failed,
            error: OffersFailure.jeeberAtCapacity,
          ),
        ),
      ),
    ),
    CatalogState(
      'Conflict — request expired (AE-07)',
      (_) => _sheetHost(
        OfferAcceptSheet(
          offer: _sampleOffer,
          requestId: 'req-demo-1',
          repository:
              ClientOffersScreenPreviewFixtures.requestExpiredAcceptRepository(),
          initialState: const OfferAcceptState(
            status: OfferAcceptStatus.failed,
            error: OffersFailure.requestExpired,
          ),
        ),
      ),
    ),
    CatalogState(
      'Conflict — jeeber wallet short (AE-08)',
      (_) => _sheetHost(
        OfferAcceptSheet(
          offer: _sampleOffer,
          requestId: 'req-demo-1',
          repository:
              ClientOffersScreenPreviewFixtures.walletShortAcceptRepository(),
          initialState: const OfferAcceptState(
            status: OfferAcceptStatus.failed,
            error: OffersFailure.jeeberWalletShort,
          ),
        ),
      ),
    ),
  ],
);

// Static screen — no network, buttons are inert.
final CatalogEntry _clientUnreachableScreenEntry = CatalogEntry(
  feature: 'client_unreachable',
  screen: 'client_unreachable_screen',
  states: [
    CatalogState(
      ClientUnreachableScreenFixtures.catalogDefault.label,
      (_) => ClientUnreachableScreenPreviewHost(
        fixture: ClientUnreachableScreenFixtures.catalogDefault,
        screen: ClientUnreachableScreen(
          deliveryId: ClientUnreachableScreenFixtures.catalogDefault.deliveryId,
        ),
      ),
    ),
  ],
);

final CatalogEntry _customerProfileScreenEntry = CatalogEntry(
  feature: 'customer_profile',
  screen: 'customer_profile_screen',
  states: [
    CatalogState(
      'Client — verified, rated',
      (_) => const CustomerProfileScreen(
        data: CustomerProfileScreenPreviewFixtures.ratedClient,
        repository: CustomerProfileScreenStaticRepository(
          CustomerProfileScreenPreviewFixtures.ratedClient,
        ),
        reviewLauncher: CustomerProfileScreenInertReviewLauncher(),
      ),
    ),
    CatalogState(
      'Jeeber — no ratings yet',
      (_) => const CustomerProfileScreen(
        data: CustomerProfileScreenPreviewFixtures.jeeber,
        repository: CustomerProfileScreenStaticRepository(
          CustomerProfileScreenPreviewFixtures.jeeber,
        ),
        reviewLauncher: CustomerProfileScreenInertReviewLauncher(),
      ),
    ),
    CatalogState(
      'Rating unavailable — review-service outage (UX-33)',
      (_) => const CustomerProfileScreen(
        data: CustomerProfileScreenPreviewFixtures.ratedClient,
        repository: CustomerProfileScreenReviewOutageRepository(
          CustomerProfileScreenPreviewFixtures.ratedClient,
        ),
        reviewLauncher: CustomerProfileScreenInertReviewLauncher(),
      ),
    ),
    CatalogState(
      'Refresh failed over a seeded profile (UX-42)',
      (_) => catalogProfileRefresh(CustomerProfileScreen(
        data: CustomerProfileScreenPreviewFixtures.ratedClient,
        repository: CustomerProfileScreenRefreshFailingRepository(
          CustomerProfileScreenPreviewFixtures.ratedClient,
        ),
        reviewLauncher: const CustomerProfileScreenInertReviewLauncher(),
      )),
    ),
    CatalogState(
      'Cold blank read failed (UX-42)',
      (_) => const CustomerProfileScreen(
        data: CustomerProfileViewData(),
        repository: CustomerProfileScreenFailingRepository(
          CustomerProfileFailure.network,
          NetworkFailure(offline: true),
        ),
        reviewLauncher: CustomerProfileScreenInertReviewLauncher(),
      ),
    ),
    CatalogState(
      'Rate-app unavailable (RATE-01)',
      (_) => catalogProfileRateApp(const CustomerProfileScreen(
        data: CustomerProfileScreenPreviewFixtures.ratedClient,
        repository: CustomerProfileScreenStaticRepository(
          CustomerProfileScreenPreviewFixtures.ratedClient,
        ),
        reviewLauncher: CustomerProfileScreenUnavailableReviewLauncher(),
      )),
    ),
  ],
);

/// The release fallback both `/profile/*` routes build when no typed `extra`
/// arrives. It had no catalog state, so its treatment was never captured.
final CatalogEntry _profileUnavailableScreenEntry = CatalogEntry(
  feature: 'core_router',
  screen: 'ProfileUnavailableScreen',
  states: [
    CatalogState('Unavailable', (_) => const ProfileUnavailableScreen()),
  ],
);

/// The dev-only diagnostics export (M3-38). It had no catalog state at all, so
/// none of its four frames was capturable.
final CatalogEntry _diagnosticsScreenEntry = CatalogEntry(
  feature: 'core',
  screen: 'DiagnosticsScreen',
  states: [
    CatalogState(
      'Sessions — newest first',
      (_) => _diagnostics(DiagnosticsScreenPreviewFixtures.listing),
    ),
    CatalogState(
      'Empty — no session files',
      (_) => _diagnostics(DiagnosticsScreenPreviewFixtures.empty),
    ),
    CatalogState(
      'Loading — listing files',
      (_) => _diagnostics(DiagnosticsScreenPreviewFixtures.stalled),
    ),
    CatalogState(
      'Error — listing failed',
      (_) => _diagnostics(DiagnosticsScreenPreviewFixtures.failing),
    ),
    CatalogState(
      'Release-like build — diag disabled',
      (_) => _diagnostics(
        DiagnosticsScreenPreviewFixtures.listing,
        enabled: false,
      ),
    ),
  ],
);

/// Drives the `Diag.enabled` build gate and keeps every side-effecting seam
/// (share sheet, clipboard) inert.
Widget _diagnostics(
  Future<List<DiagSessionFileInfo>> Function() loader, {
  bool enabled = true,
}) {
  return DiagnosticsScreenEnabledScope(
    enabled: enabled,
    child: DiagnosticsScreen(
      sessionsLoader: loader,
      shareLauncher: DiagnosticsScreenPreviewFixtures.inertShare,
      clipboardWriter: DiagnosticsScreenPreviewFixtures.inertClipboard,
    ),
  );
}
