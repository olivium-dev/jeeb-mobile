import 'package:flutter/widgets.dart';

import '../../features/shell/tab_visibility.dart';
import 'app_resume_signals.dart';
import 'route_visibility.dart';

typedef RouteResumeCallback = void Function(BuildContext context);

class RouteResumeRefetch extends StatefulWidget {
  const RouteResumeRefetch({
    super.key,
    required this.onResume,
    required this.child,
  });

  final RouteResumeCallback onResume;

  final Widget child;

  @override
  State<RouteResumeRefetch> createState() => _RouteResumeRefetchState();
}

class _RouteResumeRefetchState extends State<RouteResumeRefetch>
    with ResumeRefetchMixin {
  ModalRoute<Object?>? _route;

  bool _scopeOnTop = true;

  bool _pending = false;

  bool _tabVisible = true;

  bool get _isVisible =>
      _tabVisible && _scopeOnTop && (_route?.isCurrent ?? true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of<Object?>(context);
    _scopeOnTop = RouteVisibilityScope.isOnTop(context);
    _tabVisible = TabVisibility.maybeOf(context)?.isVisible ?? true;
    _payDebt();
  }

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
    widget.onResume(context);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
