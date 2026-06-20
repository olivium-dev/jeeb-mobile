import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/connectivity_source.dart';

enum ConnectivityStatus { online, offline }

class OfflineState {

  const OfflineState({
    this.status = ConnectivityStatus.online,
    this.pendingSyncCount = 0,
    this.dismissed = false,
  });
  final ConnectivityStatus status;
  final int pendingSyncCount;

  /// User dismissed the banner for the current offline episode. Reset to
  /// `false` on the next offline transition so it reappears if connectivity
  /// drops again.
  final bool dismissed;

  /// Whether the global banner should render: offline AND not dismissed.
  bool get showBanner =>
      status == ConnectivityStatus.offline && !dismissed;

  OfflineState copyWith({
    ConnectivityStatus? status,
    int? pendingSyncCount,
    bool? dismissed,
  }) {
    return OfflineState(
      status: status ?? this.status,
      pendingSyncCount: pendingSyncCount ?? this.pendingSyncCount,
      dismissed: dismissed ?? this.dismissed,
    );
  }
}

/// Drives the global `OfflineBanner` (global-offline-banner / SC-129).
///
/// Previously dead UI: `setOffline()` had NO caller and no connectivity source
/// existed. Now an optional [ConnectivitySource] seeds the initial state and
/// subscribes to transitions so airplane mode flips the banner on/off. Tests
/// (and the no-source default) can still drive [setOffline]/[setOnline]
/// directly.
class OfflineCubit extends Cubit<OfflineState> {
  OfflineCubit({ConnectivitySource? connectivity})
      : _connectivity = connectivity,
        super(const OfflineState()) {
    if (_connectivity != null) {
      _bind(_connectivity);
    }
  }

  final ConnectivitySource? _connectivity;
  StreamSubscription<bool>? _sub;

  void _bind(ConnectivitySource source) {
    // Seed from the current value so the banner is correct on launch, then
    // follow transitions. Both paths are fail-safe: a connectivity error must
    // never crash the app — assume online.
    unawaited(source.isOnline().then(_apply).catchError((_) {}));
    _sub = source.onConnectivityChanged.listen(_apply, onError: (_) {});
  }

  void _apply(bool online) => online ? setOnline() : setOffline();

  void setOnline() => emit(state.copyWith(status: ConnectivityStatus.online));

  void setOffline() {
    // A fresh offline episode resets a prior dismiss so the banner reappears.
    emit(state.copyWith(
      status: ConnectivityStatus.offline,
      dismissed: false,
    ));
  }

  /// User dismissed the banner for this offline episode.
  void dismissBanner() => emit(state.copyWith(dismissed: true));

  void enqueuePendingSync() {
    emit(state.copyWith(pendingSyncCount: state.pendingSyncCount + 1));
  }

  void syncCompleted() {
    final count = state.pendingSyncCount > 0 ? state.pendingSyncCount - 1 : 0;
    emit(state.copyWith(pendingSyncCount: count));
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
