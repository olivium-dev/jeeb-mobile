import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/delivery_receipt/data/fake_delivery_receipt_repository.dart';
import '../../../features/delivery_receipt/domain/delivery_receipt.dart';
import '../../../features/delivery_receipt/domain/delivery_receipt_repository.dart';
import '../../../features/delivery_receipt/presentation/delivery_receipt_screen.dart';
import '../../../features/delivery_status/domain/delivery_snapshot.dart';
import '../../../features/delivery_status/domain/delivery_stage.dart';
import '../../../features/delivery_status/domain/delivery_status_gateway.dart';
import '../../../features/delivery_status/presentation/delivery_status_screen.dart';
import '../../../features/dispute_status/data/empty_dispute_status_repository.dart';
import '../../../features/dispute_status/domain/dispute_status_repository.dart';
import '../../../features/dispute_status/presentation/dispute_status_screen.dart';
import '../../../features/earnings/application/earnings_cubit.dart';
import '../../../features/earnings/domain/earnings_repository.dart';
import '../../../features/earnings/domain/earnings_summary.dart';
import '../../../features/earnings/presentation/earnings_dashboard_screen.dart';
import '../../../features/escalate/application/escalate_cubit.dart';
import '../../../features/escalate/domain/escalate_repository.dart';
import '../../../features/escalate/presentation/escalate_screen.dart';
import '../../../features/goods_cost/presentation/goods_cost_screen.dart';
import '../catalog_models.dart';

/// Batch 03 — delivery_receipt, delivery_status, dispute_status, earnings,
/// escalate, goods_cost.
///
/// Same pattern as batch 00: every state passes an explicit LOCAL fake/stub
/// so the real screen renders its DESIGNED state with NO network. Screens
/// that resolve their cubit/repository from GetIt (`EarningsDashboardScreen`,
/// `EscalateScreen`) are wrapped in an explicit `BlocProvider` here instead.
List<CatalogEntry> get batch03Entries => <CatalogEntry>[
      const CatalogEntry(
        feature: 'delivery_receipt',
        screen: 'DeliveryReceiptScreen',
        states: [
          CatalogState('Loaded — proof photo', _deliveryReceiptWithPhoto),
          CatalogState('Loaded — no proof photo', _deliveryReceiptNoPhoto),
          CatalogState(
            'Load failed — network',
            _deliveryReceiptNetworkError,
          ),
        ],
      ),
      const CatalogEntry(
        feature: 'delivery_status',
        screen: 'DeliveryStatusScreen',
        states: [
          CatalogState('Matched', _deliveryStatusMatched),
          CatalogState('In transit — ETA visible', _deliveryStatusInTransit),
          CatalogState('Delivered (completed)', _deliveryStatusDelivered),
          CatalogState('Cancelled', _deliveryStatusCancelled),
          CatalogState('Stream lost — error', _deliveryStatusStreamError),
        ],
      ),
      const CatalogEntry(
        feature: 'dispute_status',
        screen: 'DisputeStatusScreen',
        states: [
          CatalogState('Open', _disputeStatusOpen),
          CatalogState('Resolved — refund', _disputeStatusResolvedRefund),
          CatalogState('Load failed (not found)', _disputeStatusNotFound),
        ],
      ),
      const CatalogEntry(
        feature: 'earnings',
        screen: 'EarningsDashboardScreen',
        states: [
          CatalogState('Loaded — with breakdown', _earningsLoaded),
          CatalogState('Loaded — no deliveries yet', _earningsEmpty),
          CatalogState('Load failed — network', _earningsError),
        ],
      ),
      const CatalogEntry(
        feature: 'escalate',
        screen: 'EscalateScreen',
        states: [
          CatalogState('Empty form', _escalateEmptyForm),
          CatalogState('Reason selected', _escalateReasonSelected),
          CatalogState('Submission error', _escalateSubmissionError),
        ],
      ),
      const CatalogEntry(
        feature: 'goods_cost',
        screen: 'GoodsCostScreen',
        states: [
          CatalogState('Enter cost', _goodsCostEnter),
        ],
      ),
    ];

// ─────────────────────────── delivery_receipt ───────────────────────────

Widget _deliveryReceiptWithPhoto(BuildContext _) => DeliveryReceiptScreen(
      deliveryId: 'demo-delivery-001',
      repository: FakeDeliveryReceiptRepository(),
    );

Widget _deliveryReceiptNoPhoto(BuildContext _) => DeliveryReceiptScreen(
      deliveryId: 'demo-delivery-002',
      repository: FakeDeliveryReceiptRepository(
        receipt: const DeliveryReceipt(
          deliveryId: 'demo-delivery-002',
          jeeberName: 'Rima Zein',
          jeeberId: 'user-jeeber-010',
          cashAmount: 14.5,
          currency: 'USD',
          status: 'AtDoor',
        ),
      ),
    );

Widget _deliveryReceiptNetworkError(BuildContext _) => DeliveryReceiptScreen(
      deliveryId: 'demo-delivery-003',
      repository: FakeDeliveryReceiptRepository(
        fetchFailure: DeliveryReceiptFailure.network,
      ),
    );

// ─────────────────────────── delivery_status ───────────────────────────

Widget _deliveryStatusMatched(BuildContext _) => DeliveryStatusScreen(
      deliveryId: 'demo-delivery-201',
      gateway: InMemoryDeliveryStatusGateway(
        seed: demoDeliverySnapshot(
          id: 'demo-delivery-201',
          stage: DeliveryStage.matched,
        ),
      ),
    );

Widget _deliveryStatusInTransit(BuildContext _) => DeliveryStatusScreen(
      deliveryId: 'demo-delivery-202',
      gateway: InMemoryDeliveryStatusGateway(
        seed: demoDeliverySnapshot(
          id: 'demo-delivery-202',
          stage: DeliveryStage.inTransit,
        ),
      ),
    );

Widget _deliveryStatusDelivered(BuildContext _) => DeliveryStatusScreen(
      deliveryId: 'demo-delivery-203',
      gateway: InMemoryDeliveryStatusGateway(
        seed: demoDeliverySnapshot(
          id: 'demo-delivery-203',
          stage: DeliveryStage.delivered,
        ).copyWith(lifecycle: DeliveryLifecycle.completed),
      ),
    );

Widget _deliveryStatusCancelled(BuildContext _) => DeliveryStatusScreen(
      deliveryId: 'demo-delivery-204',
      gateway: InMemoryDeliveryStatusGateway(
        seed: demoDeliverySnapshot(
          id: 'demo-delivery-204',
          stage: DeliveryStage.matched,
        ).copyWith(lifecycle: DeliveryLifecycle.cancelled),
      ),
    );

Widget _deliveryStatusStreamError(BuildContext _) => const DeliveryStatusScreen(
      deliveryId: 'demo-delivery-205',
      gateway: _ErrorDeliveryStatusGateway(),
    );

/// Local fake that fails the live stream — models a stream-lost transport
/// failure (no live gateway/websocket involved).
class _ErrorDeliveryStatusGateway implements DeliveryStatusGateway {
  const _ErrorDeliveryStatusGateway();

  @override
  Stream<DeliverySnapshot> watch(String deliveryId) =>
      Stream<DeliverySnapshot>.error(StateError('stream lost'));

  @override
  Future<CancellationOutcome> cancel(String deliveryId) async =>
      CancellationOutcome.networkError;
}

// ─────────────────────────── dispute_status ───────────────────────────

Widget _disputeStatusOpen(BuildContext _) => const DisputeStatusScreen(
      disputeId: 'dispute-demo-001',
      repository: _FakeDisputeStatusRepository(
        DisputeStatus(
          id: 'dispute-demo-001',
          state: DisputeState.open,
          orderRef: 'delivery-demo-001',
          evidence: DisputeEvidenceSummary(
            reason: 'damaged',
            comment: 'Box was crushed on arrival.',
            photoCount: 2,
            hasVoice: true,
            hasChatSnapshot: true,
            chatMessageCount: 6,
            timelineCount: 3,
          ),
        ),
      ),
    );

Widget _disputeStatusResolvedRefund(BuildContext _) =>
    const DisputeStatusScreen(
      disputeId: 'dispute-demo-002',
      repository: _FakeDisputeStatusRepository(
        DisputeStatus(
          id: 'dispute-demo-002',
          state: DisputeState.resolved,
          outcome: DisputeOutcome.refund,
          resolution: 'refund',
          note: 'Refund issued to the customer wallet.',
          refundAmount: 12.0,
          currency: 'USD',
          orderRef: 'delivery-demo-002',
          evidence: DisputeEvidenceSummary(
            reason: 'wrong_item',
            photoCount: 1,
            timelineCount: 4,
          ),
        ),
      ),
    );

Widget _disputeStatusNotFound(BuildContext _) => const DisputeStatusScreen(
      disputeId: 'dispute-demo-404',
      repository: EmptyDisputeStatusRepository(),
    );

class _FakeDisputeStatusRepository implements DisputeStatusRepository {
  const _FakeDisputeStatusRepository(this._status);

  final DisputeStatus _status;

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async => _status;
}

// ─────────────────────────── earnings ───────────────────────────

const EarningsSummary _demoEarningsSummary = EarningsSummary(
  totalCashEarned: 245.50,
  feesPaid: 24.55,
  currency: 'USD',
  deliveryCount: 12,
  memberSince: '2025-02-14',
  deliveries: [
    EarningsDeliveryItem(
      deliveryId: 'delivery-demo-101',
      date: '2026-07-01',
      cashCollected: 20.0,
      feePaid: 2.0,
      currency: 'USD',
    ),
    EarningsDeliveryItem(
      deliveryId: 'delivery-demo-102',
      date: '2026-06-30',
      cashCollected: 15.5,
      feePaid: 1.55,
      currency: 'USD',
    ),
  ],
);

const EarningsSummary _demoEarningsSummaryEmpty = EarningsSummary(
  totalCashEarned: 0,
  feesPaid: 0,
  currency: 'USD',
  deliveryCount: 0,
);

Widget _earningsLoaded(BuildContext _) => BlocProvider<EarningsCubit>(
      create: (_) => EarningsCubit(
        repository: const _FakeEarningsRepository(
          summary: _demoEarningsSummary,
        ),
        jeeberId: 'demo-jeeber-401',
      ),
      child: const EarningsDashboardScreen(),
    );

Widget _earningsEmpty(BuildContext _) => BlocProvider<EarningsCubit>(
      create: (_) => EarningsCubit(
        repository: const _FakeEarningsRepository(
          summary: _demoEarningsSummaryEmpty,
        ),
        jeeberId: 'demo-jeeber-402',
      ),
      child: const EarningsDashboardScreen(),
    );

Widget _earningsError(BuildContext _) => BlocProvider<EarningsCubit>(
      create: (_) => EarningsCubit(
        repository: const _FakeEarningsRepository(
          failure: EarningsErrorKind.network,
        ),
        jeeberId: 'demo-jeeber-403',
      ),
      child: const EarningsDashboardScreen(),
    );

class _FakeEarningsRepository implements EarningsRepository {
  const _FakeEarningsRepository({this.summary, this.failure});

  final EarningsSummary? summary;
  final EarningsErrorKind? failure;

  @override
  Future<EarningsSummary> fetchEarnings({
    required String jeeberId,
    EarningsPeriod period = EarningsPeriod.week,
  }) async {
    final failing = failure;
    if (failing != null) throw EarningsRepositoryException(failing);
    return summary ?? _demoEarningsSummary;
  }

  @override
  Future<String> exportEarningsPdf({
    required String jeeberId,
    EarningsPeriod period = EarningsPeriod.week,
  }) async =>
      '/tmp/demo-earnings.pdf';
}

// ─────────────────────────── escalate ───────────────────────────

Widget _escalateEmptyForm(BuildContext _) => BlocProvider<EscalateCubit>(
      create: (_) => EscalateCubit(
        repository: const _FakeEscalateRepository(),
        deliveryId: 'demo-delivery-501',
      ),
      child: const EscalateScreen(),
    );

Widget _escalateReasonSelected(BuildContext _) => BlocProvider<EscalateCubit>(
      create: (_) => EscalateCubit(
        repository: const _FakeEscalateRepository(),
        deliveryId: 'demo-delivery-502',
      )..setReason(EscalateReason.damaged),
      child: const EscalateScreen(),
    );

Widget _escalateSubmissionError(BuildContext _) => BlocProvider<EscalateCubit>(
      create: (_) => EscalateCubit(
        repository: const _FakeEscalateRepository(
          submitFailure: EscalateErrorKind.network,
        ),
        deliveryId: 'demo-delivery-503',
      )
        ..setReason(EscalateReason.fraud)
        ..submit(),
      child: const EscalateScreen(),
    );

class _FakeEscalateRepository implements EscalateRepository {
  const _FakeEscalateRepository({this.submitFailure});

  final EscalateErrorKind? submitFailure;

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) async {
    return const EscalateEvidence(
      chatSnapshotUrl: 'https://cdn.jeeb.app/chat/demo-snapshot.json',
      chatMessageCount: 8,
      timeline: [
        EscalateTimelineEntry(status: 'Ordered'),
        EscalateTimelineEntry(status: 'Picked'),
        EscalateTimelineEntry(status: 'InTransit'),
      ],
    );
  }

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const [],
    String? voicePath,
    EscalateEvidence evidence = EscalateEvidence.empty,
  }) async {
    final failing = submitFailure;
    if (failing != null) throw EscalateException(failing);
    return const EscalateResult(caseId: 'dispute-demo-501', status: 'open');
  }
}

// ─────────────────────────── goods_cost ───────────────────────────

Widget _goodsCostEnter(BuildContext _) =>
    const GoodsCostScreen(deliveryId: 'demo-delivery-301');
