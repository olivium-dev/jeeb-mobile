import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/notifications_repository.dart';
import 'notifications_list_state.dart';

class NotificationsListCubit extends Cubit<NotificationsListState> {
  NotificationsListCubit({required NotificationsRepository repository})
      : _repository = repository,
        super(const NotificationsListState());

  final NotificationsRepository _repository;

  Future<void> load() async {
    if (isClosed || state.status != NotificationsListStatus.initial) return;
    emit(state.copyWith(
      status: NotificationsListStatus.loading,
      clearError: true,
    ));
    try {
      final items = await _repository.fetchNotifications();
      if (isClosed) return;
      emit(state.copyWith(
        status: NotificationsListStatus.loaded,
        items: _sorted(items),
      ));
    } on NotificationsRepositoryException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(
        status: NotificationsListStatus.failed,
        error: e.failure,
      ));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(
        status: NotificationsListStatus.failed,
        error: NotificationsFailure.unknown,
      ));
    }
  }

  Future<void> refresh() async {
    if (isClosed) return;
    try {
      final items = await _repository.fetchNotifications();
      if (isClosed) return;
      emit(state.copyWith(
        status: NotificationsListStatus.loaded,
        items: _sorted(items),
        clearError: true,
      ));
    } on NotificationsRepositoryException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: e.failure));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(error: NotificationsFailure.unknown));
    }
  }

  Future<void> markRead(String id) async {
    final target = state.items.where((i) => i.id == id);
    if (target.isEmpty || target.first.read) return;
    emit(state.copyWith(
      items: state.items
          .map((i) => i.id == id ? i.copyWith(read: true) : i)
          .toList(growable: false),
    ));
    try {
      await _repository.markRead(id);
    } on NotificationsRepositoryException catch (_) {
    } catch (_) {/* same — swallow */}
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
