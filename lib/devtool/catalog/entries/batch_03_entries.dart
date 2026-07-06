import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/chat/data/dev_chat_fixture_gateway.dart';
import '../../../features/chat/domain/delivery_chat_message.dart'
    show ConversationPhase;
import '../../../features/chat/domain/order_chat_summary.dart';
import '../../../features/deep_link_targets/chat_detail_screen.dart';
import '../../../features/deep_link_targets/delivery_detail_screen.dart';
import '../../../features/deep_link_targets/kyc_status_screen.dart';
import '../../../features/deep_link_targets/rating_prompt_screen.dart';
import '../../../features/delivery_man_profile/data/dev_delivery_man_profile_fixtures.dart';
import '../../../features/delivery_man_profile/domain/delivery_man_profile_view_data.dart';
import '../../../features/delivery_man_profile/presentation/delivery_man_profile_screen.dart';
import '../../../features/delivery_receipt/data/fake_delivery_receipt_repository.dart';
import '../../../features/delivery_receipt/domain/delivery_receipt.dart';
import '../../../features/delivery_receipt/domain/delivery_receipt_repository.dart';
import '../../../features/delivery_receipt/presentation/delivery_receipt_screen.dart';
import '../../../features/delivery_status/domain/delivery_address.dart';
import '../../../features/delivery_status/domain/delivery_snapshot.dart';
import '../../../features/delivery_status/domain/delivery_stage.dart';
import '../../../features/delivery_status/domain/delivery_status_gateway.dart';
import '../../../features/delivery_status/domain/delivery_tier.dart';
import '../../../features/delivery_status/domain/jeeber_summary.dart';
import '../../../features/delivery_status/presentation/delivery_status_screen.dart';
import '../../../features/dispute_status/data/empty_dispute_status_repository.dart';
import '../../../features/dispute_status/domain/dispute_status_repository.dart';
import '../../../features/dispute_status/presentation/dispute_status_screen.dart';
import '../../../features/earnings/application/earnings_cubit.dart';
import '../../../features/earnings/domain/earnings_repository.dart';
import '../../../features/earnings/domain/earnings_summary.dart';
import '../../../features/earnings/presentation/earnings_dashboard_screen.dart';
import '../catalog_models.dart';

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
final List<CatalogEntry> _chatDetailEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'deep_link_targets',
    screen: 'ChatDetailScreen',
    states: [
      CatalogState(
        'Compose — broadcasting, no offers yet',
        (context) => ChatDetailScreen(
          chatId: 'chat-sending-1',
          debugGateway: DevChatFixtureGateway(
            phase: ConversationPhase.broadcasting,
            sending: true,
          ),
          debugPhase: ConversationPhase.broadcasting,
        ),
      ),
      CatalogState(
        'Broadcasting — offer cards landing',
        (context) => ChatDetailScreen(
          chatId: 'chat-broadcasting-1',
          debugGateway: DevChatFixtureGateway(
            phase: ConversationPhase.broadcasting,
          ),
          debugPhase: ConversationPhase.broadcasting,
        ),
      ),
      CatalogState(
        'Accepted — 1:1 thread + pinned summary',
        (context) => ChatDetailScreen(
          chatId: 'chat-accepted-1',
          debugGateway: DevChatFixtureGateway(
            phase: ConversationPhase.accepted,
          ),
          debugPhase: ConversationPhase.accepted,
          debugHasWinner: true,
          debugCounterpartName: 'Kamal Hajj',
          debugSummary: const OrderChatSummary(
            deliveryId: 'chat-accepted-1',
            requestId: 'chat-accepted-1',
            priceLabel: r'$35.00',
            jeeberName: 'Kamal Hajj',
            rating: 4.6,
            etaMinutes: 120,
            tierId: 'standard',
            orderRef: 'ORD-4821',
            statusId: 'matched',
          ),
        ),
      ),
    ],
  ),
];

/// `DeliveryDetailScreen` — the order-detail action hub. No repository/GetIt
/// dependency at all (every CTA just pushes a route), so the real screen
/// renders as-is with zero seams. `RoleCubit` is read defensively (catches
/// `ProviderNotFoundException`), so the plain catalog host is safe.
final List<CatalogEntry> _deliveryDetailEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'deep_link_targets',
    screen: 'DeliveryDetailScreen',
    states: [
      CatalogState(
        'Action hub',
        (context) => const DeliveryDetailScreen(deliveryId: 'ORD-4821'),
      ),
    ],
  ),
];

/// `KycStatusScreen` — restored placeholder (no behavior, no network).
final List<CatalogEntry> _kycStatusEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'deep_link_targets',
    screen: 'KycStatusScreen',
    states: [
      CatalogState('Placeholder', (context) => const KycStatusScreen()),
    ],
  ),
];

/// `RatingPromptScreen` — placeholder governed by the Type-A placeholder
/// discipline script; no behavior/network to fake.
final List<CatalogEntry> _ratingPromptEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'deep_link_targets',
    screen: 'RatingPromptScreen',
    states: [
      CatalogState(
        'Placeholder',
        (context) => const RatingPromptScreen(deliveryId: 'ORD-4821'),
      ),
    ],
  ),
];

// ───────────────────────── delivery_man_profile ───────────────────────────

/// `DeliveryManProfileScreen` — takes a plain [DeliveryManProfileViewData]
/// value, no GetIt/network involved at all.
final List<CatalogEntry> _deliveryManProfileEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'delivery_man_profile',
    screen: 'DeliveryManProfileScreen',
    states: [
      CatalogState(
        'Populated — reviews + score (shipped fixture)',
        (context) => const DeliveryManProfileScreen(
          data: DevDeliveryManProfileFixtures.sample,
        ),
      ),
      CatalogState(
        'Cold-start — < 5 reviews, score hidden (D59)',
        (context) => const DeliveryManProfileScreen(
          data: DeliveryManProfileViewData(
            name: 'Rana Ahmad',
            rating: 5,
            reviewCount: 2,
            location: 'Lebanon',
            isAvailable: true,
            jeeberId: 'jeeber-rana',
            reviews: [
              DeliveryReviewData(
                id: 'r1',
                reviewerName: 'Sami Fares',
                rating: 5,
                body: 'Fast and friendly, will request again.',
                daysAgo: 1,
              ),
            ],
          ),
        ),
      ),
      CatalogState(
        'Empty — no reviews yet',
        (context) => const DeliveryManProfileScreen(
          data: DeliveryManProfileViewData(
            name: 'New Jeeber',
            rating: 0,
            reviewCount: 0,
            location: 'Lebanon',
            isAvailable: false,
            reviews: [],
          ),
        ),
      ),
    ],
  ),
];

// ───────────────────────────── delivery_receipt ───────────────────────────

/// `DeliveryReceiptScreen` — the shipped `repository` constructor seam
/// (already production-designed for widget tests) is reused directly with
/// [FakeDeliveryReceiptRepository].
final List<CatalogEntry> _deliveryReceiptEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'delivery_receipt',
    screen: 'DeliveryReceiptScreen',
    states: [
      CatalogState(
        'Loaded — proof photo + cash-on-delivery amount',
        (context) => DeliveryReceiptScreen(
          deliveryId: 'ORD-4821',
          repository: FakeDeliveryReceiptRepository(),
        ),
      ),
      CatalogState(
        'Loaded — amount unknown (run-22 P1-A degrade)',
        (context) => DeliveryReceiptScreen(
          deliveryId: 'ORD-4821',
          repository: FakeDeliveryReceiptRepository(
            receipt: const DeliveryReceipt(
              deliveryId: 'ORD-4821',
              jeeberName: 'Kamal Hajj',
              jeeberId: 'user-jeeber-002',
              cashAmount: null,
              currency: 'USD',
              status: 'Done',
              proofPhotoUrl: null,
            ),
          ),
        ),
      ),
      CatalogState(
        'Error — receipt not found',
        (context) => DeliveryReceiptScreen(
          deliveryId: 'ORD-4821',
          repository: FakeDeliveryReceiptRepository(
            fetchFailure: DeliveryReceiptFailure.notFound,
          ),
        ),
      ),
    ],
  ),
];

// ───────────────────────────── delivery_status ────────────────────────────

DeliverySnapshot _statusSnapshot(
  DeliveryStage stage, {
  DeliveryLifecycle lifecycle = DeliveryLifecycle.active,
  int? etaMinutes,
}) {
  final now = DateTime.now();
  final timestamps = <DeliveryStage, DateTime>{};
  for (final s in DeliveryStage.values) {
    if (!stage.isBefore(s)) {
      timestamps[s] =
          now.subtract(Duration(minutes: (stage.order - s.order + 1) * 4));
    }
  }
  return DeliverySnapshot(
    id: 'ORD-4821',
    stage: stage,
    lifecycle: lifecycle,
    stageTimestamps: timestamps,
    pickup: const DeliveryAddress(
      label: 'Hamra Main St, Beirut',
      detail: 'Apt 4B, Floor 3',
    ),
    dropoff: const DeliveryAddress(
      label: 'Verdun, Beirut',
      detail: 'Reception desk',
    ),
    tier: DeliveryTier.scooter,
    jeeber: lifecycle == DeliveryLifecycle.active
        ? const JeeberSummary(
            displayName: 'Karim H.',
            vehicleLabel: 'Scooter',
            phoneE164: '+96171000000',
            rating: 4.8,
          )
        : null,
    etaMinutes: etaMinutes,
  );
}

/// Local fake gateway for the one state [InMemoryDeliveryStatusGateway] can't
/// script directly: a stream that fails outright (the D30 error state).
class _ErroringDeliveryStatusGateway implements DeliveryStatusGateway {
  @override
  Stream<DeliverySnapshot> watch(String deliveryId) =>
      Stream<DeliverySnapshot>.error(StateError('stream lost'));

  @override
  Future<CancellationOutcome> cancel(String deliveryId) async =>
      CancellationOutcome.networkError;
}

/// `DeliveryStatusScreen` — the shipped `gateway` constructor seam
/// ([InMemoryDeliveryStatusGateway] + `demoDeliverySnapshot`, already used by
/// the screen's own no-backend fallback) is reused for every in-flight stage;
/// the terminal/error states are built from plain domain values.
final List<CatalogEntry> _deliveryStatusEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'delivery_status',
    screen: 'DeliveryStatusScreen',
    states: [
      CatalogState(
        'Matched — courier assigned',
        (context) => DeliveryStatusScreen(
          deliveryId: 'ORD-4821',
          gateway: InMemoryDeliveryStatusGateway(
            seed: _statusSnapshot(DeliveryStage.matched),
          ),
        ),
      ),
      CatalogState(
        'In transit — ETA visible',
        (context) => DeliveryStatusScreen(
          deliveryId: 'ORD-4821',
          gateway: InMemoryDeliveryStatusGateway(
            seed: _statusSnapshot(DeliveryStage.inTransit, etaMinutes: 8),
          ),
        ),
      ),
      CatalogState(
        'Delivered — terminal, CTAs hidden',
        (context) => DeliveryStatusScreen(
          deliveryId: 'ORD-4821',
          gateway: InMemoryDeliveryStatusGateway(
            seed: _statusSnapshot(
              DeliveryStage.delivered,
              lifecycle: DeliveryLifecycle.completed,
            ),
          ),
        ),
      ),
      CatalogState(
        'Error — stream lost, retry',
        (context) => DeliveryStatusScreen(
          deliveryId: 'ORD-4821',
          gateway: _ErroringDeliveryStatusGateway(),
        ),
      ),
    ],
  ),
];

// ───────────────────────────── dispute_status ─────────────────────────────

/// Inline fake for [DisputeStatusRepository] — the screen's shipped
/// `repository` constructor seam takes any implementation directly.
class _FakeDisputeStatusRepository implements DisputeStatusRepository {
  const _FakeDisputeStatusRepository(this.dispute);

  final DisputeStatus dispute;

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async => dispute;
}

final List<CatalogEntry> _disputeStatusEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'dispute_status',
    screen: 'DisputeStatusScreen',
    states: [
      CatalogState(
        'Open — under review',
        (context) => const DisputeStatusScreen(
          disputeId: 'dsp-1',
          repository: _FakeDisputeStatusRepository(
            DisputeStatus(
              id: 'dsp-1',
              state: DisputeState.open,
              orderRef: 'ORD-4821',
              createdAt: '2026-07-01T10:00:00Z',
              evidence: DisputeEvidenceSummary(
                reason: 'damaged',
                comment: 'Box arrived crushed.',
                photoCount: 2,
                hasChatSnapshot: true,
                chatMessageCount: 6,
                timelineCount: 4,
              ),
            ),
          ),
        ),
      ),
      CatalogState(
        'Resolved — refund issued (D2)',
        (context) => const DisputeStatusScreen(
          disputeId: 'dsp-2',
          repository: _FakeDisputeStatusRepository(
            DisputeStatus(
              id: 'dsp-2',
              state: DisputeState.resolved,
              outcome: DisputeOutcome.refund,
              resolution: 'refund',
              refundAmount: 35,
              currency: 'USD',
              orderRef: 'ORD-4790',
              createdAt: '2026-06-28T09:00:00Z',
              resolvedAt: '2026-06-29T14:00:00Z',
              evidence: DisputeEvidenceSummary(
                reason: 'no_show',
                photoCount: 1,
                hasVoice: true,
                timelineCount: 3,
              ),
            ),
          ),
        ),
      ),
      CatalogState(
        'Error — not found (shipped fallback repository)',
        (context) => const DisputeStatusScreen(
          disputeId: '',
          repository: EmptyDisputeStatusRepository(),
        ),
      ),
    ],
  ),
];

// ──────────────────────────────── earnings ────────────────────────────────

/// Inline fake for [EarningsRepository] — the screen has no constructor seam
/// of its own (it reads `EarningsCubit` off a `BlocProvider` ancestor), so
/// each state wraps the real [EarningsDashboardScreen] in a locally-created
/// [BlocProvider] seeded with this fake — no GetIt, no Dio, no live gateway.
class _FakeEarningsRepository implements EarningsRepository {
  const _FakeEarningsRepository(this._summary);

  final EarningsSummary _summary;

  @override
  Future<EarningsSummary> fetchEarnings({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      _summary;

  @override
  Future<String> exportEarningsPdf({
    String jeeberId = '',
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      '/tmp/dev-earnings.pdf';
}

Widget _earningsHost(EarningsSummary summary) => BlocProvider<EarningsCubit>(
      create: (_) =>
          EarningsCubit(repository: _FakeEarningsRepository(summary)),
      child: const EarningsDashboardScreen(),
    );

final List<CatalogEntry> _earningsEntries = <CatalogEntry>[
  CatalogEntry(
    feature: 'earnings',
    screen: 'EarningsDashboardScreen',
    states: [
      CatalogState(
        'Populated — cash + fees + breakdown',
        (context) => _earningsHost(
          const EarningsSummary(
            totalCashEarned: 245.0,
            feesPaid: 24.5,
            currency: 'USD',
            deliveryCount: 7,
            memberSince: '2025-11-03T00:00:00Z',
            deliveries: [
              EarningsDeliveryItem(
                deliveryId: 'ORD-4821',
                date: '2026-07-04T18:20:00Z',
                cashCollected: 35.0,
                feePaid: 3.5,
                currency: 'USD',
              ),
              EarningsDeliveryItem(
                deliveryId: 'ORD-4790',
                date: '2026-07-02T12:05:00Z',
                cashCollected: 50.0,
                feePaid: 5.0,
                currency: 'USD',
              ),
            ],
          ),
        ),
      ),
      CatalogState(
        'Empty — no earnings this period (T11/SW-01 honest empty)',
        (context) => _earningsHost(
          const EarningsSummary(
            totalCashEarned: 0,
            feesPaid: 0,
            currency: 'USD',
            deliveryCount: 0,
          ),
        ),
      ),
    ],
  ),
];
