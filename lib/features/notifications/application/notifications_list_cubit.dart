import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/notifications_repository.dart';
import 'notifications_list_state.dart';

/// Drives notifications-list (JM-057). Imports `domain/` only
/// (40_GUARDRAILS_ARCH §2.2); the abstract [NotificationsRepository] is
/// constructor-injected (the screen resolves the LIVE `DioNotificationsRepository`
/// from `sl<NotificationsRepository>()`; the notification-service list+read
/// endpoints are mock-ready on :4010 — 42_GUARDRAILS_MOCK §4).
///
/// Responsibilities:
///  - cold-load the inbox (newest first),
///  - pull-to-refresh without flipping to a full-screen spinner,
///  - mark a single row read **optimistically** on tap (the deep-link dispatch
///    is the screen's concern; the cubit only owns the read flag), reconciling
///    silently if the PATCH fails (a transient read-flag error must not block
///    the navigation nor flash a banner — §2.2).
class NotificationsListCubit extends Cubit<NotificationsListState> {
  NotificationsListCubit({required NotificationsRepository repository})
      : _repository = repository,
        super(const NotificationsListState());

  final NotificationsRepository _repository;

  /// Cold-entry load. Guards re-entry so a remount doesn't refetch (§2.2).
  Future<void> load() async {
    if (state.status != NotificationsListStatus.initial) return;
    emit(state.copyWith(
      status: NotificationsListStatus.loading,
      clearError: true,
    ));
    try {
      final items = await _repository.fetchNotifications();
      emit(state.copyWith(
        status: NotificationsListStatus.loaded,
        items: _sorted(items),
      ));
    } on NotificationsRepositoryException catch (e) {
      emit(state.copyWith(
        status: NotificationsListStatus.failed,
        error: e.failure,
      ));
    } catch (_) {
      emit(state.copyWith(
        status: NotificationsListStatus.failed,
        error: NotificationsFailure.unknown,
      ));
    }
  }

  /// Pull-to-refresh — does NOT flip `status` to `loading` (the UI shows the
  /// pull indicator, not a full-screen spinner, §2.2).
  Future<void> refresh() async {
    try {
      final items = await _repository.fetchNotifications();
      emit(state.copyWith(
        status: NotificationsListStatus.loaded,
        items: _sorted(items),
        clearError: true,
      ));
    } on NotificationsRepositoryException catch (e) {
      emit(state.copyWith(error: e.failure));
    } catch (_) {
      emit(state.copyWith(error: NotificationsFailure.unknown));
    }
  }

  /// Marks [id] read. Optimistic: flips the local flag immediately so the row
  /// loses its unread affordance the instant the user taps it (the screen then
  /// deep-links per D84), and fires the PATCH in the background. A failed PATCH
  /// is swallowed — the read flag is a soft, non-blocking concern and a flaky
  /// network must not strand the deep-link or replay a banner (§2.2).
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
      // Swallow — optimistic read flag (§2.2). The next refresh reconciles.
    } catch (_) {/* same — swallow */}
  }

  /// One-shot error acknowledgement so a banner replay doesn't loop (§2.2).
  void acknowledgeError() {
    if (state.error == null) return;
    emit(state.copyWith(clearError: true));
  }

  /// Stable newest-first ordering by the row timestamp. Rows with an
  /// unparseable / empty timestamp sort last (so a malformed row never jumps
  /// to the top). The list is unmodifiable — the cubit owns the order (§2.1).
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
