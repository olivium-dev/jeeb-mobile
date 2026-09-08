import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/network_reachability_signals.dart';

enum ConnectivityStatus { online, offline }

class OfflineState {

  const OfflineState({
    this.status = ConnectivityStatus.online,
    this.pendingSyncCount = 0,
    this.bannerDismissed = false,
  });
  final ConnectivityStatus status;
  final int pendingSyncCount;

  final bool bannerDismissed;

  OfflineState copyWith({
    ConnectivityStatus? status,
    int? pendingSyncCount,
    bool? bannerDismissed,
  }) {
    return OfflineState(
      status: status ?? this.status,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
      bannerDismissed: bannerDismissed ?? this.bannerDismissed,
    );
  }
}

class OfflineCubit extends Cubit<OfflineState> {
  OfflineCubit() : super(const OfflineState());

  StreamSubscription<bool>? _reachability;

  void setOnline() => _setStatus(ConnectivityStatus.online);
  void setOffline() => _setStatus(ConnectivityStatus.offline);

  /// Persistent UI starts from the snapshot and mirrors every state transition,
  /// independently of the throttled reconnect refresh triggers.
  void bindReachability(NetworkReachabilitySignals signals) {
    _reachability?.cancel();
    _applyReachability(signals.isOnline);
    _reachability = signals.stateStream.listen(_applyReachability);
  }

  void _applyReachability(bool online) => online ? setOnline() : setOffline();

  @override
  Future<void> close() async {
    await _reachability?.cancel();
    _reachability = null;
    return super.close();
  }

  void _setStatus(ConnectivityStatus status) {
    final transitioned = status != state.status;
    if (transitioned) {
      Diag.event('connectivity', <String, Object?>{'status': status.name});
    }
    emit(state.copyWith(
      status: status,
      bannerDismissed: transitioned ? false : state.bannerDismissed,
    ));
  }

  void dismissBanner() {
    if (state.bannerDismissed) return;
    emit(state.copyWith(bannerDismissed: true));
  }

  void enqueuePendingSync() {
    emit(state.copyWith(pendingSyncCount: state.pendingSyncCount + 1));
  }

  void syncCompleted() {
    final count = state.pendingSyncCount > 0 ? state.pendingSyncCount - 1 : 0;
    emit(state.copyWith(pendingSyncCount: count));
  }
}
