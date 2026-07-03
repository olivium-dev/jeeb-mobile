import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/local_push_inbox.dart';

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
  BadgeCountCubit({BadgeCounts initial = const BadgeCounts(), LocalPushInbox? inbox})
      : _inbox = inbox,
        super(initial);

  /// Durable push store (G3). When supplied (production), the counts are
  /// re-derived from it on [hydrate] so a push that arrived while the app was
  /// backgrounded/terminated — handled only by the FCM background isolate, which
  /// cannot reach this cubit — still shows a badge on resume. The clears
  /// write-through so a cleared badge does NOT resurrect on the next hydrate.
  /// Null in widget/unit tests → pure in-memory (the pre-G3 behavior).
  final LocalPushInbox? _inbox;

  /// One accepted push. [isNewRequest] marks the `new_request` category so
  /// the feed-tab badge counts exactly the unseen open requests, never
  /// chat/offer noise.
  void increment({bool isNewRequest = false}) {
    emit(state.copyWith(
      unread: state.unread + 1,
      newRequests: isNewRequest ? state.newRequests + 1 : null,
    ));
  }

  /// Re-derive the counts from the durable [LocalPushInbox] (G3). Called on cold
  /// start and every app-resume so background/terminated `new_request` pushes
  /// surface a badge. No-op when no store is wired (tests). REPLACES the counts
  /// (does not add) so it is safe to call repeatedly — the store is the single
  /// source of truth for background-arrived pushes.
  Future<void> hydrate() async {
    final inbox = _inbox;
    if (inbox == null) return;
    final records = await inbox.readAll();
    final unread = records.where((r) => !r.read).length;
    // A new_request badges the feed tab only until it is EITHER viewed in the
    // feed (seenInFeed) OR surfaced by entering the inbox (read) — matching the
    // in-memory model where clear() zeros BOTH counters and clearNewRequests()
    // zeros only the feed count.
    final newRequests = records
        .where((r) =>
            r.type == kNewRequestPushType && !r.read && !r.seenInFeed)
        .length;
    emit(BadgeCounts(unread: unread, newRequests: newRequests));
  }

  /// User entered the notifications inbox — every push is now surfaced
  /// there, so zero both counters (and mark the durable rows read so a resume
  /// doesn't re-count them).
  void clear() {
    unawaited(_inbox?.markAllRead());
    if (state == const BadgeCounts()) return;
    emit(const BadgeCounts());
  }

  /// User is looking at the jeeber feed — the open requests are on screen,
  /// so the feed-tab badge no longer has anything unseen to count. Persist the
  /// "seen in feed" flag so the badge stays cleared across a resume/cold start.
  void clearNewRequests() {
    unawaited(_inbox?.markAllNewRequestsSeenInFeed());
    if (state.newRequests == 0) return;
    emit(state.copyWith(newRequests: 0));
  }
}
