import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../features/shell/tab_visibility.dart';
import '../lifecycle/route_visibility.dart';
import 'auth_loss_signals.dart';
import 'reviews_refresh_signals.dart';

/// One read on first visibility/refocus/resume; no timer or hidden-tab polling.
/// Signals arriving during a read collapse to one trailing visible read.
class ProfileReviewRefreshScope extends StatefulWidget {
  const ProfileReviewRefreshScope({
    super.key,
    required this.onRefresh,
    required this.onSessionEnded,
    required this.child,
    required this.source,
    required this.rateeId,
    this.profileChanges,
    this.reviewChanges,
    this.authLoss,
  });

  final Future<void> Function() onRefresh;
  final VoidCallback onSessionEnded;
  final Widget child;
  final Object source;
  final String? Function() rateeId;
  final Stream<void>? profileChanges;
  final Stream<ReviewsRefreshEvent>? reviewChanges;
  final Stream<AuthLossReason>? authLoss;

  @override
  State<ProfileReviewRefreshScope> createState() =>
      _ProfileReviewRefreshScopeState();
}

class _ProfileReviewRefreshScopeState extends State<ProfileReviewRefreshScope>
    with WidgetsBindingObserver {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _routeVisible = false;
  bool _foreground = true;
  bool _ended = false;
  bool _pending = true;
  bool _scheduled = false;
  bool _running = false;

  bool get _visible => _routeVisible && _foreground && !_ended;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground =
        lifecycle != AppLifecycleState.paused &&
        lifecycle != AppLifecycleState.hidden &&
        lifecycle != AppLifecycleState.detached;
    final profileChanges = widget.profileChanges;
    if (profileChanges != null) {
      _subscriptions.add(profileChanges.listen((_) => _request()));
    }
    _subscriptions.add(
      (widget.reviewChanges ?? ReviewsRefreshSignals.instance.stream).listen((
        e,
      ) {
        if (!identical(e.source, widget.source) &&
            e.rateeId == widget.rateeId()) {
          _request();
        }
      }),
    );
    _subscriptions.add(
      (widget.authLoss ?? AuthLossSignals.instance.stream).listen((_) {
        _ended = true;
        _pending = false;
        widget.onSessionEnded();
      }),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute also works in small routers without appRouteObserver installed.
    final visible =
        (TabVisibility.maybeOf(context)?.isVisible ?? true) &&
        RouteVisibilityScope.isOnTop(context) &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    final refocused = visible && !_routeVisible;
    _routeVisible = visible;
    if (refocused) _request();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) return;
    final resumed = state == AppLifecycleState.resumed;
    final refocused = resumed && !_foreground;
    _foreground = resumed;
    if (refocused) _request();
  }

  void _request() {
    if (!mounted || _ended) return;
    _pending = true;
    _schedule();
  }

  void _schedule() {
    if (!_visible || !_pending || _running || _scheduled || !mounted) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _scheduled = false;
      if (!mounted || !_visible || !_pending) return;
      _pending = false;
      _running = true;
      try {
        await widget.onRefresh();
      } finally {
        _running = false;
        if (mounted) _schedule();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
