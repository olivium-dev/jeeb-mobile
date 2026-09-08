import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/notifications_repository.dart';

enum NotificationsListStatus { initial, loading, loaded, failed }

class NotificationsListState extends Equatable {
  const NotificationsListState({
    this.status = NotificationsListStatus.initial,
    this.items = const <NotificationItem>[],
    this.error,
    this.appFailure,
    this.refreshError,
    this.markReadFailure,
    this.degraded = false,
  });

  final NotificationsListStatus status;

  final List<NotificationItem> items;

  final NotificationsFailure? error;

  /// The classified cold-read failure.
  final AppFailure? appFailure;

  /// A refresh that failed over rows already on screen.
  final AppFailure? refreshError;

  /// The last mark-read failure, after the optimistic flip was rolled back.
  final AppFailure? markReadFailure;

  /// The list is a subset, not a complete inbox (NOTIF-02).
  final bool degraded;

  bool get hasItems => items.isNotEmpty;

  int get unreadCount => items.where((i) => !i.read).length;

  NotificationsListState copyWith({
    NotificationsListStatus? status,
    List<NotificationItem>? items,
    NotificationsFailure? error,
    AppFailure? appFailure,
    AppFailure? refreshError,
    bool clearRefreshError = false,
    AppFailure? markReadFailure,
    bool clearMarkReadFailure = false,
    bool? degraded,
    bool clearError = false,
  }) {
    return NotificationsListState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: clearError ? null : (error ?? this.error),
      appFailure: clearError ? null : (appFailure ?? this.appFailure),
      refreshError: clearRefreshError
          ? null
          : (refreshError ?? this.refreshError),
      markReadFailure: clearMarkReadFailure
          ? null
          : (markReadFailure ?? this.markReadFailure),
      degraded: degraded ?? this.degraded,
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    error,
    appFailure,
    refreshError,
    markReadFailure,
    degraded,
  ];
}
