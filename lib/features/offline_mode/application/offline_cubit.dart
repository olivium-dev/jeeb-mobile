import 'package:flutter_bloc/flutter_bloc.dart';

enum ConnectivityStatus { online, offline }

class OfflineState {
  final ConnectivityStatus status;
  final int pendingSyncCount;

  const OfflineState({
    this.status = ConnectivityStatus.online,
    this.pendingSyncCount = 0,
  });

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

  void setOnline() => emit(state.copyWith(status: ConnectivityStatus.online));
  void setOffline() => emit(state.copyWith(status: ConnectivityStatus.offline));

  void enqueuePendingSync() {
    emit(state.copyWith(pendingSyncCount: state.pendingSyncCount + 1));
  }

  void syncCompleted() {
    final count = state.pendingSyncCount > 0 ? state.pendingSyncCount - 1 : 0;
    emit(state.copyWith(pendingSyncCount: count));
  }
}
