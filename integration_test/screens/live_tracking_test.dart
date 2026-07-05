// Isolated native UI test — live-tracking (LiveTrackingScreen, JM-032). The
// screen reads a LiveTrackingCubit, so we host it in a BlocProvider over an
// in-memory LiveTrackingRepository returning a fixed in-transit snapshot. The
// map is rendered as the deterministic placeholder (useLiveMap:false — the
// keyless GoogleMap is never mounted), so we capture the real chrome: pinned
// summary header, 4-step stepper, jeeber card, tracking panel, dispute/no-show
// bar. A far-future pollInterval keeps the cubit's periodic timer from firing
// during the pump; addTearDown cancels it.
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/delivery_status/domain/jeeber_summary.dart';
import 'package:jeeb_mobile/features/live_tracking/application/live_tracking_cubit.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/delivery_tracking_info.dart';
import 'package:jeeb_mobile/features/live_tracking/domain/live_tracking_repository.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/live_tracking_screen.dart';

import '../support/screen_harness.dart';

const String _deliveryId = 'DLV-770001';

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
      deliveryId: _deliveryId,
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
    deliveryId: _deliveryId,
    // Effectively disable the auto-poll so no timer fires during the pump.
    pollInterval: const Duration(days: 365),
  );
  return BlocProvider<LiveTrackingCubit>.value(
    value: cubit,
    child: const LiveTrackingScreen(deliveryId: _deliveryId),
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('live-tracking: in-transit stepper + overlays (en)',
      (tester) async {
    await pumpAndShoot(tester, binding, _tracking(), 'live-tracking__in-transit');
  });

  testWidgets('live-tracking: in-transit stepper + overlays (ar)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _tracking(),
      'live-tracking__in-transit-ar',
      locale: const Locale('ar'),
    );
  });
}
