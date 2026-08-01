import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/lifecycle/app_resume_signals.dart';
import '../../../core/notifications/application/push_refresh_signals.dart';
import '../../shell/tab_visibility.dart';
import '../application/order_history_cubit.dart';

/// Recovery triggers for the customer's Delivery-tab order list.
///
/// ## The defect this exists to remove
///
/// On real hardware during the live COD run the customer's status chip read
/// **"Pending"** while the jeeber had already moved to Picked / InTransit.
///
/// The chip is [OrderStatusChip] inside `OrderHistoryCard`, and it is the ONLY
/// customer-facing status chip in the app that can render "Pending"
/// (`orderHistoryStatusPending`). It was not stale because it was on the
/// push-only status axis. It was stale because it was on **no refresh axis at
/// all** — a stronger failure than the one that was suspected:
///
///  * `OrderHistoryScreen.initState` fires `initialLoad()` exactly once;
///  * the shell hosts its tabs in an `IndexedStack`
///    (`shell_screen.dart:128`), so `OrdersTab` never unmounts on a bottom-nav
///    switch and `initState` never runs again;
///  * `OrderHistoryCubit` takes no `refreshSignals`, so no `delivery` push
///    reaches it;
///  * nothing in the feature reads [AppResumeSignals] or [TabVisibility]
///    (`grep -c` over the screen, the cubit and the tab container: 0, 0, 0).
///
/// So for the whole life of the process the list held whatever the very first
/// read returned. The only recoveries were pull-to-refresh, tapping a filter
/// tab, or a cold restart — none of which a customer knows to do, and all of
/// which make the app look like it was lying rather than idle.
///
/// This is the same shape as the Earnings-tab staleness recorded in
/// `docs/execution/findings/U5-U6-triage-20260801.md`, with the same remedy the
/// finding names: the shell is ALREADY broadcasting the signal, the consumer is
/// what was missing.
///
/// ## The triggers, and why exactly these three
///
///  1. **Shell-tab refocus** — the customer navigates to Delivery to check on
///     their order. That is the moment the list must be true, and it is the
///     path the COD-run observation actually took.
///  2. **App resume** — via [ResumeRefetchMixin], so this inherits the
///     genuine-resume filter and the coalescing floor instead of adding a
///     thirteenth `didChangeAppLifecycleState` observer (the multiplier
///     [AppResumeSignals] exists to remove).
///  3. **An `order` push** — [RefreshTopic.order] is defined as exactly this
///     event ("a delivery/order advanced its own lifecycle state"), so a
///     customer sitting ON the tab while the jeeber transitions sees it move.
///     Gated on tab visibility: a push for a tab nobody is looking at would
///     truncate a paginated list the customer may still be scrolled into, and
///     it is not needed — trigger 1 pays that debt on the way back in, once.
///
/// Nothing here is timed. There is no interval, no retry and no clock; the
/// inputs are the platform's resume notification, the user's own navigation,
/// and an external push. `armed-poll-inventory.py` gains no site.
///
/// Outside the shell (bare widget tests, deep-link routes)
/// `TabVisibility.maybeOf` is null → treated as always-visible → the refocus
/// trigger degrades to a no-op, exactly like `FeedResumeRefetcher` and the
/// customer home.
class OrdersResumeRefetcher extends StatefulWidget {
  const OrdersResumeRefetcher({
    super.key,
    required this.child,
    this.refreshSignals,
  });

  final Widget child;

  /// Payload-less push→refetch bus. Defaults to the DI-registered
  /// [PushRefreshSignals] filtered to [RefreshTopic.order]; null in a bare test
  /// with no DI, which then simply never receives a push trigger.
  final Stream<void>? refreshSignals;

  @override
  State<OrdersResumeRefetcher> createState() => _OrdersResumeRefetcherState();
}

class _OrdersResumeRefetcherState extends State<OrdersResumeRefetcher>
    with ResumeRefetchMixin {
  /// Last-observed shell-tab visibility. `null` until the first
  /// [didChangeDependencies] so the very first frame never double-fetches —
  /// `OrderHistoryScreen.initState` owns the initial read.
  bool? _wasVisible;

  StreamSubscription<void>? _pushSub;

  @override
  void initState() {
    super.initState();
    final signals = widget.refreshSignals ??
        resolvePushRefreshStream(topics: const {RefreshTopic.order});
    _pushSub = signals?.listen((_) {
      // Visible-only: see the class doc, trigger 3.
      if (_wasVisible ?? true) _read();
    });
  }

  @override
  void dispose() {
    _pushSub?.cancel();
    _pushSub = null;
    super.dispose();
  }

  @override
  void onAppResumed() => _read();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isVisible = TabVisibility.maybeOf(context)?.isVisible ?? true;
    final becameVisible = _wasVisible == false && isVisible;
    _wasVisible = isVisible;
    if (!becameVisible) return;
    // THIS trigger, and only this one, fires mid-build — so it is the only one
    // that defers to a post-frame callback. A frame is guaranteed here: the
    // dependency changed, which means one is already being built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
  }

  /// One silent re-pull, mounted-guarded so a trigger landing during teardown
  /// never touches a defunct element.
  ///
  /// Deliberately NOT wrapped in `addPostFrameCallback`. The push and resume
  /// triggers arrive on a stream, outside any build, so there is no build-phase
  /// hazard to defer around — and deferring would introduce a real one: a
  /// post-frame callback only runs at the end of the NEXT frame, and
  /// `addPostFrameCallback` does not schedule one. A push landing on a
  /// foregrounded but visually idle list would therefore be queued behind a
  /// frame that never comes, and the fix would silently do nothing on device in
  /// exactly the situation it was written for. (Caught by the test: the
  /// push-while-visible case read the repository once, not twice.)
  ///
  /// [OrderHistoryCubit.refreshSilently] no-ops on a never-loaded tab and is
  /// single-flighted, so coinciding triggers collapse to one read.
  void _read() {
    if (!mounted) return;
    unawaited(context.read<OrderHistoryCubit>().refreshSilently());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
