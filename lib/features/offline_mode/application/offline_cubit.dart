import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';

enum ConnectivityStatus { online, offline }

class OfflineState {

  const OfflineState({
    this.status = ConnectivityStatus.online,
    this.pendingSyncCount = 0,
    this.bannerDismissed = false,
  });
  final ConnectivityStatus status;
  final int pendingSyncCount;

  /// JEBV4-13: whether the user dismissed the offline banner for the CURRENT
  /// offline episode. Re-arms (false) on the next online→offline transition
  /// so a new outage is never silently hidden.
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

  void setOnline() => _setStatus(ConnectivityStatus.online);
  void setOffline() => _setStatus(ConnectivityStatus.offline);

  /// Diagnostic seam (diag-persistence lane): connectivity is the cheapest
  /// existing hook for "the network flipped" — emit only on ACTUAL transitions
  /// so a flapping caller can't spam the stream. No-op in release.
  void _setStatus(ConnectivityStatus status) {
    final transitioned = status != state.status;
    if (transitioned) {
      Diag.event('connectivity', <String, Object?>{'status': status.name});
    }
    emit(state.copyWith(
      status: status,
      // JEBV4-13: a NEW offline episode re-arms the banner so a dismissal
      // never silently hides a later outage.
      bannerDismissed: transitioned ? false : state.bannerDismissed,
    ));
  }

  /// JEBV4-13: user-invoked dismissal of the offline banner (its DISMISS
  /// action was previously `onTap: () {}` — a dead CTA). Hides the banner
  /// until the next online→offline transition.
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
