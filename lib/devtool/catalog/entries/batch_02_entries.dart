import 'package:flutter/material.dart';

import '../../../features/cancel_request/application/cancel_request_state.dart';
import '../../../features/cancel_request/data/fake_cancel_request_repository.dart';
import '../../../features/cancel_request/domain/cancel_request_repository.dart';
import '../../../features/cancel_request/presentation/cancel_request_sheet.dart';
import '../../../features/cancellation/domain/cancellation_repository.dart';
import '../../../features/cancellation/domain/cancellation_result.dart';
import '../../../features/cancellation/presentation/cancellation_screen.dart';
import '../../../features/cancellation/presentation/cubit/cancellation_state.dart';
import '../../../features/cancellation/presentation/widgets/cancellation_success_sheet.dart';
import '../../../features/chat/presentation/dev_chat_preview_screen.dart';
import '../../../features/client_offers/application/offer_accept_state.dart';
import '../../../features/client_offers/data/fake_offers_repository.dart';
import '../../../features/client_offers/domain/jeeber_vehicle.dart';
import '../../../features/client_offers/domain/offer.dart';
import '../../../features/client_offers/domain/offers_repository.dart';
import '../../../features/client_offers/presentation/client_offers_screen.dart';
import '../../../features/client_offers/presentation/widgets/offer_accept_sheet.dart';
import '../../../features/client_unreachable/presentation/client_unreachable_screen.dart';
import '../../../features/customer_profile/data/dev_customer_profile_fixtures.dart';
import '../../../features/customer_profile/domain/customer_profile_repository.dart';
import '../../../features/customer_profile/domain/customer_profile_view_data.dart';
import '../../../features/customer_profile/presentation/customer_profile_screen.dart';
import '../catalog_models.dart';

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
          initialState:
              const CancelRequestState(status: CancelRequestStatus.inFlight),
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

/// Never resolves onto the live gateway (constructor test/catalog seam —
/// same shape as `FakeCancelRequestRepository`). Returns a plausible result if
/// a reviewer actually taps Confirm in the interactive preview, instead of
/// throwing, so poking at the live screen doesn't crash the catalog.
class _CatalogCancellationRepository implements CancellationRepository {
  const _CatalogCancellationRepository();

  @override
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) async {
    return CancellationResult(
      deliveryId: deliveryId,
      feeApplied: reason == 'wait_too_long' ? 5.0 : 0.0,
      weeklyCount: 1,
    );
  }
}

final CatalogEntry _cancellationScreenEntry = CatalogEntry(
  feature: 'cancellation',
  screen: 'cancellation_screen',
  states: [
    CatalogState(
      'Client — reason picker',
      (_) => const CancellationScreen(
        deliveryId: 'delivery-demo-1',
        isJeeber: false,
        repository: _CatalogCancellationRepository(),
      ),
    ),
    CatalogState(
      'Jeeber — reason picker',
      (_) => const CancellationScreen(
        deliveryId: 'delivery-demo-1',
        isJeeber: true,
        repository: _CatalogCancellationRepository(),
      ),
    ),
    CatalogState(
      'Submitting',
      (_) => const CancellationScreen(
        deliveryId: 'delivery-demo-1',
        isJeeber: false,
        repository: _CatalogCancellationRepository(),
        initialState: CancellationLoading(),
      ),
    ),
  ],
);

final CatalogEntry _cancellationSuccessSheetEntry = CatalogEntry(
  feature: 'cancellation',
  screen: 'cancellation_success_sheet',
  states: [
    CatalogState(
      'Fee applied — wallet CTA',
      (_) => _sheetHost(
        CancellationSuccessSheet(
          result: const CancellationResult(
            deliveryId: 'delivery-demo-1',
            feeApplied: 5.0,
            weeklyCount: 2,
          ),
          onWalletTap: () {},
          onDone: () {},
        ),
      ),
    ),
    CatalogState(
      'No fee — done only',
      (_) => _sheetHost(
        CancellationSuccessSheet(
          result: const CancellationResult(
            deliveryId: 'delivery-demo-1',
            feeApplied: 0,
            weeklyCount: 1,
          ),
          onWalletTap: () {},
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
final CatalogEntry _chatScreenEntry = CatalogEntry(
  feature: 'chat',
  screen: 'chat_screen',
  states: [
    CatalogState(
      'Client — sending initial request',
      (_) => const DevChatPreviewScreen(selector: 'sending'),
    ),
    CatalogState(
      'Client — broadcasting (offer cards)',
      (_) => const DevChatPreviewScreen(selector: 'broadcasting'),
    ),
    CatalogState(
      'Client — accepted 1:1 thread',
      (_) => const DevChatPreviewScreen(selector: 'accepted'),
    ),
    CatalogState(
      'Jeeber — accepted thread',
      (_) => const DevChatPreviewScreen(selector: 'dm'),
    ),
    CatalogState(
      'Jeeber — order picked banner',
      (_) => const DevChatPreviewScreen(selector: 'dm-order-picked'),
    ),
    CatalogState(
      'Jeeber — confirm picking sheet',
      (_) => const DevChatPreviewScreen(selector: 'dm-confirm-picking'),
    ),
    CatalogState(
      'Jeeber — confirm heading-off sheet',
      (_) => const DevChatPreviewScreen(selector: 'dm-confirm-heading-off'),
    ),
  ],
);

// ────────────────────────────── client_offers ──────────────────────────

/// Always fails (network) — demonstrates the offer-review-list `failed`
/// status without depending on the live gateway.
class _FailingOffersRepository implements OffersRepository {
  const _FailingOffersRepository();

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async {
    throw const OffersRepositoryException(OffersFailure.network);
  }

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    throw const OffersRepositoryException(OffersFailure.network);
  }
}

final CatalogEntry _clientOffersScreenEntry = CatalogEntry(
  feature: 'client_offers',
  screen: 'client_offers_screen',
  states: [
    CatalogState(
      'Loaded — 3 offers',
      (_) => ClientOffersScreen(
        requestId: 'req-demo-1',
        repository: FakeOffersRepository(),
      ),
    ),
    CatalogState(
      'Empty — no offers yet',
      (_) => ClientOffersScreen(
        requestId: 'req-demo-1',
        repository: FakeOffersRepository(seed: const []),
      ),
    ),
    CatalogState(
      'Offer window expired',
      (_) => ClientOffersScreen(
        requestId: 'req-demo-1',
        repository: FakeOffersRepository(
          windowExpiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      ),
    ),
    CatalogState(
      'Request closed',
      (_) => ClientOffersScreen(
        requestId: 'req-demo-1',
        repository: FakeOffersRepository()..closeRequest(),
      ),
    ),
    CatalogState(
      'Error — network',
      (_) => const ClientOffersScreen(
        requestId: 'req-demo-1',
        repository: _FailingOffersRepository(),
      ),
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
          initialState:
              const OfferAcceptState(status: OfferAcceptStatus.submitting),
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
final CatalogEntry _clientUnreachableScreenEntry = CatalogEntry(
  feature: 'client_unreachable',
  screen: 'client_unreachable_screen',
  states: [
    CatalogState(
      'Default',
      (_) => const ClientUnreachableScreen(deliveryId: 'delivery-demo-1'),
    ),
  ],
);

// ───────────────────────────── customer_profile ────────────────────────

/// Constructor test/catalog seam — returns the seeded read model unchanged so
/// the cubit's `load()` refresh is a same-data no-op instead of a live
/// `GET /user-management/users/me` call.
class _CatalogCustomerProfileRepository implements CustomerProfileRepository {
  const _CatalogCustomerProfileRepository(this._data);

  final CustomerProfileViewData _data;

  @override
  Future<CustomerProfileViewData> fetchProfile() async => _data;
}

const CustomerProfileViewData _jeeberProfileData = CustomerProfileViewData(
  name: 'Kamal Hajj',
  email: 'kamal.hajj@jeeb.dev',
  isVerified: false,
  isJeeber: true,
  availableRoles: ['client', 'jeeber'],
);

final CatalogEntry _customerProfileScreenEntry = CatalogEntry(
  feature: 'customer_profile',
  screen: 'customer_profile_screen',
  states: [
    CatalogState(
      'Client — verified, rated',
      (_) => const CustomerProfileScreen(
        data: DevCustomerProfileFixtures.sample,
        repository: _CatalogCustomerProfileRepository(
          DevCustomerProfileFixtures.sample,
        ),
      ),
    ),
    CatalogState(
      'Jeeber — no ratings yet',
      (_) => const CustomerProfileScreen(
        data: _jeeberProfileData,
        repository: _CatalogCustomerProfileRepository(_jeeberProfileData),
      ),
    ),
  ],
);
