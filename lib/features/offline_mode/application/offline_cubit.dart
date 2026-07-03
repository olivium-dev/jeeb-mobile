import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';

enum ConnectivityStatus { online, offline }

class OfflineState {

  const OfflineState({
    this.status = ConnectivityStatus.online,
    this.pendingSyncCount = 0,
  });
  final ConnectivityStatus status;
  final int pendingSyncCount;

  OfflineState copyWith({
    ConnectivityStatus? status,
    int? pendingSyncCount,
  }) {
    return OfflineState(
      status: status ?? this.status,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
    );
  }
}

class OfflineCubit extends Cubit<OfflineState> {
  OfflineCubit() : super(const OfflineState());

  void setOnline() => _setStatus(ConnectivityStatus.online);
  void setOffline() => _setStatus(ConnectivityStatus.offline);

  /// Diagnostic seam (diag-persistence lane): connectivity is the cheapest
  /// existing hook for "the network flipped" — emit only on ACTUAL transitions
  /// so a flapping caller can't spam the stream. No-op in release.
  void _setStatus(ConnectivityStatus status) {
    if (status != state.status) {
      Diag.event('connectivity', <String, Object?>{'status': status.name});
    }
    emit(state.copyWith(status: status));
  }

  void enqueuePendingSync() {
    emit(state.copyWith(pendingSyncCount: state.pendingSyncCount + 1));
  }

  void syncCompleted() {
    final count = state.pendingSyncCount > 0 ? state.pendingSyncCount - 1 : 0;
    emit(state.copyWith(pendingSyncCount: count));
  }
}
