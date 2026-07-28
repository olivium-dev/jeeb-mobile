import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/lifecycle/deferred_refresh_gate.dart';
import '../../../core/lifecycle/polling_visibility.dart';
import '../domain/active_deliveries_repository.dart';
import '../domain/active_delivery_summary.dart';

/// Load phase for the jeeber active-deliveries banner.
enum ActiveDeliveriesPhase { loading, loaded }

/// State emitted by [ActiveDeliveriesCubit].
class ActiveDeliveriesState extends Equatable {
  const ActiveDeliveriesState({
    this.phase = ActiveDeliveriesPhase.loading,
    this.deliveries = const <ActiveDeliverySummary>[],
  });

  final ActiveDeliveriesPhase phase;
  final List<ActiveDeliverySummary> deliveries;

  bool get hasDeliveries => deliveries.isNotEmpty;

  ActiveDeliveriesState copyWith({
    ActiveDeliveriesPhase? phase,
    List<ActiveDeliverySummary>? deliveries,
  }) => ActiveDeliveriesState(
    phase: phase ?? this.phase,
    deliveries: deliveries ?? this.deliveries,
  );

  @override
  List<Object?> get props => [phase, deliveries];
}

/// Drives the jeeber's "active deliveries" surface (iter6 real-flow blocker
/// fix). Loads the accepted/assigned deliveries from
/// `GET /v1/deliveries?role=jeeber`.
///
/// ## N2 — PUSH-DRIVEN. The 60 s safety-net poll is DELETED.
///
/// There is no clock in this class any more. Every read is caused by one of
/// exactly three things, and the shape is the owner's 2026-07-28 architecture
/// ruling applied verbatim (the same shape `client_offers_cubit` and
/// `waiting_cubit` already ship):
///
///   1. **mount** — [start] fetches ONCE at create time;
///   2. **resume** — [refreshOnResume], driven by `AppResumeSignals` from the
///      widget layer (`dashboard_tab.dart`), fetches once when the user comes
///      back to the app;
///   3. **push** — a `delivery` transition or an `offer_accepted` on
///      [refreshSignals].
///
/// Legs 1 and 2 are the BACKSTOP and are not optional: a dropped push costs
/// freshness until the next time the dashboard is opened or the app resumed,
/// instead of leaving a permanently wrong card. Both run through the same
/// [DeferredRefreshGate], so an off-screen dashboard neither reads on push nor
/// reads on resume — it records ONE boolean debt and pays it with ONE read when
/// the jeeber looks at it again.
///
/// ## Why deleting the poll is safe now, and was not before
///
/// #190 recorded the correct blocker: the gateway→push-service leg was live
/// (12/12 `DeliveryStatusPushNotifier` emissions matched a same-second
/// `POST /api/v1/sent-payload/user/{id}`, all `201`) but a `201` is an
/// ACCEPTANCE counter, not a delivery signal (I-04), and receiver-side arrival
/// had never been witnessed for this category.
///
/// ⚠️ SCOPE OF WHAT THE DEVICE RUN ON THIS BRANCH ACTUALLY PROVED, stated
/// precisely because overclaiming it is the failure this file has already had
/// once. On a two-phone run (`N234-RECORD.md` §4) the `chat` category was
/// witnessed END TO END — send → `POST /api/v1/sent-payload/user/{id}` →
/// the RECIPIENT's re-pull 4 s later → the message rendered on the recipient's
/// screen — and this surface's own poll was proved gone (zero
/// `GET /v1/deliveries?role=jeeber` across a 7.5-minute idle window with a
/// gateway-internal control still ticking in the same capture). A `delivery`-
/// category push was NOT independently witnessed driving THIS card on hardware
/// in that run: no status transition was available to fire without consuming
/// the live delivery fixture.
///
/// What carries the gap instead, and it is weaker than a device witness: the
/// bus, the topic routing and the gate this cubit uses are the SAME code the
/// chat leg exercised live, and the push→one-read behaviour is pinned by
/// `test/features/polling_elimination/` (RED first, transcripts filed). If a
/// `delivery` push is later found not to arrive, the failure mode here is
/// bounded by the mount/resume one-shot below — a stale card until the jeeber
/// next opens the dashboard, not a permanently wrong one.
///
/// Delivery-status notifications DO publish on this bus and DO reach this
/// subscriber: `push_notification_handler.dart` maps
/// `NotificationCategory.delivery → {RefreshTopic.order}` and this cubit's own
/// subscription is `{RefreshTopic.order}` (`dashboard_tab.dart`). The retracted
/// "delivery-status push is inert" claim (`JEBV4-NEW-P1-delivery-status-push-
/// inert.md`) survived in this file's constructor body twelve lines below its
/// own retraction; it is gone from both places now.
class ActiveDeliveriesCubit extends Cubit<ActiveDeliveriesState>
    implements PollingVisibility {
  ActiveDeliveriesCubit({
    required ActiveDeliveriesRepository repository,
    Stream<void>? refreshSignals,
  }) : _repository = repository,
       super(const ActiveDeliveriesState()) {
    // b02 READ ECONOMICS — through a [DeferredRefreshGate]. The comment that
    // stood here read "the subscription remains independent of polling
    // visibility so a hidden dashboard still refreshes", and that reasoning is
    // what put a `GET /v1/deliveries?role=jeeber` on the wire for a card behind
    // the active-delivery route. The gate keeps the guarantee the comment was
    // protecting — a hidden dashboard is NEVER left stale — while paying for it
    // once, when the dashboard is looked at again, instead of on every push.
    _refreshGate = DeferredRefreshGate(
      onRefresh: refresh,
      signals: refreshSignals,
      debugLabel: 'ActiveDeliveriesCubit',
    );
  }

  final ActiveDeliveriesRepository _repository;
  late final DeferredRefreshGate _refreshGate;

  /// Mount latch. Was `_poller.isStarted`; the poller is gone and [start] still
  /// has to be idempotent because the dashboard `..start()`s at create time and
  /// a rebuild must not re-fetch.
  bool _started = false;

  @visibleForTesting
  bool get debugStarted => _started;

  /// Reads this cubit has actually issued. The read budget a device run and a
  /// widget test both assert on — "one push → exactly one fetch", and "five
  /// minutes idle → zero".
  @visibleForTesting
  int get debugRefreshCount => _refreshCount;
  int _refreshCount = 0;

  /// The MOUNT one-shot. Idempotent — a second call is a no-op so the dashboard
  /// can `..start()` at create-time without double-fetching.
  void start() {
    if (_started) return;
    _started = true;
    unawaited(refresh());
  }

  /// The RESUME one-shot. Driven by `AppResumeSignals` at the widget layer, not
  /// by a lifecycle observer here — one app-wide, coalesced, genuine-resume bus
  /// rather than a per-cubit `didChangeAppLifecycleState`, which is the storm
  /// `AppResumeSignals` exists to cap.
  ///
  /// Goes through the gate, so a resume that lands while the dashboard is off
  /// screen is DEFERRED (one debt) rather than paid for pixels nobody sees.
  void refreshOnResume() => _refreshGate.signal();

  /// Surface visibility. Drives the push-refresh gate ONLY — there is no poller
  /// left to latch. An off-screen dashboard reads nothing and catches up with
  /// exactly one read when it comes back.
  @override
  void setPollingVisible(bool visible) =>
      _refreshGate.setPollingVisible(visible);

  /// SINGLE FLIGHT (b02 wave D). This cubit has THREE independent triggers —
  /// mount, resume and the push bus — and none of them coordinates with the
  /// others. A jeeber whose offer is accepted
  /// receives `offer_accepted` and, moments later, the first `type=delivery`
  /// transition: two bus events well inside one `GET /v1/deliveries?role=jeeber`
  /// round trip. Overlapping, the later-issued read can complete FIRST and
  /// paint the card from the older snapshot — the accepted delivery flickers,
  /// or briefly disappears. A clock alone could never produce that.
  bool _refreshInFlight = false;

  Future<void> refresh() async {
    if (isClosed || _refreshInFlight) return;
    _refreshInFlight = true;
    _refreshCount++;
    try {
      final deliveries = await _repository.listActive();
      if (isClosed) return;
      emit(
        state.copyWith(
          phase: ActiveDeliveriesPhase.loaded,
          deliveries: deliveries,
        ),
      );
    } finally {
      _refreshInFlight = false;
    }
  }

  @override
  Future<void> close() {
    unawaited(_refreshGate.dispose());
    return super.close();
  }
}
