import 'package:flutter/widgets.dart';

import 'polling_visibility.dart';

class PollingVisibilityGate extends StatefulWidget {
  const PollingVisibilityGate({
    super.key,
    required this.target,
    required this.isVisible,
    required this.child,
  });

  final PollingVisibility target;

  final bool isVisible;

  final Widget child;

  @override
  State<PollingVisibilityGate> createState() => _PollingVisibilityGateState();
}

class _PollingVisibilityGateState extends State<PollingVisibilityGate> {
  bool? _applied;

  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void didUpdateWidget(PollingVisibilityGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.target, widget.target)) {
      oldWidget.target.setPollingVisible(false);
      _applied = null;
    }
    _apply();
  }

  void _apply() {
    if (_applied == widget.isVisible) return;
    _applied = widget.isVisible;
    widget.target.setPollingVisible(widget.isVisible);
  }

  @override
  void dispose() {
    widget.target.setPollingVisible(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
