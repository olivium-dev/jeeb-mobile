import 'dart:async';

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
import '../../../features/client_offers/application/client_offers_cubit.dart';
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


class _CatalogCancellationRepository implements CancellationRepository {
  const _CatalogCancellationRepository();

  @override
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) async {
    return CancellationResult(deliveryId: deliveryId, weeklyCount: 1);
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

ClientOffersCubit _catalogOffersCubit(
  OffersRepository repository,
  String requestId,
) {
  return ClientOffersCubit(
    repository: repository,
    requestId: requestId,
    refreshSignals: const Stream<void>.empty(),
    clockTicks: const Stream<void>.empty(),
  );
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
        cancelRepositoryOverride: FakeCancelRequestRepository(),
        cubitFactory: _catalogOffersCubit,
      ),
    ),
    CatalogState(
      'Empty — no offers yet',
      (_) => ClientOffersScreen(
        requestId: 'req-demo-1',
        repository: FakeOffersRepository(seed: const []),
        cancelRepositoryOverride: FakeCancelRequestRepository(),
        cubitFactory: _catalogOffersCubit,
      ),
    ),
    CatalogState(
      'Offer window expired',
      (_) => ClientOffersScreen(
        requestId: 'req-demo-1',
        repository: FakeOffersRepository(
          windowExpiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        cancelRepositoryOverride: FakeCancelRequestRepository(),
        cubitFactory: _catalogOffersCubit,
      ),
    ),
    CatalogState(
      'Request closed',
      (_) => ClientOffersScreen(
        requestId: 'req-demo-1',
        repository: FakeOffersRepository()..closeRequest(),
        cancelRepositoryOverride: FakeCancelRequestRepository(),
        cubitFactory: _catalogOffersCubit,
      ),
    ),
    CatalogState(
      'Error — network',
      (_) => ClientOffersScreen(
        requestId: 'req-demo-1',
        repository: const _FailingOffersRepository(),
        cancelRepositoryOverride: FakeCancelRequestRepository(),
        cubitFactory: _catalogOffersCubit,
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
