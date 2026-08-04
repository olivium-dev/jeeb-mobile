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
import '../../../features/kyc/domain/kyc_submission.dart';
import '../../../features/kyc/presentation/kyc_wizard_screen.dart';
import '../../../features/kyc_rejected/presentation/kyc_rejected_screen.dart';
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
  ],
);

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
  ],
);

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
    ),
    CatalogState(
      'Status read in flight',
      (_) => KycRejectedScreen(gateway: KycRejectedScreenFixtures.pending()),
    ),
  ],
);
