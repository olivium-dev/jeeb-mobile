// Designed states for the jeeber active-deliveries band — ONE source of truth
// for the failure/stalled rungs the catalog and the previews both mount.

import 'dart:async';

import '../../../core/network/app_failure.dart';
import '../../../features/jeeber_active_deliveries/application/active_deliveries_cubit.dart';
import '../../../features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import '../../../features/jeeber_active_deliveries/domain/active_delivery_summary.dart';

/// Throws the classified failure — the band's cold-failure rung (ES-03).
class FailingActiveDeliveriesRepository implements ActiveDeliveriesRepository {
  const FailingActiveDeliveriesRepository(this.failure);

  final AppFailure failure;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async => throw failure;
}

/// Never answers — the read is still in flight, so the band stays collapsed.
class StalledActiveDeliveriesRepository implements ActiveDeliveriesRepository {
  const StalledActiveDeliveriesRepository();

  @override
  Future<List<ActiveDeliverySummary>> listActive() =>
      Completer<List<ActiveDeliverySummary>>().future;
}

/// A cubit already settled on the failed phase, with no read in flight.
ActiveDeliveriesCubit failedActiveDeliveriesCubit(AppFailure failure) =>
    ActiveDeliveriesCubit(
      repository: FailingActiveDeliveriesRepository(failure),
    )..start();
