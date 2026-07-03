import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// In-app unread-notification counters (G3: tracked AND rendered).
///
/// * [unread] — every push the handler accepts; the inbox affordance.
///   Cleared when the user enters the notifications inbox.
/// * [newRequests] — the `new_request` subset: open requests the jeeber has
///   not looked at yet. Rendered as the count badge on the shell's Dashboard
///   (feed) tab icon and cleared the moment the feed is actually viewed.
class BadgeCounts extends Equatable {
  const BadgeCounts({this.unread = 0, this.newRequests = 0});

  final int unread;
  final int newRequests;

  BadgeCounts copyWith({int? unread, int? newRequests}) {
    return BadgeCounts(
      unread: unread ?? this.unread,
      newRequests: newRequests ?? this.newRequests,
    );
  }

  @override
  List<Object?> get props => [unread, newRequests];
}

/// Tracks the in-app unread-notification counts. Kept dead simple — every
/// push that the handler accepts increments [BadgeCounts.unread] (and, for
/// `new_request` pushes, [BadgeCounts.newRequests]); entering the inbox
/// clears everything; viewing the jeeber feed clears the request badge.
///
/// G3: before sprint-009 this cubit was incremented on every push but read
/// by ZERO widgets. It now drives the count badge on the shell's Dashboard
/// tab icon (`shell_screen.dart` `_BarItem`), cleared on feed view by
/// `FeedResumeRefetcher`.
///
/// The platform app-icon badge is owned by the OS / firebase_messaging
/// (`badge: true` in the notification payload), not this cubit; we only
/// model the in-app visual.
class BadgeCountCubit extends Cubit<BadgeCounts> {
  BadgeCountCubit({BadgeCounts initial = const BadgeCounts()})
      : super(initial);

  /// One accepted push. [isNewRequest] marks the `new_request` category so
  /// the feed-tab badge counts exactly the unseen open requests, never
  /// chat/offer noise.
  void increment({bool isNewRequest = false}) {
    emit(state.copyWith(
      unread: state.unread + 1,
      newRequests: isNewRequest ? state.newRequests + 1 : null,
    ));
  }

  /// User entered the notifications inbox — every push is now surfaced
  /// there, so zero both counters.
  void clear() {
    if (state == const BadgeCounts()) return;
    emit(const BadgeCounts());
  }

  /// User is looking at the jeeber feed — the open requests are on screen,
  /// so the feed-tab badge no longer has anything unseen to count.
  void clearNewRequests() {
    if (state.newRequests == 0) return;
    emit(state.copyWith(newRequests: 0));
  }
}
