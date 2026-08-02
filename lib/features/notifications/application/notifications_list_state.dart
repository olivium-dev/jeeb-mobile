import 'package:equatable/equatable.dart';

import '../domain/notifications_repository.dart';

enum NotificationsListStatus {
  initial,

  loading,

  loaded,

  failed,
}

class NotificationsListState extends Equatable {
  const NotificationsListState({
    this.status = NotificationsListStatus.initial,
    this.items = const <NotificationItem>[],
    this.error,
  });

  final NotificationsListStatus status;

  final List<NotificationItem> items;

  final NotificationsFailure? error;

  bool get hasItems => items.isNotEmpty;

  int get unreadCount => items.where((i) => !i.read).length;

  NotificationsListState copyWith({
    NotificationsListStatus? status,
    List<NotificationItem>? items,
    NotificationsFailure? error,
    bool clearError = false,
  }) {
    return NotificationsListState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, items, error];
}
