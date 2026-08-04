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

Widget _chatDetail(ChatDetailScreenPreviewState state) => ChatDetailScreen(
      chatId: state.chatId,
      debugGateway: state.gateway(),
      debugPhase: state.phase,
      debugHasWinner: state.hasWinner,
      debugCounterpartName: state.counterpartName,
      debugSummary: state.summary,
    );

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
        // alreadyRated: shows read-only summary sheet instead of navigating out
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
        'Loading — read in flight',
        (context) => DeliveryReceiptScreen(
          deliveryId: DeliveryReceiptScreenFixtures.deliveryId,
          repository: DeliveryReceiptScreenFixtures.pending(),
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

Widget _deliveryStatusScreen(DeliveryStatusScreenDesignedState state) =>
    DeliveryStatusScreen(
      deliveryId: state.deliveryId,
      gateway: state.gateway,
    );

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

Widget _disputeStatusScreen(DisputeStatusScreenDesignedState state) =>
    DisputeStatusScreen(
      disputeId: state.disputeId,
      repository: state.repository,
    );

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
