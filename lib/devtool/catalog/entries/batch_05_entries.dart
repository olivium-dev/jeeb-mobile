import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../features/jeeber_home/domain/entities/feed_request.dart';
import '../../../features/jeeber_onboarding_funding/presentation/onboarding_funding_screen.dart';
import '../../../features/jeeber_pending_offers/presentation/jeeber_pending_offers_screen.dart';
import '../../../features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import '../../../features/jeeber_request_detail/presentation/jeeber_request_detail_loader.dart';
import '../../../features/jeeber_request_detail/presentation/jeeber_request_detail_screen.dart';
import '../../../features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart';
import '../../../features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import '../../../features/jeeber_request_feed/data/dev_jeeber_feed_fixtures.dart';
import '../../../features/jeeber_request_feed/data/request_feed_models.dart';
import '../../../features/jeeber_request_feed/data/request_feed_repository.dart';
import '../../../features/jeeber_request_feed/domain/submitted_offer.dart';
import '../../../features/jeeber_request_feed/domain/submitted_offers_repository.dart';
import '../../../features/jeeber_request_feed/presentation/request_feed_screen.dart';
import '../../../features/kyc/application/kyc_wizard_cubit.dart';
import '../../../features/kyc/domain/kyc_gateway.dart';
import '../../../features/kyc/domain/kyc_submission.dart';
import '../../../features/kyc/presentation/kyc_wizard_screen.dart';
import '../../../features/kyc_rejected/presentation/kyc_rejected_screen.dart';
import '../../../features/photo_attachment/data/stub_photo_picker_service.dart';
import '../../../features/wallet/domain/wallet_repository.dart';
import '../catalog_models.dart';

List<CatalogEntry> get batch05Entries => <CatalogEntry>[
      _onboardingFundingEntry,
      _pendingOffersEntry,
      _requestDetailEntry,
      _requestUnavailableEntry,
      _requestDetailLoaderEntry,
      _requestFeedEntry,
      _kycWizardEntry,
      _kycRejectedEntry,
    ];


final CatalogEntry _onboardingFundingEntry = CatalogEntry(
  feature: 'jeeber_onboarding_funding',
  screen: 'OnboardingFundingScreen',
  states: [
    CatalogState(
      'Enriched — starter credit + reserve amounts loaded',
      (_) => const OnboardingFundingScreen(
        repository: _StaticWalletRepository(
          WalletBalance(
            availableBalance: 150,
            affordabilityState: WalletAffordability.enough,
            reservedNow: 20,
            giftCredit: 50,
            currency: 'USD',
          ),
        ),
      ),
    ),
    CatalogState(
      'Fail-safe — wallet fetch failed, static explainer only',
      (_) => const OnboardingFundingScreen(
        repository: _FailingWalletRepository(),
      ),
    ),
  ],
);

class _StaticWalletRepository implements WalletRepository {
  const _StaticWalletRepository(this._balance);

  final WalletBalance _balance;

  @override
  Future<WalletBalance> fetchBalance() async => _balance;
}

class _FailingWalletRepository implements WalletRepository {
  const _FailingWalletRepository();

  @override
  Future<WalletBalance> fetchBalance() async {
    throw const WalletRepositoryException(WalletFailure.network);
  }
}


final CatalogEntry _pendingOffersEntry = CatalogEntry(
  feature: 'jeeber_pending_offers',
  screen: 'JeeberPendingOffersScreen',
  states: [
    CatalogState(
      'Awaiting customer decision',
      (_) => const JeeberPendingOffersScreen(
        jeeberId: 'user-jeeber-002',
        repository: _StaticSubmittedOffersRepository([
          SubmittedOffer(
            id: 'offer-1',
            requestId: 'req-101',
            price: 12.5,
            currency: 'USD',
            etaMinutes: 25,
            note: 'Can drop off at the lobby',
          ),
          SubmittedOffer(
            id: 'offer-2',
            requestId: 'req-102',
            price: 8,
            currency: 'USD',
          ),
        ]),
      ),
    ),
    CatalogState(
      'Mixed outcomes — accepted / not selected badges',
      (_) => const JeeberPendingOffersScreen(
        jeeberId: 'user-jeeber-002',
        repository: _StaticSubmittedOffersRepository([
          SubmittedOffer(
            id: 'offer-3',
            requestId: 'req-103',
            price: 15,
            currency: 'USD',
            etaMinutes: 18,
            status: OfferStatus.accepted,
          ),
          SubmittedOffer(
            id: 'offer-4',
            requestId: 'req-104',
            price: 9.75,
            currency: 'USD',
            etaMinutes: 40,
            status: OfferStatus.lost,
          ),
          SubmittedOffer(
            id: 'offer-5',
            requestId: 'req-105',
            price: 11,
            currency: 'USD',
          ),
        ]),
      ),
    ),
    CatalogState(
      'Empty — nothing submitted yet',
      (_) => const JeeberPendingOffersScreen(
        jeeberId: 'user-jeeber-002',
        repository: _StaticSubmittedOffersRepository([]),
      ),
    ),
    CatalogState(
      'Error — load failed',
      (_) => const JeeberPendingOffersScreen(
        jeeberId: 'user-jeeber-002',
        repository: _StaticSubmittedOffersRepository(
          [],
          throwOnList: true,
        ),
      ),
    ),
  ],
);

class _StaticSubmittedOffersRepository implements SubmittedOffersRepository {
  const _StaticSubmittedOffersRepository(
    this._offers, {
    this.throwOnList = false,
  });

  final List<SubmittedOffer> _offers;
  final bool throwOnList;

  @override
  Future<List<SubmittedOffer>> listSubmitted() async {
    if (throwOnList) {
      throw Exception('catalog: designed error state');
    }
    return _offers;
  }

  @override
  Future<bool> withdraw(String offerId) async => true;
}


const ProhibitedItemReportService _reportService =
    ProhibitedItemReportService();

final CatalogEntry _requestDetailEntry = CatalogEntry(
  feature: 'jeeber_request_detail',
  screen: 'JeeberRequestDetailScreen',
  states: [
    CatalogState(
      'With request description (G1)',
      (_) => JeeberRequestDetailScreen(
        request: const FeedRequest(
          id: 'req-101',
          shortLabel: 'Hamra, Beirut',
          description: '1 kilo potato, water gallon, coffee blend',
        ),
        reportService: _reportService,
        onDeclined: (_) {},
      ),
    ),
    CatalogState(
      'Without description (legacy/edge payload)',
      (_) => JeeberRequestDetailScreen(
        request: const FeedRequest(
          id: 'req-102',
          shortLabel: 'Achrafieh, Beirut',
        ),
        reportService: _reportService,
        onDeclined: (_) {},
      ),
    ),
  ],
);

final CatalogEntry _requestUnavailableEntry = CatalogEntry(
  feature: 'jeeber_request_detail',
  screen: 'JeeberRequestUnavailableScreen',
  states: [
    CatalogState(
      'Request no longer available',
      (_) => JeeberRequestUnavailableScreen(
        requestId: 'req-404',
        onBack: () {},
      ),
    ),
  ],
);

final CatalogEntry _requestDetailLoaderEntry = CatalogEntry(
  feature: 'jeeber_request_detail',
  screen: 'JeeberRequestDetailLoader',
  states: [
    CatalogState(
      'Loading — recovering a push-tap by id',
      (_) => JeeberRequestDetailLoader(
        requestId: 'req-303',
        initial: null,
        fetch: () => Completer<FeedRequest?>().future,
        reportService: _reportService,
        onDeclined: (_) {},
        onBack: () {},
      ),
    ),
    CatalogState(
      'Resolved — push-tap request recovered by id',
      (_) => JeeberRequestDetailLoader(
        requestId: 'req-777',
        initial: null,
        fetch: () async => const FeedRequest(
          id: 'req-777',
          shortLabel: 'Hamra, Beirut',
          description: '2 kg rice, cooking oil',
        ),
        reportService: _reportService,
        onDeclined: (_) {},
        onBack: () {},
      ),
    ),
    CatalogState(
      'Unavailable — feed miss, no active delivery either',
      (_) => JeeberRequestDetailLoader(
        requestId: 'req-404',
        initial: null,
        fetch: () async => null,
        fetchAcceptedDeliveryId: () async => null,
        reportService: _reportService,
        onDeclined: (_) {},
        onBack: () {},
      ),
    ),
  ],
);


final CatalogEntry _requestFeedEntry = CatalogEntry(
  feature: 'jeeber_request_feed',
  screen: 'RequestFeedScreen',
  states: [
    CatalogState(
      'Incoming — Ignore / Offer card',
      (_) => _RequestFeedPreview(
        repositoryBuilder: () =>
            SeededRequestFeedRepository(DevJeeberFeedFixtures.incoming()),
      ),
    ),
    CatalogState(
      'Pending response — awaiting client reply',
      (_) => _RequestFeedPreview(
        repositoryBuilder: () =>
            SeededRequestFeedRepository(DevJeeberFeedFixtures.pending()),
      ),
    ),
    CatalogState(
      'Accepted — delivery-action cards',
      (_) => _RequestFeedPreview(
        repositoryBuilder: () =>
            SeededRequestFeedRepository(DevJeeberFeedFixtures.replies()),
      ),
    ),
    CatalogState(
      'Empty — no requests right now',
      (_) => _RequestFeedPreview(
        repositoryBuilder: () => const _EmptyRequestFeedRepository(),
      ),
    ),
    CatalogState(
      'Error — load failed',
      (_) => _RequestFeedPreview(
        repositoryBuilder: () => const _ErrorRequestFeedRepository(),
      ),
    ),
    CatalogState(
      'Reconnecting — degraded polling transport',
      (_) => _RequestFeedPreview(
        repositoryBuilder: () =>
            _PollingRequestFeedRepository(DevJeeberFeedFixtures.incoming()),
      ),
    ),
  ],
);

class _RequestFeedPreview extends StatefulWidget {
  const _RequestFeedPreview({required this.repositoryBuilder});

  final RequestFeedRepository Function() repositoryBuilder;

  @override
  State<_RequestFeedPreview> createState() => _RequestFeedPreviewState();
}

class _RequestFeedPreviewState extends State<_RequestFeedPreview> {
  late final RequestFeedCubit _cubit =
      RequestFeedCubit(repository: widget.repositoryBuilder())..start();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RequestFeedScreen(cubit: _cubit);
}

class _EmptyRequestFeedRepository implements RequestFeedRepository {
  const _EmptyRequestFeedRepository();

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<FeedTransportUpdate> get transport async* {
    yield const FeedTransportUpdate(FeedTransport.webSocket);
  }

  @override
  Future<List<DeliveryRequest>> refresh() async => const <DeliveryRequest>[];

  @override
  Future<RequestActionOutcome> accept(String id) async =>
      RequestActionOutcome.accepted;

  @override
  Future<RequestActionOutcome> decline(String id) async =>
      RequestActionOutcome.declined;

  @override
  Future<void> dispose() async {}
}

class _ErrorRequestFeedRepository implements RequestFeedRepository {
  const _ErrorRequestFeedRepository();

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<FeedTransportUpdate> get transport async* {
    yield const FeedTransportUpdate(FeedTransport.webSocket);
  }

  @override
  Future<List<DeliveryRequest>> refresh() async {
    throw Exception('catalog: designed error state');
  }

  @override
  Future<RequestActionOutcome> accept(String id) async =>
      RequestActionOutcome.networkError;

  @override
  Future<RequestActionOutcome> decline(String id) async =>
      RequestActionOutcome.networkError;

  @override
  Future<void> dispose() async {}
}

class _PollingRequestFeedRepository implements RequestFeedRepository {
  _PollingRequestFeedRepository(this._snapshot);

  final List<DeliveryRequest> _snapshot;

  @override
  Stream<DeliveryRequest> get requests => const Stream<DeliveryRequest>.empty();

  @override
  Stream<FeedTransportUpdate> get transport async* {
    yield const FeedTransportUpdate(FeedTransport.polling);
  }

  @override
  Future<List<DeliveryRequest>> refresh() async =>
      List<DeliveryRequest>.unmodifiable(_snapshot);

  @override
  Future<RequestActionOutcome> accept(String id) async =>
      RequestActionOutcome.accepted;

  @override
  Future<RequestActionOutcome> decline(String id) async =>
      RequestActionOutcome.declined;

  @override
  Future<void> dispose() async {}
}


KycWizardCubit _kycWizardCubit({
  KycStatus status = KycStatus.notSubmitted,
  KycRejectionReason? rejectionReason,
}) {
  final cubit = KycWizardCubit(
    pickerService: StubPhotoPickerService(),
    gateway: FakeKycGateway(
      initial: KycSubmission(status: status, rejectionReason: rejectionReason),
    ),
  );
  cubit.loadStatus();
  return cubit;
}

Future<void> _seedKycIdentityReady(KycWizardCubit cubit) async {
  await cubit.captureIdFront();
  await cubit.captureIdBack();
  await cubit.captureSelfie();
  cubit.setTosAccepted(true);
}

final CatalogEntry _kycWizardEntry = CatalogEntry(
  feature: 'kyc',
  screen: 'KycWizardScreen',
  states: [
    CatalogState(
      'Identity — fresh start, nothing captured',
      (_) => KycWizardScreen(cubit: _kycWizardCubit()),
    ),
    CatalogState(
      'Identity — ready to submit (captures + ToS done)',
      (_) {
        final cubit = _kycWizardCubit();
        unawaited(_seedKycIdentityReady(cubit));
        return KycWizardScreen(cubit: cubit);
      },
    ),
    CatalogState(
      'Status — pending review',
      (_) => KycWizardScreen(
        cubit: _kycWizardCubit(status: KycStatus.pending),
      ),
    ),
    CatalogState(
      'Status — approved',
      (_) => KycWizardScreen(
        cubit: _kycWizardCubit(status: KycStatus.approved),
      ),
    ),
    CatalogState(
      'Status — rejected',
      (_) => KycWizardScreen(
        cubit: _kycWizardCubit(
          status: KycStatus.rejected,
          rejectionReason: KycRejectionReason.idUnreadable,
        ),
      ),
    ),
  ],
);


final CatalogEntry _kycRejectedEntry = CatalogEntry(
  feature: 'kyc_rejected',
  screen: 'KycRejectedScreen',
  states: [
    CatalogState(
      'Reason — ID unreadable',
      (_) => KycRejectedScreen(
        gateway: FakeKycGateway(
          initial: const KycSubmission(
            status: KycStatus.rejected,
            rejectionReason: KycRejectionReason.idUnreadable,
          ),
        ),
      ),
    ),
    CatalogState(
      'Reason — selfie mismatch',
      (_) => KycRejectedScreen(
        gateway: FakeKycGateway(
          initial: const KycSubmission(
            status: KycStatus.rejected,
            rejectionReason: KycRejectionReason.selfieMismatch,
          ),
        ),
      ),
    ),
    CatalogState(
      'Reason — document expired',
      (_) => KycRejectedScreen(
        gateway: FakeKycGateway(
          initial: const KycSubmission(
            status: KycStatus.rejected,
            rejectionReason: KycRejectionReason.expired,
          ),
        ),
      ),
    ),
    CatalogState(
      'Reason — other/generic',
      (_) => KycRejectedScreen(
        gateway: FakeKycGateway(
          initial: const KycSubmission(
            status: KycStatus.rejected,
            rejectionReason: KycRejectionReason.other,
          ),
        ),
      ),
    ),
  ],
);
