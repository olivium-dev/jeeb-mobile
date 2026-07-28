import 'package:flutter/widgets.dart';

import 'app_resume_signals.dart';
import 'route_visibility.dart';

/// Signature for the one-shot a [RouteResumeRefetch] fires. It is handed the
/// State's OWN context — i.e. a context BELOW the provider the host screen
/// creates — so the callback can `context.read<SomeCubit>()` exactly the way
/// `_ActiveDeliveriesResumeRefetch` does.
typedef RouteResumeCallback = void Function(BuildContext context);

/// The RESUME backstop for a full-screen ROUTE.
///
/// ## The defect this exists to remove (N8 / N9, b02)
///
/// The polling→push conversion deleted the 5 s `Stream.periodic` that used to
/// drive `NoOfferTimeoutScreen` (N9) and `ClientOffersScreen` (N8). That poll
/// was never a feature — it was the implicit SELF-HEAL, and nothing replaced
/// it. Both screens were left with exactly two inbound triggers: `cubit.load()`
/// at mount, and the push bus.
///
/// The push bus does not cover a backgrounded app. Only
/// `FirebaseMessaging.onMessage` is wired to it
/// (`firebase_messaging_transport.dart`); the background isolate does not touch
/// the bus, and `app.dart` does not replay a refresh on resume. So a
/// `newOffer` / `delivery` push that lands while the process is BACKGROUNDED
/// reaches nothing, and a user who returns to the app WITHOUT tapping the
/// notification sits on a permanently stale screen. On N9 that is worse than a
/// visibly broken screen: `WaitingCubit.tick()` keeps the countdown moving, so
/// frozen data looks live.
///
/// This is the owner's 2026-07-28 architecture ruling applied verbatim — a
/// polled value "should be pulled once and handled locally, you should pull it
/// each time you open the screen". Mount AND resume. This widget is the resume
/// half.
///
/// ## Why it is not a poll
///
/// Nothing here is timed. There is no interval, no retry and no clock: the only
/// inputs are the platform's genuine-resume notification and the user's own
/// navigation. `armed-poll-inventory.py` counts zero new sites for it.
///
/// ## Shape
///
/// It mirrors `_ActiveDeliveriesResumeRefetch` (`dashboard_tab.dart`) — same
/// bus, same mixin, "one surface, one subscription" — deliberately, because a
/// second `didChangeAppLifecycleState` override is the multiplier
/// [AppResumeSignals] was built to remove (the measured 60-reads-in-2 s storm).
///
/// The difference is only WHERE visibility comes from. The dashboard card lives
/// in a shell tab, so its host ANDs `TabVisibility` with
/// [RouteVisibilityScope]. A pushed route has no tab; its equivalent question is
/// "is my route still the one on top", which [ModalRoute.isCurrent] answers
/// without needing the `appRouteObserver` to be installed. Both terms are ANDed
/// here so an adopter inside a shell subtree keeps the shell's answer too;
/// [RouteVisibilityScope.isOnTop] defaults to `true` when no scope is present,
/// so the extra term is inert for a plain pushed route.
///
/// ## Deferral, not suppression
///
/// A resume that lands while the screen is BURIED (another route, or a modal
/// sheet, pushed on top) issues no read — those are pixels nobody can see, and
/// reading for them is the fan-out `DeferredRefreshGate` was written to stop.
/// But it is not dropped either: dropping it would leave the screen showing a
/// pre-resume snapshot with no error, which is invisible on the device and in a
/// screenshot. The debt is recorded as a BOOLEAN and paid with exactly ONE read
/// when the route is on top again — N resumes while buried cost one read, not
/// N.
///
/// ## Coalescing
///
/// Two independent floors, both already in the tree, are composed rather than
/// re-implemented:
///
///   * [AppResumeSignals] applies the genuine-resume filter (an `inactive →
///     resumed` focus flap is not a trip) and a rate floor with a trailing
///     edge, so a burst of platform notifications collapses;
///   * the target cubit's own in-flight latch drops a resume that arrives while
///     its read is still on the wire, so a trailing emission landing inside a
///     round trip costs zero extra reads.
///
/// Composed, a rapid background/foreground flap produces ONE fetch, not N.
class RouteResumeRefetch extends StatefulWidget {
  const RouteResumeRefetch({
    super.key,
    required this.onResume,
    required this.child,
  });

  /// The one-shot to fire. Called at most once per accepted resume, and only
  /// while the host route is on top.
  final RouteResumeCallback onResume;

  /// Unmodified feature subtree — this widget renders nothing of its own.
  final Widget child;

  @override
  State<RouteResumeRefetch> createState() => _RouteResumeRefetchState();
}

class _RouteResumeRefetchState extends State<RouteResumeRefetch>
    with ResumeRefetchMixin {
  /// The route this subtree lives on. Captured in [didChangeDependencies]
  /// rather than looked up at resume time so no inherited-widget lookup happens
  /// outside the framework's own dependency phases.
  ModalRoute<Object?>? _route;

  /// The enclosing [RouteVisibilityScope]'s answer, or `true` when there is no
  /// scope (a pushed route, a bare widget test).
  bool _scopeOnTop = true;

  /// A resume arrived while the screen was buried and has not been paid yet.
  /// Boolean, not a counter: N missed resumes describe ONE snapshot to catch up
  /// to, and the target re-reads the whole snapshot.
  bool _pending = false;

  /// Whether the host route is currently the one the user can see.
  ///
  /// Deliberately no `debugVisible` / `debugPending` seam: both are inferable
  /// from behaviour, and the discriminating test — pop back WITHOUT a resume
  /// first, and nothing must read — is the one a state-flag assertion could
  /// not have made (G23.1: a flag proves shape, only behaviour proves power).
  bool get _isVisible => _scopeOnTop && (_route?.isCurrent ?? true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of<Object?>(context);
    _scopeOnTop = RouteVisibilityScope.isOnTop(context);
    // `_ModalScopeStatus.updateShouldNotify` fires on an `isCurrent` flip, so
    // this runs again the moment the route above us pops — which is where a
    // deferred resume is paid.
    _payDebt();
  }

  /// Called at most once per [AppResumeSignals.minInterval], and only after the
  /// app genuinely left and re-entered the foreground.
  @override
  void onAppResumed() {
    if (!_isVisible) {
      _pending = true;
      return;
    }
    widget.onResume(context);
  }

  void _payDebt() {
    if (!_pending || !_isVisible) return;
    _pending = false;
    // Direct, NOT via `addPostFrameCallback`. The twins on the active-delivery
    // and live-tracking routes record why: a post-frame callback registered
    // while the scheduler is idle does not itself schedule a frame, so on a
    // quiescent screen (which these are, now the polls are gone) the refetch
    // waits for something that never comes. The `mounted` guard the deferral
    // would have bought is already provided by [ResumeRefetchMixin].
    widget.onResume(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
