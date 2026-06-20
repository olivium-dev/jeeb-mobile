import 'package:equatable/equatable.dart';

import '../domain/notifications_repository.dart';

/// Top-level UI status for notifications-list (JM-057) — the canonical
/// 4-state machine (40_GUARDRAILS_ARCH §2.1 / §3). `empty` is NOT a fifth
/// status: it is `loaded` + an empty [NotificationsListState.items].
enum NotificationsListStatus {
  /// Cold load — nothing fetched yet.
  initial,

  /// First fetch is on the wire.
  loading,

  /// At least one fetch has landed. A refresh keeps us here.
  loaded,

  /// Cold load failed and there is nothing to show.
  failed,
}

/// Immutable state for the notifications inbox.
///
/// [items] is held newest-first (the cubit owns the ordering, sorting by the
/// row timestamp). [error] is a typed [NotificationsFailure] surfaced from the
/// last foreground action (load / refresh) — never a raw exception or string
/// (40_GUARDRAILS_ARCH §2.1). A mid-screen mark-read failure is swallowed
/// (optimistic), so it does not raise [error].
class NotificationsListState extends Equatable {
  const NotificationsListState({
    this.status = NotificationsListStatus.initial,
    this.items = const <NotificationItem>[],
    this.error,
    this.confirmingReceiptIds = const <String>{},
    this.confirmedReceiptIds = const <String>{},
    this.confirmReceiptFailedId,
  });

  final NotificationsListStatus status;

  /// Inbox rows in display order (newest first).
  final List<NotificationItem> items;

  /// One-shot error from the last load / refresh.
  final NotificationsFailure? error;

  /// Notification ids whose inline confirm-receipt action is in flight (drives
  /// the per-row spinner; notif-inline-confirm-receipt).
  final Set<String> confirmingReceiptIds;

  /// Notification ids whose inline confirm-receipt succeeded (the row swaps to
  /// a "confirmed" affordance instead of the action button).
  final Set<String> confirmedReceiptIds;

  /// One-shot id of the row whose inline confirm-receipt just failed (drives a
  /// retry snackbar). Cleared by [NotificationsListCubit.acknowledgeConfirmReceiptError].
  final String? confirmReceiptFailedId;

  bool get hasItems => items.isNotEmpty;

  /// Count of unread rows — drives the (optional) unread affordance.
  int get unreadCount => items.where((i) => !i.read).length;

  /// True while [id]'s inline confirm-receipt action is in flight.
  bool isConfirmingReceipt(String id) => confirmingReceiptIds.contains(id);

  /// True once [id]'s inline confirm-receipt has succeeded.
  bool isReceiptConfirmed(String id) => confirmedReceiptIds.contains(id);

  NotificationsListState copyWith({
    NotificationsListStatus? status,
    List<NotificationItem>? items,
    NotificationsFailure? error,
    bool clearError = false,
    Set<String>? confirmingReceiptIds,
    Set<String>? confirmedReceiptIds,
    String? confirmReceiptFailedId,
    bool clearConfirmReceiptFailedId = false,
  }) {
    return NotificationsListState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: clearError ? null : (error ?? this.error),
      confirmingReceiptIds: confirmingReceiptIds ?? this.confirmingReceiptIds,
      confirmedReceiptIds: confirmedReceiptIds ?? this.confirmedReceiptIds,
      confirmReceiptFailedId: clearConfirmReceiptFailedId
          ? null
          : (confirmReceiptFailedId ?? this.confirmReceiptFailedId),
    );
  }

  @override
  List<Object?> get props => [
        status,
        items,
        error,
        confirmingReceiptIds,
        confirmedReceiptIds,
        confirmReceiptFailedId,
      ];
}
