// Designed states for `CancellationScreen` — ONE source of truth, two
// consumers.
//
//   lib/devtool/catalog/entries/batch_02_entries.dart
//       the designer-facing, on-device Screen Catalog
//   lib/features/cancellation/presentation/cancellation_screen.dart
//       the JEEB PREVIEWS section at its bottom
//
// The catalog owned a private `_CatalogCancellationRepository` and spelled out
// the three designed states inline. Copying that into the preview section would
// have given the two surfaces two different notions of "the cancellation
// screen, mid-submit", free to drift; every fake and every state below is now
// named once and imported by both.
//
// ## The screen has exactly TWO seams, and they bound what can be a state
//
// `CancellationScreen` takes `repository` (test/catalog override, else GetIt)
// and `initialState` (the DT-04 seam that presets the cubit). Everything else
// that decides what is on screen lives in `_CancellationViewState._selectedReason`
// — private `State` field, no constructor argument — so:
//
//  * the SELECTED-reason rendering, and with it the free-text
//    `cancellation_other_field` that `selectedReason == 'other'` reveals and
//    the ENABLED submit button, cannot be seeded by either surface. They are
//    reachable only by tapping, which the canvas and the catalog both allow and
//    a still card cannot show.
//  * `CancellationSuccess` / `CancellationTooLate` / `CancellationError` have
//    no rendering to seed. All three are delivered through a `BlocListener`,
//    which fires on state CHANGES only — never on the state a cubit is
//    constructed in — so an `initialState:` of any of them renders the plain
//    reason picker. [CancellationScreenRejectingRepository] and
//    [CancellationScreenTooLateRepository] exist for that reason: they make the
//    terminal states reachable the way the user reaches them, by submitting.
//
// Both are documented at the state constants below rather than worked around.
//
// ## Network-free by construction
//
// Every repository here answers from a const expression, throws, or never
// completes. None of them builds a Dio client or touches GetIt, so neither
// surface depends on the `CatalogNetworkGuard` its host installs — that is a
// net, not the plan.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import 'package:jeeb_mobile/features/cancellation/domain/cancellation_repository.dart';
import 'package:jeeb_mobile/features/cancellation/domain/cancellation_result.dart';
import 'package:jeeb_mobile/features/cancellation/presentation/cubit/cancellation_state.dart';

/// The delivery every state cancels.
///
/// Nothing on screen renders it — the picker shows a prompt, four or five
/// reasons and a button, and never the order it belongs to — so this is a
/// wire-level detail only. Shared so both surfaces describe the same delivery,
/// and so the preview's router can mount the real `/orders/:id/cancel` path.
const String cancellationScreenDeliveryId = 'delivery-demo-1';

/// A cancel that SUCCEEDS, returning a plausible D5 `CancelDeliveryResponse`.
///
/// `weeklyCount: 1` is this user's first cancellation of the ISO week. Nothing
/// on the success sheet renders it today (`CancellationSuccessSheet` shows an
/// icon, one line of copy and a Done button), but it is what the gateway
/// returns and the fixture stays honest to the contract.
///
/// This is the repository behind the two picker states: a reviewer who taps
/// Confirm in the catalog or the canvas gets the real success sheet instead of
/// a crash.
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
///
/// Pairs with the seeded in-flight state so the phase is STABLE: the submit
/// button is disabled while loading, but a reviewer who reaches the state some
/// other way cannot move it on, and the "Cancelling…" label stays put for as
/// long as the surface is open.
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
///
/// Throws the typed [CancellationException] the data layer is contracted to
/// throw, never a raw `DioException`. The message is retained for diagnostics
/// and is NEVER rendered: `_onStateChange` maps every [CancellationError] onto
/// the localized `cancellationGenericError` snackbar, which is exactly the
/// leak-prevention this fixture is here to keep visible.
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
///
/// The one failure the user can do nothing about, and the only one with its own
/// copy (`cancellationTooLate`). Reached by submitting; see the file header for
/// why seeding [CancellationTooLate] shows nothing.
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
///
/// The screen is configured entirely by its constructor, so a state IS its
/// arguments — which is what lets the catalog and the preview canvas share the
/// state itself rather than a copy of the code that builds it. Each surface
/// then owns only its own chrome (a `CatalogState` label there, a caption and a
/// `Router` here).
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
///
/// Backed by the succeeding repository, so tapping a reason and then Confirm
/// walks all the way to the success sheet.
const CancellationScreenDesignedState cancellationScreenClientPickerState =
    CancellationScreenDesignedState(
  label: 'Client — reason picker',
  isJeeber: false,
  repository: CancellationScreenFakeRepository(),
);

/// The Jeeber's five reasons — a different list for the same screen.
///
/// Worth its own state twice over. It carries the longest shipping labels
/// ("Cannot complete delivery", "Prohibited item detected"), and it is
/// UNREACHABLE from the app today: `isJeeber` comes from the `?role=jeeber`
/// query parameter (`app_router.dart:860`) and the only in-app entry point,
/// `_CancelButton` in `delivery_detail_screen.dart:697`, pushes
/// `/orders/$deliveryId/cancel` with no query at all — so a Jeeber cancelling a
/// delivery is shown the client's "Changed my mind / Taking too long / Wrong
/// address".
const CancellationScreenDesignedState cancellationScreenJeeberPickerState =
    CancellationScreenDesignedState(
  label: 'Jeeber — reason picker',
  isJeeber: true,
  repository: CancellationScreenFakeRepository(),
);

/// `POST /v1/deliveries/{id}/cancel` in flight.
///
/// The only feedback is inside the button: the label swaps to
/// `deliveryActionCancellingLabel` ("Cancelling…") and it goes disabled. The
/// reason list stays live and stays tappable — nothing above the button says a
/// submission is happening.
const CancellationScreenDesignedState cancellationScreenSubmittingState =
    CancellationScreenDesignedState(
  label: 'Submitting',
  isJeeber: false,
  repository: CancellationScreenPendingRepository(),
  initialState: CancellationLoading(),
);

/// The 5xx lane, seeded — and therefore INVISIBLE.
///
/// Seeding [CancellationError] proves the negative the file header describes:
/// the state is delivered by a `BlocListener`, which never sees the state a
/// cubit was constructed in, so this renders as a pristine reason picker with
/// no snackbar, no inline error and no retry affordance. The rejecting
/// repository is attached so the same card reaches the real failure by
/// submitting.
const CancellationScreenDesignedState cancellationScreenRejectedState =
    CancellationScreenDesignedState(
  label: 'Rejected — 5xx (seeded)',
  isJeeber: false,
  repository: CancellationScreenRejectingRepository(),
  initialState: CancellationError('gateway 502 (fixture)'),
);

/// The 409 lane, seeded — invisible for the same reason as
/// [cancellationScreenRejectedState].
///
/// This is the one failure with dedicated copy ("Too late to cancel — your
/// Jeeber is already on the way."), and a seeded state shows none of it. The
/// copy is addressed to the CLIENT, which is why this state is the client's
/// four reasons rather than the Jeeber's five.
const CancellationScreenDesignedState cancellationScreenTooLateState =
    CancellationScreenDesignedState(
  label: 'Too late — 409 (seeded)',
  isJeeber: false,
  repository: CancellationScreenTooLateRepository(),
  initialState: CancellationTooLate(),
);
