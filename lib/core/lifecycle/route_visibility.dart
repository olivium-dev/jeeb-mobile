import 'package:flutter/widgets.dart';

import '../router/app_route_observer.dart';

/// "Is the route this subtree lives on still the one on top of the navigator?"
///
/// The shell's tabs already know whether they are the SELECTED tab
/// (`TabVisibility`), and that is not the same question. Pushing
/// `/delivery/:id`, `/chat/:id` or the order summary on top of the shell leaves
/// every tab body mounted and still "selected" — so a push-bus subscriber in a
/// tab keeps reading for a surface the user cannot see. That is where six of the
/// ten reads measured for ONE `delivery` push came from (the customer home
/// summary's `/requests` ×2 + `/v1/offers` ×4, refetched underneath the
/// delivery-detail route).
///
/// `ChatDetailScreen` answers exactly this question for itself, with
/// [RouteAware] on [appRouteObserver] (`_onScreen`), for the foreground
/// push-suppression rule. This widget is that same mechanism, hoisted so a
/// subtree can read it — it is deliberately NOT a second observer stack: it
/// subscribes to the SAME production [appRouteObserver] the router installs.
///
/// Defaults to visible: [isOnTop] is `true` when no scope is present (a bare
/// widget test, a screen mounted outside a navigator), so an adopter degrades to
/// its previous always-read behaviour rather than to silent staleness.
class RouteVisibilityScope extends StatefulWidget {
  const RouteVisibilityScope({super.key, required this.child});

  final Widget child;

  /// Whether the nearest enclosing scope's route is on top. `true` when there is
  /// no scope. Establishes a dependency, so a dependent's
  /// `didChangeDependencies` re-runs when the answer flips.
  static bool isOnTop(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RouteOnTopScope>()?.isOnTop ??
      true;

  @override
  State<RouteVisibilityScope> createState() => _RouteVisibilityScopeState();
}

class _RouteVisibilityScopeState extends State<RouteVisibilityScope>
    with RouteAware {
  bool _isOnTop = true;

  /// The observer instance actually subscribed to. Captured because
  /// [appRouteObserver] is re-minted per router (`newAppRouteObserver`), and
  /// unsubscribing from a different instance would leak the subscription — the
  /// same reason `ChatDetailScreen` captures it.
  RouteObserver<ModalRoute<void>>? _subscribedObserver;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void> && _subscribedObserver == null) {
      // `subscribe` invokes `didPush()` synchronously, which sets the initial
      // value; no separate priming call is needed.
      _subscribedObserver = appRouteObserver..subscribe(this, route);
    }
  }

  void _set(bool value) {
    if (!mounted || _isOnTop == value) return;
    setState(() => _isOnTop = value);
  }

  @override
  void didPush() => _set(true);

  /// A route pushed above us popped — we are the top route again.
  @override
  void didPopNext() => _set(true);

  /// Another route was pushed ON TOP. Everything below it is invisible.
  @override
  void didPushNext() => _set(false);

  @override
  void didPop() => _set(false);

  @override
  void dispose() {
    _subscribedObserver?.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _RouteOnTopScope(isOnTop: _isOnTop, child: widget.child);
}

class _RouteOnTopScope extends InheritedWidget {
  const _RouteOnTopScope({required this.isOnTop, required super.child});

  final bool isOnTop;

  @override
  bool updateShouldNotify(_RouteOnTopScope oldWidget) =>
      oldWidget.isOnTop != isOnTop;
}
