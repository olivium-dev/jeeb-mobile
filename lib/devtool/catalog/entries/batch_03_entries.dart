import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/deep_link_targets/chat_detail_screen.dart';
import '../../../features/deep_link_targets/delivery_detail_screen.dart';
import '../../../features/deep_link_targets/kyc_status_screen.dart';
import '../../../features/deep_link_targets/rating_prompt_screen.dart';
import '../../../features/delivery_man_profile/presentation/delivery_man_profile_screen.dart';
import '../../../features/delivery_receipt/presentation/delivery_receipt_screen.dart';
import '../../../features/delivery_status/presentation/delivery_status_screen.dart';
import '../../../features/dispute_status/presentation/dispute_status_screen.dart';
import '../../../features/earnings/application/earnings_cubit.dart';
import '../../../features/earnings/domain/earnings_repository.dart';
import '../../../features/earnings/presentation/earnings_dashboard_screen.dart';
import '../catalog_models.dart';
import '../fixtures/chat_detail_screen_fixtures.dart';
import '../fixtures/delivery_detail_screen_fixtures.dart';
import '../fixtures/delivery_man_profile_screen_fixtures.dart';
import '../fixtures/delivery_receipt_screen_fixtures.dart';
import '../fixtures/delivery_status_screen_fixtures.dart';
import '../fixtures/dispute_status_screen_fixtures.dart';
import '../fixtures/earnings_dashboard_screen_fixtures.dart';
import '../fixtures/kyc_status_screen_fixtures.dart';
import '../fixtures/rating_prompt_screen_fixtures.dart';

/// DT-04 / F2 batch 3 — deep_link_targets, delivery_man_profile,
/// delivery_receipt, delivery_status, dispute_status, earnings.
///
/// Every builder below mounts the REAL screen against a local, offline
/// fake/stub — never GetIt's live Dio — per the DT-04 DoD.
List<CatalogEntry> get batch03Entries => <CatalogEntry>[
      ..._chatDetailEntries,
      ..._deliveryDetailEntries,
      ..._kycStatusEntries,
      ..._ratingPromptEntries,
      ..._deliveryManProfileEntries,
      ..._deliveryReceiptEntries,
      ..._deliveryStatusEntries,
      ..._disputeStatusEntries,
      ..._earningsEntries,
    ];

// ─────────────────────────── deep_link_targets ────────────────────────────

/// `ChatDetailScreen` — the `/chat/:id` order-chat deep-link target (JM-025).
/// Driven through the additive `debugGateway` seam (chat_detail_screen.dart)
/// so no async GetIt/Dio resolution ever runs; each state pairs a
/// [DevChatFixtureGateway] (already shipped for the app's own dev-seam
/// capture path) with the matching phase/winner/summary flags.
///
/// The states themselves live in `fixtures/chat_detail_screen_fixtures.dart`,
/// shared with the JEEB PREVIEWS section at the bottom of the screen's own
/// source file, so this browser and that canvas cannot drift into showing two
/// different "designed states" under the same label. The six states that file
/// adds beyond these three (fresh compose, empty, failed, loading, longest
/// content, unnamed counterpart) are engineer-facing and are deliberately not
/// listed here.
final List<CatalogEntry> _chatDetailEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'deep_link_targets',
    screen: 'ChatDetailScreen',
    states: [
      CatalogState(
        'Compose — broadcasting, no offers yet',
        (context) => _chatDetail(ChatDetailScreenPreviewFixtures.compose),
      ),
      CatalogState(
        'Broadcasting — offer cards landing',
        (context) => _chatDetail(ChatDetailScreenPreviewFixtures.broadcasting),
      ),
      CatalogState(
        'Accepted — 1:1 thread + pinned summary',
        (context) => _chatDetail(ChatDetailScreenPreviewFixtures.accepted),
      ),
    ],
  ),
];

/// Mounts one [ChatDetailScreenPreviewState] through the screen's `debugGateway`
/// seam. The preview section at the bottom of `chat_detail_screen.dart` has the
/// same two lines against the same descriptors — see that file's note on why the
/// construction is not shared.
Widget _chatDetail(ChatDetailScreenPreviewState state) => ChatDetailScreen(
      chatId: state.chatId,
      debugGateway: state.gateway(),
      debugPhase: state.phase,
      debugHasWinner: state.hasWinner,
      debugCounterpartName: state.counterpartName,
      debugSummary: state.summary,
    );

/// `DeliveryDetailScreen` — the order-detail action hub. `RoleCubit` is read
/// defensively (catches `ProviderNotFoundException`), so the plain catalog host
/// is safe.
///
/// This entry USED to mount the screen bare, on the strength of "no
/// repository/GetIt dependency at all — every CTA just pushes a route". That
/// stopped being true at JEBV4-309: the hub now reads the delivery's lifecycle
/// `statusId` on mount, and with `summaryRepository:` null it resolves that read
/// from GetIt's live `Dio`. The catalog only ever runs inside the app, where DI
/// IS built, so the bare entry issued a real `GET /v1/deliveries/ORD-4821` —
/// a GET, so `CatalogNetworkGuard` waves it through — and then rendered
/// whichever bucket that order happened to be in on the day. Both seams are now
/// scripted from `../fixtures/delivery_detail_screen_fixtures.dart`, shared with
/// the JEEB PREVIEWS section at the bottom of the screen's own source file, so
/// the states below are designed rather than observed and the two dev surfaces
/// cannot drift apart.
///
/// `Action hub` is kept as the first state under its original name — it is the
/// fail-open list this entry always showed, now reached deliberately (status
/// unavailable) instead of by whatever the gateway said.
final List<CatalogEntry> _deliveryDetailEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'deep_link_targets',
    screen: 'DeliveryDetailScreen',
    states: [
      CatalogState(
        'Action hub — status unavailable, fails open',
        (context) => const DeliveryDetailScreen(
          deliveryId: DeliveryDetailScreenFixtures.deliveryId,
          summaryRepository: DeliveryDetailScreenFixtures.statusUnavailable,
          ratingRepository: DeliveryDetailScreenFixtures.notYetRated,
          refreshSignals: Stream<void>.empty(),
        ),
      ),
      CatalogState(
        'Active — pre-pickup (free cancel open)',
        (context) => const DeliveryDetailScreen(
          deliveryId: DeliveryDetailScreenFixtures.deliveryId,
          summaryRepository: DeliveryDetailScreenFixtures.ordered,
          ratingRepository: DeliveryDetailScreenFixtures.notYetRated,
          refreshSignals: Stream<void>.empty(),
        ),
      ),
      CatalogState(
        'Active — in transit (cancel closed)',
        (context) => const DeliveryDetailScreen(
          deliveryId: DeliveryDetailScreenFixtures.deliveryId,
          summaryRepository: DeliveryDetailScreenFixtures.inTransit,
          ratingRepository: DeliveryDetailScreenFixtures.notYetRated,
          refreshSignals: Stream<void>.empty(),
        ),
      ),
      CatalogState(
        // `alreadyRated`, so a designer tapping Rate gets the read-only summary
        // sheet in place rather than being navigated out of the catalog into
        // the DI-backed mutual-rating terminal.
        'Delivered — banner + Rate + Receipt',
        (context) => const DeliveryDetailScreen(
          deliveryId: DeliveryDetailScreenFixtures.deliveryId,
          summaryRepository: DeliveryDetailScreenFixtures.delivered,
          ratingRepository: DeliveryDetailScreenFixtures.alreadyRated,
          refreshSignals: Stream<void>.empty(),
        ),
      ),
      CatalogState(
        'Cancelled — banner + Report only',
        (context) => const DeliveryDetailScreen(
          deliveryId: DeliveryDetailScreenFixtures.deliveryId,
          summaryRepository: DeliveryDetailScreenFixtures.cancelled,
          ratingRepository: DeliveryDetailScreenFixtures.notYetRated,
          refreshSignals: Stream<void>.empty(),
        ),
      ),
    ],
  ),
];

/// `KycStatusScreen` — restored placeholder (no behavior, no network).
///
/// The screen has no data axis to seed, so its designed states are WINDOWS:
/// how wide, how tall, how much of the display the system chrome has claimed,
/// and how large the user has set their text. Those windows live in
/// `../fixtures/kyc_status_screen_fixtures.dart` and are shared verbatim with
/// the JEEB PREVIEWS section at the bottom of the screen's own file, so this
/// catalog and the preview canvas cannot drift apart.
///
/// `Placeholder` renders at the real device size (the device IS the window);
/// the rest frame a simulated display inside it, captioned, so a reviewer can
/// see the small-screen and 200%-text renderings without owning six phones.
final List<CatalogEntry> _kycStatusEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'deep_link_targets',
    screen: 'KycStatusScreen',
    states: [
      CatalogState(
        'Placeholder',
        (context) => const KycStatusScreenPreviewHost(
          screen: KycStatusScreen(),
        ),
      ),
      for (final KycStatusScreenWindow window in KycStatusScreenWindows.all)
        CatalogState(
          window.label,
          (context) => KycStatusScreenPreviewHost(
            window: window,
            screen: const KycStatusScreen(),
          ),
        ),
    ],
  ),
];

/// `RatingPromptScreen` — placeholder governed by the Type-A placeholder
/// discipline script; no behavior/network to fake.
///
/// The screen has no data axis to seed either, so — as with `KycStatusScreen`
/// above — its designed states are WINDOWS: how wide, how tall, how much of the
/// display the system chrome has claimed, how large the user has set their
/// text, and which deep-link `deliveryId` it was handed (a parameter it accepts
/// and never renders). Those windows live in
/// `../fixtures/rating_prompt_screen_fixtures.dart` and are shared verbatim
/// with the JEEB PREVIEWS section at the bottom of the screen's own file, so
/// this catalog and the preview canvas cannot drift apart.
///
/// `Placeholder` renders at the real device size (the device IS the window);
/// the rest frame a simulated display inside it, captioned, so a reviewer can
/// see the small-screen and 200%-text renderings without owning six phones.
final List<CatalogEntry> _ratingPromptEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'deep_link_targets',
    screen: 'RatingPromptScreen',
    states: [
      CatalogState(
        'Placeholder',
        (context) => const RatingPromptScreen(
          deliveryId: RatingPromptScreenFixtures.deliveryId,
        ),
      ),
      for (final RatingPromptScreenWindow window
          in RatingPromptScreenWindows.all)
        CatalogState(
          window.label,
          (context) => RatingPromptScreenPreviewHost(
            window: window,
            screen: RatingPromptScreen(deliveryId: window.deliveryId),
          ),
        ),
    ],
  ),
];

// ───────────────────────── delivery_man_profile ───────────────────────────

/// `DeliveryManProfileScreen` — takes a plain `DeliveryManProfileViewData`
/// value, no GetIt/network involved at all.
///
/// The three states themselves live in
/// `fixtures/delivery_man_profile_screen_fixtures.dart`, shared with the JEEB
/// PREVIEWS section at the bottom of the screen's own source file, so the
/// designer's browser and the engineer's canvas cannot drift into two
/// different "designed states" under the same label.
final List<CatalogEntry> _deliveryManProfileEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'delivery_man_profile',
    screen: 'DeliveryManProfileScreen',
    states: [
      CatalogState(
        'Populated — reviews + score (shipped fixture)',
        (context) => const DeliveryManProfileScreen(
          data: DeliveryManProfileScreenFixtures.populated,
        ),
      ),
      CatalogState(
        'Cold-start — < 5 reviews, score hidden (D59)',
        (context) => const DeliveryManProfileScreen(
          data: DeliveryManProfileScreenFixtures.coldStart,
        ),
      ),
      CatalogState(
        'Empty — no reviews yet',
        (context) => const DeliveryManProfileScreen(
          data: DeliveryManProfileScreenFixtures.empty,
        ),
      ),
    ],
  ),
];

// ───────────────────────────── delivery_receipt ───────────────────────────

/// `DeliveryReceiptScreen` — the shipped `repository` constructor seam
/// (already production-designed for widget tests) is the ONLY seam this screen
/// exposes: it builds its own `DeliveryReceiptCubit` internally, so every state
/// is reached through a repository that answers, stalls, or throws.
///
/// The three states below are unchanged; their fixtures now live in
/// `../fixtures/delivery_receipt_screen_fixtures.dart`, shared with the JEEB
/// PREVIEWS section at the bottom of the screen's own source file, so this
/// browser and that canvas cannot drift into showing two different "designed
/// states" under the same label. The six states that file adds beyond these
/// three (loading, zero amount, missing jeeber name, longest content, network
/// failure, rejected confirm) are engineer-facing and are deliberately not
/// listed here.
final List<CatalogEntry> _deliveryReceiptEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'delivery_receipt',
    screen: 'DeliveryReceiptScreen',
    states: [
      CatalogState(
        'Loaded — proof photo + cash-on-delivery amount',
        (context) => DeliveryReceiptScreen(
          deliveryId: DeliveryReceiptScreenFixtures.deliveryId,
          repository: DeliveryReceiptScreenFixtures.loaded(),
        ),
      ),
      CatalogState(
        'Loaded — amount unknown (run-22 P1-A degrade)',
        (context) => DeliveryReceiptScreen(
          deliveryId: DeliveryReceiptScreenFixtures.deliveryId,
          repository: DeliveryReceiptScreenFixtures.amountUnknown(),
        ),
      ),
      CatalogState(
        'Error — receipt not found',
        (context) => DeliveryReceiptScreen(
          deliveryId: DeliveryReceiptScreenFixtures.deliveryId,
          repository: DeliveryReceiptScreenFixtures.notFound(),
        ),
      ),
    ],
  ),
];

// ───────────────────────────── delivery_status ────────────────────────────

/// Mounts the real screen on one designed state.
///
/// The `gateway:` argument is the screen's shipped constructor seam — the same
/// one its own no-backend fallback uses — so nothing here reaches DI.
Widget _deliveryStatusScreen(DeliveryStatusScreenDesignedState state) =>
    DeliveryStatusScreen(
      deliveryId: state.deliveryId,
      gateway: state.gateway,
    );

/// `DeliveryStatusScreen` — driven through the shipped `gateway` seam.
///
/// The states themselves live in
/// `fixtures/delivery_status_screen_fixtures.dart`, shared with the JEEB
/// PREVIEWS section at the bottom of the screen's own source file, so the
/// catalog card and the canvas card cannot drift into two different notions of
/// the same designed state. That file holds more states than are listed here
/// (cold load, no courier yet, cancelled, mid-delivery drop, cancel in
/// flight); they are one line each to add.
final List<CatalogEntry> _deliveryStatusEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'delivery_status',
    screen: 'DeliveryStatusScreen',
    states: [
      CatalogState(
        'Matched — courier assigned',
        (context) => _deliveryStatusScreen(
          DeliveryStatusScreenFixtures.matched,
        ),
      ),
      CatalogState(
        'In transit — ETA visible',
        (context) => _deliveryStatusScreen(
          DeliveryStatusScreenFixtures.inTransit,
        ),
      ),
      CatalogState(
        'Delivered — terminal, CTAs hidden',
        (context) => _deliveryStatusScreen(
          DeliveryStatusScreenFixtures.delivered,
        ),
      ),
      CatalogState(
        'Error — stream lost, retry',
        (context) => _deliveryStatusScreen(
          DeliveryStatusScreenFixtures.streamLostOnOpen,
        ),
      ),
    ],
  ),
];

// ───────────────────────────── dispute_status ─────────────────────────────

/// `DisputeStatusScreen` — the JM-065 dispute-status surface, driven through
/// its shipped `repository:` constructor seam (40_GUARDRAILS_ARCH §5.4), so no
/// GetIt/Dio resolution ever runs.
///
/// The states themselves live in
/// `fixtures/dispute_status_screen_fixtures.dart`, shared with the JEEB
/// PREVIEWS section at the bottom of the screen's own source file, so this
/// browser and that canvas cannot drift into showing two different "designed
/// states" under the same label. That file holds more states than are listed
/// here (cold read, empty evidence, penalty outcome, network / session-expired
/// failures, an unrecognized wire status, the longest-content ceiling); they
/// are one line each to add.
final List<CatalogEntry> _disputeStatusEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'dispute_status',
    screen: 'DisputeStatusScreen',
    states: [
      CatalogState(
        'Open — under review',
        (context) => _disputeStatusScreen(
          DisputeStatusScreenFixtures.openUnderReview,
        ),
      ),
      CatalogState(
        'Resolved — refund issued (D2)',
        (context) => _disputeStatusScreen(
          DisputeStatusScreenFixtures.resolvedRefund,
        ),
      ),
      CatalogState(
        'Error — not found (shipped fallback repository)',
        (context) => _disputeStatusScreen(
          DisputeStatusScreenFixtures.notFoundFallback,
        ),
      ),
    ],
  ),
];

/// Mounts the real screen on one shared designed state.
Widget _disputeStatusScreen(DisputeStatusScreenDesignedState state) =>
    DisputeStatusScreen(
      disputeId: state.disputeId,
      repository: state.repository,
    );

// ──────────────────────────────── earnings ────────────────────────────────

/// Mounts the real [EarningsDashboardScreen] over a local, offline repository.
///
/// The screen has no constructor seam of its own (it reads `EarningsCubit` off
/// a `BlocProvider` ancestor), so each state wraps it in a locally-created
/// [BlocProvider] seeded with a fixture repository — no GetIt, no Dio, no live
/// gateway.
///
/// The repositories and the summaries they answer with live in
/// `fixtures/earnings_dashboard_screen_fixtures.dart`, shared with the JEEB
/// PREVIEWS section at the bottom of the screen's own source file, so this
/// browser and that canvas cannot drift into showing two different "designed
/// states" under the same label. The four states that file adds beyond these
/// two (loading, load-failed, totals-without-rows, longest content) are
/// engineer-facing and are deliberately not listed here.
Widget _earningsHost(EarningsRepository repository) =>
    BlocProvider<EarningsCubit>(
      create: (_) => EarningsCubit(repository: repository),
      child: const EarningsDashboardScreen(),
    );

final List<CatalogEntry> _earningsEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'earnings',
    screen: 'EarningsDashboardScreen',
    states: [
      CatalogState(
        'Populated — cash + fees + breakdown',
        (context) =>
            _earningsHost(EarningsDashboardScreenPreviewFixtures.populated()),
      ),
      CatalogState(
        'Empty — no earnings this period (T11/SW-01 honest empty)',
        (context) =>
            _earningsHost(EarningsDashboardScreenPreviewFixtures.empty()),
      ),
    ],
  ),
];
