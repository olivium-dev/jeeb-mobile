import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/lifecycle/app_resume_signals.dart';
import '../../../core/notifications/application/push_refresh_signals.dart';
import '../../shell/tab_visibility.dart';
import '../application/order_history_cubit.dart';

/// Recovery triggers for the customer's Delivery-tab order list.
class OrdersResumeRefetcher extends StatefulWidget {
  const OrdersResumeRefetcher({
    super.key,
    required this.child,
    this.refreshSignals,
  });

  final Widget child;

  final Stream<void>? refreshSignals;

  @override
  State<OrdersResumeRefetcher> createState() => _OrdersResumeRefetcherState();
}

class _OrdersResumeRefetcherState extends State<OrdersResumeRefetcher>
    with ResumeRefetchMixin {
  bool? _wasVisible;

  StreamSubscription<void>? _pushSub;

  @override
  void initState() {
    super.initState();
    final signals = widget.refreshSignals ??
        resolvePushRefreshStream(topics: const {RefreshTopic.order});
    _pushSub = signals?.listen((_) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
  }

  /// One silent re-pull, mounted-guarded so a trigger landing during teardown
  /// never touches a defunct element.
  void _read() {
    if (!mounted) return;
    unawaited(context.read<OrderHistoryCubit>().refreshSilently());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
