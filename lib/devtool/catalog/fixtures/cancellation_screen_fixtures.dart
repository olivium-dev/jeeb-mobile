// Designed states for `CancellationScreen` — ONE source of truth, two

import 'dart:async';

import 'package:jeeb_mobile/features/cancellation/domain/cancellation_repository.dart';
import 'package:jeeb_mobile/features/cancellation/domain/cancellation_result.dart';
import 'package:jeeb_mobile/features/cancellation/presentation/cubit/cancellation_state.dart';

/// The delivery every state cancels.
/// Nothing on screen renders it — the picker shows a prompt, four or five
const String cancellationScreenDeliveryId = 'delivery-demo-1';

/// A cancel that SUCCEEDS, returning a plausible D5 `CancelDeliveryResponse`.
/// `weeklyCount: 1` is this user's first cancellation of the ISO week. Nothing
/// on the success sheet renders it today (`CancellationSuccessSheet` shows an
class CancellationScreenFakeRepository implements CancellationRepository {
  const CancellationScreenFakeRepository();

  @override
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) async =>
      CancellationResult(deliveryId: deliveryId, weeklyCount: 1);
}

/// A cancel that never lands, holding [CancellationLoading] open.
/// Pairs with the seeded in-flight state so the phase is STABLE: the submit
/// button is disabled while loading, but a reviewer who reaches the state some
class CancellationScreenPendingRepository implements CancellationRepository {
  const CancellationScreenPendingRepository();

  @override
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) =>
      Completer<CancellationResult>().future;
}

/// A cancel the gateway rejects with a 5xx — the generic-failure lane.
/// Throws the typed [CancellationException] the data layer is contracted to
/// throw, never a raw `DioException`. The message is retained for diagnostics
class CancellationScreenRejectingRepository implements CancellationRepository {
  const CancellationScreenRejectingRepository();

  @override
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) async =>
      throw const CancellationException('gateway 502 (fixture)');
}

/// A cancel the gateway rejects with 409 — the delivery is already picked up.
/// The one failure the user can do nothing about, and the only one with its own
/// copy (`cancellationTooLate`). Reached by submitting; see the file header for
class CancellationScreenTooLateRepository implements CancellationRepository {
  const CancellationScreenTooLateRepository();

  @override
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) async =>
      throw const CancellationTooLateException();
}

/// One designed state of `CancellationScreen`: the arguments that produce it.
/// The screen is configured entirely by its constructor, so a state IS its
/// arguments — which is what lets the catalog and the preview canvas share the
class CancellationScreenDesignedState {
  const CancellationScreenDesignedState({
    required this.label,
    required this.isJeeber,
    required this.repository,
    this.initialState,
    this.deliveryId = cancellationScreenDeliveryId,
  });

  /// The name BOTH surfaces show for this state.
  final String label;

  /// Which reason list `_reasons` returns — 4 codes for a client, 5 for a
  /// Jeeber, sharing only `other`.
  final bool isJeeber;

  /// The repository a submit lands on. Always a local fake above.
  final CancellationRepository repository;

  /// The DT-04 seam: the cubit state the screen starts in. Null starts idle,
  /// exactly as production does.
  final CancellationState? initialState;

  final String deliveryId;
}

/// The state every client opens: four reasons, nothing selected, submit
/// disabled.
const CancellationScreenDesignedState cancellationScreenClientPickerState =
    CancellationScreenDesignedState(
  label: 'Client — reason picker',
  isJeeber: false,
  repository: CancellationScreenFakeRepository(),
);

/// The Jeeber's five reasons — a different list for the same screen.
/// Worth its own state twice over. It carries the longest shipping labels
const CancellationScreenDesignedState cancellationScreenJeeberPickerState =
    CancellationScreenDesignedState(
  label: 'Jeeber — reason picker',
  isJeeber: true,
  repository: CancellationScreenFakeRepository(),
);

/// `POST /v1/deliveries/{id}/cancel` in flight.
/// The only feedback is inside the button: the label swaps to
const CancellationScreenDesignedState cancellationScreenSubmittingState =
    CancellationScreenDesignedState(
  label: 'Submitting',
  isJeeber: false,
  repository: CancellationScreenPendingRepository(),
  initialState: CancellationLoading(),
);

/// The 5xx lane, seeded — and therefore INVISIBLE.
/// Seeding [CancellationError] proves the negative the file header describes:
const CancellationScreenDesignedState cancellationScreenRejectedState =
    CancellationScreenDesignedState(
  label: 'Rejected — 5xx (seeded)',
  isJeeber: false,
  repository: CancellationScreenRejectingRepository(),
  initialState: CancellationError('gateway 502 (fixture)'),
);

/// The 409 lane, seeded — invisible for the same reason as
/// [cancellationScreenRejectedState].
const CancellationScreenDesignedState cancellationScreenTooLateState =
    CancellationScreenDesignedState(
  label: 'Too late — 409 (seeded)',
  isJeeber: false,
  repository: CancellationScreenTooLateRepository(),
  initialState: CancellationTooLate(),
);
