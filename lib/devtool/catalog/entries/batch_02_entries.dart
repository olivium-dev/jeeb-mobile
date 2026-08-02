import 'package:flutter/material.dart';

import '../../../features/cancel_request/application/cancel_request_state.dart';
import '../../../features/cancel_request/data/fake_cancel_request_repository.dart';
import '../../../features/cancel_request/domain/cancel_request_repository.dart';
import '../../../features/cancel_request/presentation/cancel_request_sheet.dart';
import '../../../features/cancellation/domain/cancellation_result.dart';
import '../../../features/cancellation/presentation/cancellation_screen.dart';
import '../../../features/cancellation/presentation/widgets/cancellation_success_sheet.dart';
import '../../../features/client_offers/application/offer_accept_state.dart';
import '../../../features/client_offers/data/fake_offers_repository.dart';
import '../../../features/client_offers/domain/jeeber_vehicle.dart';
import '../../../features/client_offers/domain/offer.dart';
import '../../../features/client_offers/domain/offers_repository.dart';
import '../../../features/client_offers/presentation/client_offers_screen.dart';
import '../../../features/client_offers/presentation/widgets/offer_accept_sheet.dart';
import '../../../features/client_unreachable/presentation/client_unreachable_screen.dart';
import '../../../features/customer_profile/presentation/customer_profile_screen.dart';
import '../catalog_models.dart';
import '../fixtures/cancellation_screen_fixtures.dart';
import '../fixtures/chat_screen_fixtures.dart';
import '../fixtures/client_offers_screen_fixtures.dart';
import '../fixtures/client_unreachable_screen_fixtures.dart';
import '../fixtures/customer_profile_screen_fixtures.dart';

/// Batch 02 — cancel_request, cancellation, chat, client_offers,
/// client_unreachable, customer_profile (DT-04 screen-catalog rework).
///
/// Every builder renders the REAL screen/sheet with an explicit LOCAL fake
/// repository/gateway — never the DI-resolved production one, since the Dev
/// Tool shares the app's real GetIt graph (`Bootstrap.minimal`, see
/// `devtool_shell.dart`) and would otherwise hit the live gateway.
List<CatalogEntry> get batch02Entries => <CatalogEntry>[
  _cancelRequestSheetEntry,
  _cancellationScreenEntry,
  _cancellationSuccessSheetEntry,
  _chatScreenEntry,
  _clientOffersScreenEntry,
  _offerAcceptSheetEntry,
  _clientUnreachableScreenEntry,
  _customerProfileScreenEntry,
];

/// Bottom-sheet previews (`CancelRequestSheet` / `OfferAcceptSheet` /
/// `CancellationSuccessSheet`) are not routes — they render a bare column, not
/// a `Scaffold`. Wrapping in a surface-colored `Scaffold` with the sheet
/// pinned to the bottom mirrors how `showModalBottomSheet` actually presents
/// them, without depending on a `Navigator`/`showModalBottomSheet` call (the
/// catalog previews a plain widget, not a modal route).
Widget _sheetHost(Widget sheet) {
  return Builder(
    builder: (context) => Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Align(alignment: Alignment.bottomCenter, child: sheet),
    ),
  );
}

// ─────────────────────────── cancel_request ────────────────────────────

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

// ──────────────────────────── cancellation ─────────────────────────────

/// One catalog card per shared designed state.
///
/// The three states below — their labels, their fakes and their seeded cubit
/// state — are named once in [CancellationScreenDesignedState] constants and
/// shared verbatim with the JEEB PREVIEWS section at the bottom of
/// `features/cancellation/presentation/cancellation_screen.dart`, so the
/// designer's in-app browser and the engineer's preview canvas cannot drift
/// into showing two different "designed states" of the same screen. The
/// private `_CatalogCancellationRepository` this entry used to own now lives
/// there as [CancellationScreenFakeRepository] — same behaviour: never resolves
/// onto the live gateway, and returns a plausible result if a reviewer actually
/// taps Confirm, instead of throwing.
CatalogState _cancellationScreenState(CancellationScreenDesignedState state) {
  return CatalogState(
    state.label,
    (_) => CancellationScreen(
      deliveryId: state.deliveryId,
      isJeeber: state.isJeeber,
      repository: state.repository,
      initialState: state.initialState,
    ),
  );
}

final CatalogEntry _cancellationScreenEntry = CatalogEntry(
  feature: 'cancellation',
  screen: 'cancellation_screen',
  states: [
    _cancellationScreenState(cancellationScreenClientPickerState),
    _cancellationScreenState(cancellationScreenJeeberPickerState),
    _cancellationScreenState(cancellationScreenSubmittingState),
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

// ──────────────────────────────── chat ─────────────────────────────────

/// Reuses the shipped `DevChatPreviewScreen` — the app's own debug-only host
/// that renders the real `ChatScreen` against `DevChatFixtureGateway` (a
/// deterministic in-memory gateway, no network) for exactly these designed
/// states (see its doc comment for the Figma node each selector matches).
///
/// The selectors are no longer spelled out here: each state is named once in
/// [ChatScreenPreviewFixtures] and shared verbatim with the JEEB PREVIEWS
/// section at the bottom of `features/chat/presentation/chat_screen.dart`, so
/// the designer's in-app browser and the preview canvas cannot drift into
/// showing two different "designed states" of the same screen.
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
  ],
);

// ────────────────────────────── client_offers ──────────────────────────

/// The five designed states below are named once in
/// [ClientOffersScreenPreviewFixtures] and shared verbatim with the JEEB
/// PREVIEWS section at the bottom of
/// `features/client_offers/presentation/client_offers_screen.dart`, so the
/// designer's in-app browser and the preview canvas cannot drift into showing
/// two different "designed states" of the same screen. The fakes, the frozen
/// clock and the inert cubit factory all live there; this entry only says which
/// state goes under which label.
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
  ],
);

// ───────────────────────────── client_unreachable ──────────────────────

/// Static screen — no `*_state.dart`, no repository/cubit, no network. Its
/// three buttons are inert stubs (`onTap: () {}`) or a local `Navigator.pop`
/// in the shipped source itself, so there is nothing to fake.
///
/// The id and the framing come from
/// `../fixtures/client_unreachable_screen_fixtures.dart`, which the JEEB
/// PREVIEWS section at the bottom of `client_unreachable_screen.dart` also
/// reads — so this state and the canvas cannot drift onto different ids.
/// `catalogDefault` carries `window: null` and `parentOnStack: null`, i.e. the
/// host renders the screen bare on the real device under the catalog's own
/// route, exactly as this entry did before the extraction.
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

// ───────────────────────────── customer_profile ────────────────────────

/// The people, the scripted repository and the inert store-review launcher live
/// in `../fixtures/customer_profile_screen_fixtures.dart`, shared verbatim with
/// the preview section at the bottom of `customer_profile_screen.dart` so the
/// designer's browser and the engineer's canvas cannot drift into showing two
/// different "Kamal Hajj". Both states below are the same two this entry has
/// always had.
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
  ],
);
