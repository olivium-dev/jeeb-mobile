import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../domain/notifications_repository.dart';
import 'notifications_list_state.dart';

class NotificationsListCubit extends Cubit<NotificationsListState> {
  NotificationsListCubit({required NotificationsRepository repository})
    : _repository = repository,
      super(const NotificationsListState());

  final NotificationsRepository _repository;
  int _readGeneration = 0;

  Future<void> load() async {
    if (isClosed || state.status != NotificationsListStatus.initial) return;
    emit(
      state.copyWith(status: NotificationsListStatus.loading, clearError: true),
    );
    await _read(warm: false);
  }

  /// The cold-error retry: unlike [refresh] it shows the loading rung first.
  Future<void> retry() async {
    if (isClosed || state.status == NotificationsListStatus.loading) return;
    emit(
      state.copyWith(status: NotificationsListStatus.loading, clearError: true),
    );
    await _read(warm: false);
  }

  Future<void> refresh() async {
    if (isClosed) return;
    await _read(warm: state.status == NotificationsListStatus.loaded);
  }

  Future<void> _read({required bool warm}) async {
    final generation = ++_readGeneration;
    try {
      final snapshot = await _snapshot();
      if (isClosed || generation != _readGeneration) return;
      // A degraded warm read is a partial inbox: surface the failure so the
      // strip offers Retry, not just the cached note.
      final degradedFailure = warm && snapshot.degraded
          ? snapshot.failure
          : null;
      emit(
        state.copyWith(
          status: NotificationsListStatus.loaded,
          items: _sorted(snapshot.items),
          degraded: snapshot.degraded,
          clearError: true,
          refreshError: degradedFailure,
          clearRefreshError: degradedFailure == null,
        ),
      );
    } on NotificationsRepositoryException catch (e) {
      if (isClosed || generation != _readGeneration) return;
      _emitFailure(warm, e.failure, e.appFailure ?? AppFailure.of(e));
    } catch (error) {
      if (isClosed || generation != _readGeneration) return;
      _emitFailure(warm, NotificationsFailure.unknown, AppFailure.of(error));
    }
  }

  Future<NotificationsSnapshot> _snapshot() async {
    final repository = _repository;
    if (repository is DegradableNotificationsRepository) {
      return (repository as DegradableNotificationsRepository).fetchSnapshot();
    }
    return (
      items: await repository.fetchNotifications(),
      degraded: false,
      failure: null,
    );
  }

  /// A warm failure keeps the rows; only a cold read blanks the surface.
  void _emitFailure(bool warm, NotificationsFailure kind, AppFailure failure) {
    if (warm) {
      emit(state.copyWith(refreshError: failure));
      return;
    }
    emit(
      state.copyWith(
        status: NotificationsListStatus.failed,
        error: kind,
        appFailure: failure,
      ),
    );
  }

  Future<void> markRead(String id) async {
    final target = state.items.where((i) => i.id == id);
    if (target.isEmpty || target.first.read) return;
    emit(
      state.copyWith(
        items: state.items
            .map((i) => i.id == id ? i.copyWith(read: true) : i)
            .toList(growable: false),
        clearMarkReadFailure: true,
      ),
    );
    try {
      await _repository.markRead(id);
    } catch (error) {
      if (isClosed) return;
      // Roll the one row back on the CURRENT list: a refresh may have landed
      // during the PATCH and must not be clobbered by a stale snapshot.
      emit(
        state.copyWith(
          items: state.items
              .map((i) => i.id == id ? i.copyWith(read: false) : i)
              .toList(growable: false),
          markReadFailure: error is NotificationsRepositoryException
              ? (error.appFailure ?? AppFailure.of(error))
              : AppFailure.of(error),
        ),
      );
    }
  }

  void acknowledgeMarkReadFailure() {
    if (isClosed || state.markReadFailure == null) return;
    emit(state.copyWith(clearMarkReadFailure: true));
  }

  void acknowledgeRefreshError() {
    if (isClosed || state.refreshError == null) return;
    emit(state.copyWith(clearRefreshError: true));
  }

  void acknowledgeError() {
    if (state.error == null) return;
    emit(state.copyWith(clearError: true));
  }

  List<NotificationItem> _sorted(List<NotificationItem> input) {
    final out = List<NotificationItem>.of(input);
    out.sort((a, b) {
      final ta = DateTime.tryParse(a.timestamp);
      final tb = DateTime.tryParse(b.timestamp);
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    return List<NotificationItem>.unmodifiable(out);
  }
}
