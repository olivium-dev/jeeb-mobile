import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:jeeb_mobile/features/cancellation/domain/cancellation_repository.dart';
import 'package:jeeb_mobile/features/cancellation/domain/cancellation_result.dart';
import 'package:jeeb_mobile/features/cancellation/presentation/cancellation_screen.dart';
import 'package:jeeb_mobile/features/deep_link_targets/delivery_detail_screen.dart';
import 'package:jeeb_mobile/features/deep_link_targets/rating_prompt_screen.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt.dart';
import 'package:jeeb_mobile/features/delivery_receipt/domain/delivery_receipt_repository.dart';
import 'package:jeeb_mobile/features/delivery_receipt/presentation/delivery_receipt_screen.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/jeeber_summary.dart';
import 'package:jeeb_mobile/features/escalate/application/escalate_cubit.dart';
import 'package:jeeb_mobile/features/escalate/domain/escalate_repository.dart';
import 'package:jeeb_mobile/features/escalate/presentation/escalate_screen.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';
import 'package:jeeb_mobile/features/order_summary/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_summary/domain/order_summary_repository.dart';
import 'package:jeeb_mobile/features/order_summary/presentation/order_summary_screen.dart';
import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_cubit.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_result.dart';
import 'package:jeeb_mobile/features/otp_handover/presentation/otp_handover_screen.dart';
import 'package:jeeb_mobile/features/rating/application/mutual_rating_cubit.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/features/rating/presentation/mutual_rating_screen.dart';
import 'package:jeeb_mobile/features/rating/presentation/rating_screen.dart';

import '../dev_screen_entry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// "Orders & Delivery" catalog group.
//
// One DevScreenEntry per screen; one DevScreenState per `testWidgets` case in
// the matching integration_test/screens/<file>_test.dart. Every inline fake
// repo / cubit fixture below is ported VERBATIM from those test files and
// privatised (leading underscore, file-local) — nothing is imported from test/
// or integration_test/. Navigation stays inside the screens; the dev preview
// host provides a Router ancestor and swallows stray taps, so no nav callbacks
// need stubbing here. Poll/clock timers are neutralised exactly as the tests do
// (a far-future pollInterval), keeping previews free of runaway timers.
// ─────────────────────────────────────────────────────────────────────────────

// ── Delivery Receipt (delivery_receipt_test.dart) ────────────────────────────

class _FakeReceiptRepo implements DeliveryReceiptRepository {
  const _FakeReceiptRepo(this._receipt);
  final DeliveryReceipt _receipt;
  @override
  Future<DeliveryReceipt> fetchReceipt(String deliveryId) async => _receipt;
  @override
  Future<void> confirmReceipt(DeliveryReceipt receipt) async {}
}

DeliveryReceiptScreen _receipt(DeliveryReceipt r) => DeliveryReceiptScreen(
      deliveryId: r.deliveryId,
      repository: _FakeReceiptRepo(r),
    );

// ── Order Summary (order_summary_test.dart) ──────────────────────────────────

class _FakeOrderSummaryRepo implements OrderSummaryRepository {
  const _FakeOrderSummaryRepo(this._summary);
  final OrderSummary _summary;
  @override
  Future<OrderSummary> fetchSummary(String deliveryId) async => _summary;
}

OrderSummaryScreen _summary(OrderSummary s) => OrderSummaryScreen(
      deliveryId: s.deliveryId,
      repository: _FakeOrderSummaryRepo(s),
    );

// ── Cancellation (cancellation_test.dart) ────────────────────────────────────

/// Inert repo — a submit is never triggered from the captured idle picker.
class _FakeCancellationRepo implements CancellationRepository {
  const _FakeCancellationRepo();

  @override
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) async =>
      const CancellationResult(
        deliveryId: 'DLV-1',
        weeklyCount: 1,
      );
}

CancellationScreen _cancellation({required bool isJeeber}) => CancellationScreen(
      deliveryId: 'DLV-1',
      isJeeber: isJeeber,
      repository: const _FakeCancellationRepo(),
    );

// ── Live Tracking (live_tracking_test.dart) ──────────────────────────────────

const String _trackingDeliveryId = 'DLV-770001';

/// Static repository serving one in-transit snapshot (no network, no ticks).
class _StaticTrackingRepository implements LiveTrackingRepository {
  _StaticTrackingRepository(this._info);

  final DeliveryTrackingInfo _info;

  @override
  Future<DeliveryTrackingInfo> fetchDeliveryStatus({
    required String deliveryId,
  }) async =>
      _info;
}

DeliveryTrackingInfo _inTransitInfo() => const DeliveryTrackingInfo(
      deliveryId: _trackingDeliveryId,
      currentStage: TrackingStage.inTransit,
      stageTimestamps: {},
      distanceLabel: '1.2 km',
      etaMinutes: 8,
      jeeber: JeeberSummary(displayName: 'Kamal H.', vehicleLabel: 'Scooter'),
      requestId: 'REQ-1',
      price: 12.5,
      currency: 'USD',
      jeeberName: 'Kamal H.',
      tier: 'express',
      itemSummary: 'Groceries from Blend',
    );

Widget _tracking() {
  final cubit = LiveTrackingCubit(
    repository: _StaticTrackingRepository(_inTransitInfo()),
    deliveryId: _trackingDeliveryId,
    // Effectively disable the auto-poll so no timer fires during the preview.
    pollInterval: const Duration(days: 365),
  );
  return BlocProvider<LiveTrackingCubit>.value(
    value: cubit,
    child: const LiveTrackingScreen(deliveryId: _trackingDeliveryId),
  );
}

// ── OTP Handover (otp_handover_test.dart) ────────────────────────────────────

/// Serves a fixed handover code to the client leg (or an SMS-trigger shape when
/// [code] is null) and accepts any Jeeber OTP submit.
class _FakeOtpRepo implements OtpHandoverRepository {
  const _FakeOtpRepo({this.code});
  final String? code;

  @override
  Future<OtpFetchResult> fetchHandoverCode({required String deliveryId}) async =>
      OtpFetchResult(code: code, smsTriggered: code == null);

  @override
  Future<OtpHandoverResult> submitOtp({
    required String deliveryId,
    required String otp,
  }) async =>
      const OtpHandoverResult(success: true);
}

Widget _otpHandover({required bool isClient, String? code}) {
  final cubit = OtpHandoverCubit(
    repository: _FakeOtpRepo(code: code),
    deliveryId: 'DLV-770001',
    isClient: isClient,
  );
  return BlocProvider<OtpHandoverCubit>.value(
    value: cubit,
    child: OtpHandoverScreen(deliveryId: 'DLV-770001', isClient: isClient),
  );
}

// ── Mutual Rating (mutual_rating_test.dart) ──────────────────────────────────

/// No-op rating repo — a successful submit is fire-and-forget on this terminal.
class _NoopRatingRepo implements RatingRepository {
  const _NoopRatingRepo();
  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {}
  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async =>
      throw UnimplementedError();
}

/// Always-failing repo so a submit lands the cubit in the error phase.
class _ThrowingRatingRepo implements RatingRepository {
  const _ThrowingRatingRepo();
  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async =>
      throw const RatingRepositoryException(RatingFailure.network);
  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async =>
      throw UnimplementedError();
}

MutualRatingCubit _mutualRatingCubit(RatingRepository repo) => MutualRatingCubit(
      repository: repo,
      deliveryId: 'del-client-001',
      isClient: true,
    );

Widget _mutualRatingHost(MutualRatingCubit cubit) =>
    BlocProvider<MutualRatingCubit>.value(
      value: cubit,
      child: const MutualRatingScreen(),
    );

Widget _mutualRatingInput(int stars) {
  final cubit = _mutualRatingCubit(const _NoopRatingRepo())..setStars(stars);
  return _mutualRatingHost(cubit);
}

Widget _mutualRatingError() {
  final cubit = _mutualRatingCubit(const _ThrowingRatingRepo())..setStars(4);
  // Live preview: fire submit (self-catches) so the cubit settles into error;
  // the screen rebuilds into the error phase once the future resolves.
  unawaited(cubit.submit());
  return _mutualRatingHost(cubit);
}

// ── Escalate (escalate_test.dart) ────────────────────────────────────────────

/// In-memory EscalateRepository: resolves auto-attached evidence, and
/// optionally fails submit to drive the error view.
class _FakeEscalateRepo implements EscalateRepository {
  const _FakeEscalateRepo({this.failWith});
  final EscalateErrorKind? failWith;

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) async =>
      const EscalateEvidence(
        chatSnapshotUrl: 'https://cdn.jeeb.app/snapshots/conv-1.html',
        chatMessageCount: 3,
        timeline: [
          EscalateTimelineEntry(status: 'Ordered'),
          EscalateTimelineEntry(status: 'Picked'),
          EscalateTimelineEntry(status: 'InTransit'),
        ],
      );

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const [],
    String? voicePath,
    EscalateEvidence evidence = EscalateEvidence.empty,
  }) async {
    if (failWith != null) throw EscalateException(failWith!);
    return const EscalateResult(caseId: 'dispute-999', status: 'open');
  }
}

EscalateCubit _escalateCubit({
  EscalateReason? reason,
  EscalateErrorKind? failWith,
}) {
  final cubit = EscalateCubit(
    repository: _FakeEscalateRepo(failWith: failWith),
    deliveryId: 'dlv-1',
  );
  if (reason != null) cubit.setReason(reason);
  return cubit;
}

Widget _escalateHost(EscalateCubit cubit) => BlocProvider<EscalateCubit>.value(
      value: cubit,
      child: const EscalateScreen(),
    );

Widget _escalateForm(EscalateReason reason) =>
    _escalateHost(_escalateCubit(reason: reason));

Widget _escalateError() {
  final cubit = _escalateCubit(
    reason: EscalateReason.noShow,
    failWith: EscalateErrorKind.server,
  );
  // Live preview: fire submit (self-catches) so the cubit settles into error.
  unawaited(cubit.submit());
  return _escalateHost(cubit);
}

// ─────────────────────────────────────────────────────────────────────────────
// Entries — sorted by title.
// ─────────────────────────────────────────────────────────────────────────────

final List<DevScreenEntry> ordersDeliveryScreens = <DevScreenEntry>[
  // Cancellation
  DevScreenEntry(
    id: 'delivery-cancel',
    title: 'Cancellation',
    group: 'Orders & Delivery',
    keywords: const <String>[
      'cancel',
      'cancellation',
      'refund',
      'fee',
      'reasons',
      'T-MOB-024',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'client',
        label: 'Client reasons (EN)',
        locale: const Locale('en'),
        builder: (_) => _cancellation(isJeeber: false),
      ),
      DevScreenState(
        id: 'jeeber',
        label: 'Jeeber reasons (EN)',
        locale: const Locale('en'),
        builder: (_) => _cancellation(isJeeber: true),
      ),
      DevScreenState(
        id: 'ar',
        label: 'Client reasons (AR)',
        locale: const Locale('ar'),
        builder: (_) => _cancellation(isJeeber: false),
      ),
    ],
  ),

  // Delivery Detail
  DevScreenEntry(
    id: 'delivery-detail',
    title: 'Delivery Detail',
    group: 'Orders & Delivery',
    keywords: const <String>[
      'order',
      'delivery',
      'detail',
      'action hub',
      'contact',
      'deep link',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'hub',
        label: 'Action hub (EN)',
        locale: const Locale('en'),
        builder: (_) => const DeliveryDetailScreen(deliveryId: 'DLV-1'),
      ),
      DevScreenState(
        id: 'ar',
        label: 'Action hub (AR)',
        locale: const Locale('ar'),
        builder: (_) => const DeliveryDetailScreen(deliveryId: 'DLV-1'),
      ),
    ],
  ),

  // Delivery Receipt
  DevScreenEntry(
    id: 'delivered-receipt',
    title: 'Delivery Receipt',
    group: 'Orders & Delivery',
    keywords: const <String>[
      'receipt',
      'delivered',
      'cash',
      'confirm',
      'proof',
      'JM-033',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'with-amount',
        label: 'Known cash amount (EN)',
        locale: const Locale('en'),
        builder: (_) => _receipt(const DeliveryReceipt(
          deliveryId: 'del-client-001',
          jeeberName: 'Karim',
          cashAmount: 45.0,
          currency: 'USD',
          status: 'AtDoor',
        )),
      ),
      DevScreenState(
        id: 'no-amount',
        label: 'Amount unknown, degraded (EN)',
        locale: const Locale('en'),
        builder: (_) => _receipt(const DeliveryReceipt(
          deliveryId: 'del-client-002',
          jeeberName: 'Hadi',
          cashAmount: null,
          currency: 'USD',
          status: 'AtDoor',
        )),
      ),
      DevScreenState(
        id: 'ar',
        label: 'Known cash amount (AR)',
        locale: const Locale('ar'),
        builder: (_) => _receipt(const DeliveryReceipt(
          deliveryId: 'del-client-001',
          jeeberName: 'Karim',
          cashAmount: 45.0,
          currency: 'USD',
          status: 'AtDoor',
        )),
      ),
    ],
  ),

  // Escalate
  DevScreenEntry(
    id: 'escalate',
    title: 'Escalate',
    group: 'Orders & Delivery',
    keywords: const <String>[
      'dispute',
      'escalate',
      'evidence',
      'complaint',
      'support',
      'JM-060',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'form',
        label: 'Input form, reason selected (EN)',
        locale: const Locale('en'),
        builder: (_) => _escalateForm(EscalateReason.damaged),
      ),
      DevScreenState(
        id: 'error',
        label: 'Server error state (EN)',
        locale: const Locale('en'),
        builder: (_) => _escalateError(),
      ),
      DevScreenState(
        id: 'ar',
        label: 'Input form (AR)',
        locale: const Locale('ar'),
        builder: (_) => _escalateForm(EscalateReason.fraud),
      ),
    ],
  ),

  // Live Tracking
  DevScreenEntry(
    id: 'live-tracking',
    title: 'Live Tracking',
    group: 'Orders & Delivery',
    keywords: const <String>[
      'tracking',
      'map',
      'live',
      'in-transit',
      'stepper',
      'eta',
      'JM-032',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'in-transit',
        label: 'In-transit stepper + overlays (EN)',
        locale: const Locale('en'),
        builder: (_) => _tracking(),
      ),
      DevScreenState(
        id: 'in-transit-ar',
        label: 'In-transit stepper + overlays (AR)',
        locale: const Locale('ar'),
        builder: (_) => _tracking(),
      ),
    ],
  ),

  // Mutual Rating
  DevScreenEntry(
    id: 'mutual-rating',
    title: 'Mutual Rating',
    group: 'Orders & Delivery',
    keywords: const <String>[
      'rating',
      'stars',
      'review',
      'mutual',
      'feedback',
      'JM-034',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'input',
        label: 'Inputting (EN)',
        locale: const Locale('en'),
        builder: (_) => _mutualRatingInput(4),
      ),
      DevScreenState(
        id: 'input-ar',
        label: 'Inputting (AR)',
        locale: const Locale('ar'),
        builder: (_) => _mutualRatingInput(5),
      ),
      DevScreenState(
        id: 'error',
        label: 'Submit failure error state (EN)',
        locale: const Locale('en'),
        builder: (_) => _mutualRatingError(),
      ),
    ],
  ),

  // Order Summary
  DevScreenEntry(
    id: 'order-summary',
    title: 'Order Summary',
    group: 'Orders & Delivery',
    keywords: const <String>[
      'order',
      'summary',
      'price',
      'jeeber',
      'eta',
      'JM-031',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'rated',
        label: 'Rated jeeber (EN)',
        locale: const Locale('en'),
        builder: (_) => _summary(const OrderSummary(
          deliveryId: 'del-client-001',
          requestId: 'req-client-001',
          conversationId: 'conv-001',
          price: 45.0,
          currency: 'USD',
          jeeberName: 'Karim',
          tier: 'express',
          jeeberRating: 4.8,
          jeeberRatingCount: 42,
          etaMinutes: 15,
          itemSummary: 'Pharmacy run — 2 items',
        )),
      ),
      DevScreenState(
        id: 'cold-start',
        label: 'Cold-start jeeber, no rating chip (EN)',
        locale: const Locale('en'),
        builder: (_) => _summary(const OrderSummary(
          deliveryId: 'del-client-002',
          requestId: 'req-client-002',
          conversationId: '',
          price: 18.0,
          currency: 'USD',
          jeeberName: 'Hadi',
          tier: 'standard',
          itemSummary: 'Grocery pickup',
        )),
      ),
      DevScreenState(
        id: 'ar',
        label: 'Rated jeeber (AR)',
        locale: const Locale('ar'),
        builder: (_) => _summary(const OrderSummary(
          deliveryId: 'del-client-001',
          requestId: 'req-client-001',
          conversationId: 'conv-001',
          price: 45.0,
          currency: 'USD',
          jeeberName: 'Karim',
          tier: 'express',
          jeeberRating: 4.8,
          jeeberRatingCount: 42,
          etaMinutes: 15,
          itemSummary: 'Pharmacy run — 2 items',
        )),
      ),
    ],
  ),

  // OTP Handover
  DevScreenEntry(
    id: 'otp-handover',
    title: 'OTP Handover',
    group: 'Orders & Delivery',
    keywords: const <String>[
      'otp',
      'handover',
      'code',
      'pickup',
      'verify',
      'T-MOB-018',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'client',
        label: 'Client code display (EN)',
        locale: const Locale('en'),
        builder: (_) => _otpHandover(isClient: true, code: '1234'),
      ),
      DevScreenState(
        id: 'jeeber',
        label: 'Jeeber code entry (EN)',
        locale: const Locale('en'),
        builder: (_) => _otpHandover(isClient: false),
      ),
      DevScreenState(
        id: 'ar',
        label: 'Client code display (AR)',
        locale: const Locale('ar'),
        builder: (_) => _otpHandover(isClient: true, code: '1234'),
      ),
    ],
  ),

  // Rating
  DevScreenEntry(
    id: 'feedback',
    title: 'Rating',
    group: 'Orders & Delivery',
    keywords: const <String>[
      'rating',
      'feedback',
      'stars',
      'review',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'customer',
        label: 'Customer rates jeeber (EN)',
        locale: const Locale('en'),
        builder: (_) => const RatingScreen(
          deliveryId: 'del-client-001',
          isClient: true,
          rateeName: 'Karim',
        ),
      ),
      DevScreenState(
        id: 'jeeber',
        label: 'Jeeber rates customer (EN)',
        locale: const Locale('en'),
        builder: (_) => const RatingScreen(
          deliveryId: 'del-jeeber-001',
          isClient: false,
          rateeName: 'Sami',
        ),
      ),
      DevScreenState(
        id: 'ar',
        label: 'Customer rates jeeber (AR)',
        locale: const Locale('ar'),
        builder: (_) => const RatingScreen(
          deliveryId: 'del-client-001',
          isClient: true,
          rateeName: 'Karim',
        ),
      ),
    ],
  ),

  // Rating Prompt
  DevScreenEntry(
    id: 'rating-prompt',
    title: 'Rating Prompt',
    group: 'Orders & Delivery',
    keywords: const <String>[
      'rating',
      'prompt',
      'placeholder',
      'coming soon',
    ],
    states: <DevScreenState>[
      DevScreenState(
        id: 'placeholder',
        label: 'Placeholder (EN)',
        locale: const Locale('en'),
        builder: (_) => const RatingPromptScreen(deliveryId: 'DLV-1'),
      ),
    ],
  ),
];
