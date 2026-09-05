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
import '../../../features/jeeber_request_feed/data/request_feed_repository.dart';
import '../../../features/jeeber_request_feed/presentation/request_feed_screen.dart';
import '../../../features/kyc/application/kyc_wizard_cubit.dart';
import '../../../features/kyc/domain/kyc_gateway.dart';
import '../../../features/kyc/domain/kyc_submission.dart';
import '../../../features/photo_attachment/data/stub_photo_picker_service.dart';
import '../../../features/kyc/presentation/kyc_wizard_screen.dart';
import '../../../features/kyc_rejected/presentation/kyc_rejected_screen.dart';
import '../../../core/network/app_failure.dart';
import '../catalog_models.dart';
import '../fixtures/kyc_rejected_screen_fixtures.dart';
import '../fixtures/kyc_wizard_screen_fixtures.dart';
import '../fixtures/jeeber_pending_offers_screen_fixtures.dart';
import '../fixtures/jeeber_request_unavailable_screen_fixtures.dart';
import '../fixtures/jeeber_request_detail_screen_fixtures.dart';
import '../fixtures/onboarding_funding_screen_fixtures.dart';
import '../fixtures/request_feed_screen_fixtures.dart';

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
      (_) => const OnboardingFundingScreenHost(
        screen: OnboardingFundingScreen(
          repository: OnboardingFundingScreenStaticWallet(
            onboardingFundingScreenEnrichedBalance,
          ),
        ),
      ),
    ),
    CatalogState(
      'Empty — snapshot loaded with nothing to enrich',
      (_) => const OnboardingFundingScreenHost(
        screen: OnboardingFundingScreen(
          repository: OnboardingFundingScreenStaticWallet(
            onboardingFundingScreenNoCreditBalance,
          ),
        ),
      ),
    ),
    CatalogState(
      'Loading — wallet read in flight',
      (_) => const OnboardingFundingScreenHost(
        screen: OnboardingFundingScreen(
          repository: OnboardingFundingScreenPendingWallet(),
        ),
      ),
    ),
    CatalogState(
      'Fail-safe — wallet fetch failed, static explainer only',
      (_) => const OnboardingFundingScreenHost(
        screen: OnboardingFundingScreen(
          repository: OnboardingFundingScreenFailingWallet(),
        ),
      ),
    ),
    CatalogState(
      'Wallet read failed — 5xx, kind-aware and never blames the network',
      (_) => const OnboardingFundingScreenHost(
        screen: OnboardingFundingScreen(
          repository: onboardingFundingScreenServerFailingWallet,
        ),
      ),
    ),
  ],
);

final CatalogEntry _pendingOffersEntry = CatalogEntry(
  feature: 'jeeber_pending_offers',
  screen: 'JeeberPendingOffersScreen',
  states: [
    CatalogState(
      'Awaiting customer decision',
      (_) => const JeeberPendingOffersScreen(
        jeeberId: jeeberPendingOffersScreenJeeberId,
        repository: JeeberPendingOffersScreenStaticOffers(
          JeeberPendingOffersScreenOffers.awaitingDecision,
        ),
      ),
    ),
    CatalogState(
      'Mixed outcomes — accepted / not selected badges',
      (_) => const JeeberPendingOffersScreen(
        jeeberId: jeeberPendingOffersScreenJeeberId,
        repository: JeeberPendingOffersScreenStaticOffers(
          JeeberPendingOffersScreenOffers.mixedOutcomes,
        ),
      ),
    ),
    CatalogState(
      'Empty — nothing submitted yet',
      (_) => const JeeberPendingOffersScreen(
        jeeberId: jeeberPendingOffersScreenJeeberId,
        repository: JeeberPendingOffersScreenStaticOffers(
          JeeberPendingOffersScreenOffers.none,
        ),
      ),
    ),
    CatalogState(
      'Error — load failed',
      (_) => const JeeberPendingOffersScreen(
        jeeberId: jeeberPendingOffersScreenJeeberId,
        repository: JeeberPendingOffersScreenFailingOffers(),
      ),
    ),
    // Appended, not inserted: the capture filenames are index-keyed.
    CatalogState(
      'Loading — cold read in flight',
      (_) => const JeeberPendingOffersScreen(
        jeeberId: jeeberPendingOffersScreenJeeberId,
        repository: JeeberPendingOffersScreenStalledOffers(),
      ),
    ),
    CatalogState(
      'Error — load failed, kind-aware (503)',
      (_) => const JeeberPendingOffersScreen(
        jeeberId: jeeberPendingOffersScreenJeeberId,
        repository: FailingSubmittedOffersRepository(
          ServerFailure(status: 503),
        ),
      ),
    ),
    CatalogState(
      'Error — withdraw failed',
      (_) => const JeeberPendingOffersScreen(
        jeeberId: jeeberPendingOffersScreenJeeberId,
        repository: WithdrawFailingSubmittedOffersRepository(
          JeeberPendingOffersScreenOffers.awaitingDecision,
          NetworkFailure(),
        ),
      ),
    ),
    CatalogState(
      'Refresh failed — stale rows stay up',
      (_) => JeeberPendingOffersScreen(
        jeeberId: jeeberPendingOffersScreenJeeberId,
        cubit: refreshFailedSubmittedOffersCubit(
          JeeberPendingOffersScreenOffers.awaitingDecision,
          const NetworkFailure(),
        ),
      ),
    ),
  ],
);

const ProhibitedItemReportService _reportService =
    jeeberRequestDetailScreenReportService;

final CatalogEntry _requestDetailEntry = CatalogEntry(
  feature: 'jeeber_request_detail',
  screen: 'JeeberRequestDetailScreen',
  states: [
    CatalogState(
      'With request description (G1)',
      (_) => JeeberRequestDetailScreen(
        request: JeeberRequestDetailScreenRequests.described,
        reportService: _reportService,
        onDeclined: (_) {},
      ),
    ),
    CatalogState(
      'Without description (legacy/edge payload)',
      (_) => JeeberRequestDetailScreen(
        request: JeeberRequestDetailScreenRequests.withoutDescription,
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
      JeeberRequestUnavailableScreenFixtures.catalogDefault.label,
      (_) => JeeberRequestUnavailableScreenPreviewHost(
        fixture: JeeberRequestUnavailableScreenFixtures.catalogDefault,
        screen: JeeberRequestUnavailableScreen(
          requestId:
              JeeberRequestUnavailableScreenFixtures.catalogDefault.requestId,
          onBack: () {},
        ),
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
        // Never resolves — designed preview
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
    CatalogState(
      'Failed — transport error, retryable (LR-14)',
      (_) => JeeberRequestDetailLoader(
        requestId: 'req-500',
        initial: null,
        fetch: throwingRequestDetailFetch(const NetworkFailure(offline: true)),
        fetchAcceptedDeliveryId: () async => null,
        reportService: _reportService,
        onDeclined: (_) {},
        onBack: () {},
      ),
    ),
    CatalogState(
      'Unavailable — genuine miss (fetch returned null)',
      (_) => JeeberRequestDetailLoader(
        requestId: 'req-410',
        initial: null,
        fetch: missingRequestDetailFetch(),
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
        repositoryBuilder: () => SeededRequestFeedRepository(
          RequestFeedScreenPreviewFixtures.incomingFeed(),
        ),
      ),
    ),
    CatalogState(
      'Pending response — awaiting client reply',
      (_) => _RequestFeedPreview(
        repositoryBuilder: () => SeededRequestFeedRepository(
          RequestFeedScreenPreviewFixtures.pendingFeed(),
        ),
      ),
    ),
    CatalogState(
      'Accepted — delivery-action cards',
      (_) => _RequestFeedPreview(
        repositoryBuilder: () => SeededRequestFeedRepository(
          RequestFeedScreenPreviewFixtures.acceptedFeed(),
        ),
      ),
    ),
    CatalogState(
      'Empty — no requests right now',
      (_) => _RequestFeedPreview(
        repositoryBuilder: () => const EmptyRequestFeedRepository(),
      ),
    ),
    CatalogState(
      'Error — load failed',
      (_) => _RequestFeedPreview(
        repositoryBuilder: () => const ErrorRequestFeedRepository(),
      ),
    ),
    CatalogState(
      'Reconnecting — degraded polling transport',
      (_) => _RequestFeedPreview(
        repositoryBuilder: () => PollingRequestFeedRepository(
          RequestFeedScreenPreviewFixtures.incomingFeed(),
        ),
      ),
    ),
    // M4: appended, not inserted — the capture filenames are index-keyed. The
    // cold-read skeleton had no entry, so no capture had ever shown it.
    CatalogState(
      'Loading — cold read in flight',
      (_) => _RequestFeedPreview(
        repositoryBuilder: () => const StalledRequestFeedRepository(),
      ),
    ),
    CatalogState(
      'Error — server unavailable (503)',
      (_) => _RequestFeedSeated(
        cubitBuilder: () => RequestFeedScreenPreviewFixtures.loadFailedWith(
          const ServerFailure(status: 503),
        ),
      ),
    ),
    CatalogState(
      'Error — rate limited (429)',
      (_) => _RequestFeedSeated(
        cubitBuilder: () => RequestFeedScreenPreviewFixtures.loadFailedWith(
          const RateLimitedFailure(retryAfter: Duration(seconds: 30)),
        ),
      ),
    ),
    CatalogState(
      'Refresh failed — stale rows stay up',
      (_) => _RequestFeedSeated(
        cubitBuilder: () => RequestFeedScreenPreviewFixtures.warmFailureOverRows(
          RequestFeedScreenPreviewFixtures.incomingFeed(),
          const NetworkFailure(),
        ),
      ),
    ),
  ],
);

/// Seats an already-emitted cubit (never `start()`ed) and closes it on dispose.
class _RequestFeedSeated extends StatefulWidget {
  const _RequestFeedSeated({required this.cubitBuilder});

  final RequestFeedCubit Function() cubitBuilder;

  @override
  State<_RequestFeedSeated> createState() => _RequestFeedSeatedState();
}

class _RequestFeedSeatedState extends State<_RequestFeedSeated> {
  late final RequestFeedCubit _cubit = widget.cubitBuilder();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RequestFeedScreen(cubit: _cubit);
}

/// Closes the cubit's Timer on dispose (BlocProvider.value doesn't).
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

final CatalogEntry _kycWizardEntry = CatalogEntry(
  feature: 'kyc',
  screen: 'KycWizardScreen',
  states: [
    CatalogState(
      'Identity — fresh start, nothing captured',
      (_) => KycWizardScreen(
        cubit: KycWizardScreenPreviewFixtures.seededCubit(
          KycWizardScreenPreviewFixtures.identityState(),
        ),
      ),
    ),
    CatalogState(
      'Identity — front done, back is the live step (R23 board frame)',
      (_) => KycWizardScreen(
        cubit: KycWizardScreenPreviewFixtures.seededCubit(
          KycWizardScreenPreviewFixtures.identityState(
            idFrontCaptured: true,
            tosAccepted: true,
          ),
        ),
      ),
    ),
    CatalogState(
      'Identity — ready to submit (captures + ToS done)',
      (_) => KycWizardScreen(
        cubit: KycWizardScreenPreviewFixtures.seededCubit(
          KycWizardScreenPreviewFixtures.identityState(
            idNumber: KycWizardScreenPreviewFixtures.nationalIdNumber,
            govIdCaptured: true,
            selfieCaptured: true,
            tosAccepted: true,
          ),
        ),
      ),
    ),
    // M4 — the four §2.7 states the six pass-1 fixtures never reached. Every
    // KYC wait was catalog-invisible before this block.
    CatalogState(
      'Schema — cold form load in flight (M4 loading)',
      (_) => KycWizardScreen(
        cubit: KycWizardScreenPreviewFixtures.schemaLoadingCubit(),
      ),
    ),
    CatalogState(
      'Schema — form load failed, retry (M4 error)',
      (_) => KycWizardScreen(
        cubit: KycWizardScreenPreviewFixtures.seededCubit(
          KycWizardScreenPreviewFixtures.schemaLoadFailedState,
        ),
      ),
    ),
    CatalogState(
      'Submitting — POST /v1/kyc/submit in flight (M4 loading)',
      (_) => KycWizardScreen(
        cubit: KycWizardScreenPreviewFixtures.seededCubit(
          KycWizardScreenPreviewFixtures.submittingState,
        ),
      ),
    ),
    CatalogState(
      'Status — first read in flight (M4 loading)',
      (_) => KycWizardScreen(
        cubit: KycWizardScreenPreviewFixtures.seededCubit(
          KycWizardScreenPreviewFixtures.statusLoadingState,
        ),
      ),
    ),
    CatalogState(
      'Identity — ID back compressing (M4 inline wait)',
      (_) => KycWizardScreen(
        cubit: KycWizardScreenPreviewFixtures.seededCubit(
          KycWizardScreenPreviewFixtures.captureProcessingState(),
        ),
      ),
    ),
    CatalogState(
      'Status — pending review',
      (_) => KycWizardScreen(
        cubit: KycWizardScreenPreviewFixtures.statusCubit(
          status: KycStatus.pending,
        ),
      ),
    ),
    CatalogState(
      'Status — approved',
      (_) => KycWizardScreen(
        cubit: KycWizardScreenPreviewFixtures.statusCubit(
          status: KycStatus.approved,
        ),
      ),
    ),
    CatalogState(
      'Status — rejected',
      (_) => KycWizardScreen(
        cubit: KycWizardScreenPreviewFixtures.statusCubit(
          status: KycStatus.rejected,
          rejectionReason: KycRejectionReason.idUnreadable,
        ),
      ),
    ),
    CatalogState(
      'Status read failed',
      (_) => _kycWizardOverGateway(KycWizardScreenThrowingStatusGateway()),
    ),
    CatalogState(
      'Status stale — the background refresh failed (F26)',
      (_) => _kycWizardOverGateway(
        KycWizardScreenRefreshFailingGateway(
          initial: const KycSubmission(status: KycStatus.pending),
        ),
        reads: 2,
      ),
    ),
  ],
);

/// Hydrates the wizard through the real `loadStatus()` over a scripted gateway.
Widget _kycWizardOverGateway(KycGateway gateway, {int reads = 1}) {
  final KycWizardCubit cubit = KycWizardCubit(
    pickerService: StubPhotoPickerService(),
    gateway: gateway,
  );
  unawaited(
    Future<void>(() async {
      for (int i = 0; i < reads; i++) {
        await cubit.loadStatus();
      }
    }),
  );
  return KycWizardScreen(cubit: cubit);
}

final CatalogEntry _kycRejectedEntry = CatalogEntry(
  feature: 'kyc_rejected',
  screen: 'KycRejectedScreen',
  states: [
    CatalogState(
      'Reason — ID unreadable',
      (_) => KycRejectedScreen(gateway: KycRejectedScreenFixtures.idUnreadable()),
    ),
    CatalogState(
      'Reason — selfie mismatch',
      (_) =>
          KycRejectedScreen(gateway: KycRejectedScreenFixtures.selfieMismatch()),
    ),
    CatalogState(
      'Reason — document expired',
      (_) => KycRejectedScreen(gateway: KycRejectedScreenFixtures.expired()),
    ),
    CatalogState(
      'Reason — other/generic',
      (_) => KycRejectedScreen(gateway: KycRejectedScreenFixtures.other()),
    ),
    // MIDNIGHT M3-21: the three non-default phases of the cause enrichment.
    // All three fixtures existed and none was mounted, so none was ever captured.
    CatalogState(
      'No structured reason',
      (_) => KycRejectedScreen(
        gateway: KycRejectedScreenFixtures.rejectedWithoutReason(),
      ),
    ),
    CatalogState(
      'Status read failed',
      (_) => KycRejectedScreen(gateway: KycRejectedScreenFixtures.failing()),
      capturePolicy: CatalogCapturePolicy.navigationOnly,
    ),
    CatalogState(
      'Status read in flight',
      (_) => KycRejectedScreen(gateway: KycRejectedScreenFixtures.pending()),
    ),
    CatalogState(
      'Authority read failed (classified)',
      (_) => KycRejectedScreen(gateway: KycRejectedScreenThrowingGateway()),
    ),
  ],
);
