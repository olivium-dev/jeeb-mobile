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

/// Batch 05 — DT-04 catalog entries for: jeeber_onboarding_funding,
/// jeeber_pending_offers, jeeber_request_detail, jeeber_request_feed, kyc,
/// kyc_rejected.
///
/// Every builder below renders the REAL screen with a LOCAL fake/stub
/// injected through that screen's existing constructor test seam — no DI, no
/// network. Where a screen's data arrives by driving its real cubit through
/// its own public API (KYC captures, wallet/offer fetches), the seeding calls
/// are fire-and-forget against a synchronous, no-network fake so the cubit
/// settles into the target state after a couple of microtasks.
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

// ─────────────────────────────────────────────────────────────────────────
// jeeber_onboarding_funding
// ─────────────────────────────────────────────────────────────────────────

// Hosted through the shared fixture
// (`../fixtures/onboarding_funding_screen_fixtures.dart`), which the widget
// previews at the bottom of the screen file use as well, so the catalog and the
// canvas cannot drift. The host is a local [GoRouter] over stand-in
// destinations: without it every affordance on this screen
// (`funding_topup_cta` → `goNamed('wallet-charge-info')`,
// `funding_continue_cta` → `goNamed('kyc-status')`, and the app-bar arrow's
// `context.go('/')` fallback) drives the REAL app router and drops the reviewer
// out of the catalog into the live app.
//
// The two states and their labels are unchanged; only the fakes moved.

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
      'Fail-safe — wallet fetch failed, static explainer only',
      (_) => const OnboardingFundingScreenHost(
        screen: OnboardingFundingScreen(
          repository: OnboardingFundingScreenFailingWallet(),
        ),
      ),
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────
// jeeber_pending_offers
// ─────────────────────────────────────────────────────────────────────────

// The four states and their labels are unchanged; only the fakes moved. They
// now come from `../fixtures/jeeber_pending_offers_screen_fixtures.dart`, which
// the JEEB PREVIEWS section at the bottom of `jeeber_pending_offers_screen.dart`
// reads as well — so the surface a designer signs off against and the one an
// engineer edits cannot drift onto different offers.
//
// The old private `_StaticSubmittedOffersRepository(…, throwOnList: true)`
// became two named fakes, because "static repository with a boolean" read as
// the happy path when it was really the error branch.
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
  ],
);

// ─────────────────────────────────────────────────────────────────────────
// jeeber_request_detail
// ─────────────────────────────────────────────────────────────────────────

/// The inert reporting stub every state in this section passes in. Now an alias
/// for the shared fixture so the catalog and the preview section cannot end up
/// injecting different seams.
const ProhibitedItemReportService _reportService =
    jeeberRequestDetailScreenReportService;

/// The two designed states are unchanged — their payloads simply moved to
/// `../fixtures/jeeber_request_detail_screen_fixtures.dart`, shared verbatim
/// with the preview section at the bottom of
/// `jeeber_request_detail_screen.dart`, so the surface a designer signs off
/// against and the one an engineer edits cannot drift.
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

// The id and the framing come from
// `../fixtures/jeeber_request_unavailable_screen_fixtures.dart`, which the
// JEEB PREVIEWS section at the bottom of `jeeber_request_unavailable_screen.dart`
// also reads — so this state and the canvas cannot drift onto different ids.
// `catalogDefault` carries `window: null` and `parentOnStack: null`, i.e. the
// host renders the screen bare on the real device under the catalog's own
// route, exactly as this entry did before the extraction.
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
        // Never resolves, so the loading scaffold stays on screen for the
        // designed preview.
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

// ─────────────────────────────────────────────────────────────────────────
// jeeber_request_feed
// ─────────────────────────────────────────────────────────────────────────

// The six states and their labels are unchanged; only the fakes moved. Every
// repository and every feed below now comes from
// `../fixtures/request_feed_screen_fixtures.dart`, shared with the JEEB PREVIEWS
// section at the bottom of `request_feed_screen.dart`, so the designer's in-app
// browser and the engineer's canvas cannot drift into showing two different
// "designed states". The stateful host stays here: it is catalog chrome, and it
// is what drives a REAL `RequestFeedCubit.start()` so a designer can pull the
// list and tap the actions.

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

/// Owns the [RequestFeedCubit] for a catalog preview and closes it on
/// dispose. [RequestFeedScreen] only accepts a pre-built `cubit` (wired
/// internally via `BlocProvider.value`, which never closes it), and the
/// cubit runs a real `Timer.periodic` sweep (JEEB-66 G3 expiry sweep) — so
/// without this host, backing out of a preview would leak that timer.
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

// ─────────────────────────────────────────────────────────────────────────
// kyc
// ─────────────────────────────────────────────────────────────────────────

// Hosted through the shared fixture
// (`../fixtures/kyc_wizard_screen_fixtures.dart`), which the widget previews at
// the bottom of the screen file use as well, so the catalog and the canvas
// cannot drift. The five state labels are unchanged; only the fakes moved —
// see that file's header for the two things the move fixed (decodable capture
// bytes, and a "ready to submit" state whose submit CTA is actually live).

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

// ─────────────────────────────────────────────────────────────────────────
// kyc_rejected
// ─────────────────────────────────────────────────────────────────────────

// Hosted through the shared fixture
// (`../fixtures/kyc_rejected_screen_fixtures.dart`), which the widget previews
// at the bottom of the screen file use as well, so the catalog and the canvas
// cannot drift. The four states below are the four the catalog has always
// carried — the inline `FakeKycGateway(initial: KycSubmission(...))` literals
// moved into the fixture value for value, labels unchanged.
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
  ],
);
