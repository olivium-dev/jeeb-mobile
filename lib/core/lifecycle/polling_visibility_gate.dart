import 'package:flutter/widgets.dart';

import 'polling_visibility.dart';

/// Non-rendering widget that reports surface visibility to [target].
///
/// It does **NOT** observe app lifecycle and does **NOT** dereference
/// [WidgetsBinding]. Foreground gating is ambient, via [AppLifecycleGate].
/// That is deliberate: a widget that read `WidgetsBinding.instance
/// .lifecycleState` would see `null` under `flutter_test` and silently invert
/// the gate to OFF, which is the R8 failure this contract must not have.
///
/// The host computes [isVisible] and must AND every relevant condition into
/// it — shell-tab selection, route visibility, inner sub-tab, and (later)
/// jeeber online state. Core never imports feature-layer visibility sources.
class PollingVisibilityGate extends StatefulWidget {
  const PollingVisibilityGate({
    super.key,
    required this.target,
    required this.isVisible,
    required this.child,
  });

  /// The poller, cubit or repository adapter whose visibility this reports.
  final PollingVisibility target;

  /// Whether the polling surface is actually on screen.
  final bool isVisible;

  /// Unmodified feature subtree.
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

  /// Latch so the repeated rebuilds an adopter gets from
  /// `didChangeDependencies` never churn the timer.
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
