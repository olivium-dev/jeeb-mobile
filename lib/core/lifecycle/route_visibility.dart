import 'package:flutter/widgets.dart';

import '../router/app_route_observer.dart';

/// Answers "is the route this subtree lives on still on top of the navigator?"
/// Differs from tab selection: pushing `/delivery/:id` over a tab keeps the tab
/// mounted and re-reading. Use [isOnTop] to suppress reads off-screen.
class RouteVisibilityScope extends StatefulWidget {
  const RouteVisibilityScope({super.key, required this.child});

  final Widget child;

  /// Whether the nearest enclosing scope's route is on top. `true` when there is no scope.
  static bool isOnTop(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RouteOnTopScope>()?.isOnTop ??
      true;

  @override
  State<RouteVisibilityScope> createState() => _RouteVisibilityScopeState();
}

class _RouteVisibilityScopeState extends State<RouteVisibilityScope>
    with RouteAware {
  bool _isOnTop = true;

  /// Captured because [appRouteObserver] is re-minted per router; unsubscribing from
  /// a different instance would leak the subscription.
  RouteObserver<ModalRoute<void>>? _subscribedObserver;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void> && _subscribedObserver == null) {
      // subscribe invokes didPush synchronously, sets initial value.
      _subscribedObserver = appRouteObserver..subscribe(this, route);
    }
  }

  void _set(bool value) {
    if (!mounted || _isOnTop == value) return;
    setState(() => _isOnTop = value);
  }

  @override
  void didPush() => _set(true);

  @override
  void didPopNext() => _set(true);

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
