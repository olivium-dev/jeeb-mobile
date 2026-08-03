import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/local_push_inbox.dart';

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

class BadgeCountCubit extends Cubit<BadgeCounts> {
  BadgeCountCubit({BadgeCounts initial = const BadgeCounts(), LocalPushInbox? inbox})
      : _inbox = inbox,
        super(initial);

  final LocalPushInbox? _inbox;

  void increment({bool isNewRequest = false}) {
    emit(state.copyWith(
      unread: state.unread + 1,
      newRequests: isNewRequest ? state.newRequests + 1 : null,
    ));
  }

  Future<void> hydrate() async {
    final inbox = _inbox;
    if (inbox == null) return;
    final records = await inbox.readAll();
    final unread = records.where((r) => !r.read).length;
    final newRequests = records
        .where((r) =>
            r.type == kNewRequestPushType && !r.read && !r.seenInFeed)
        .length;
    emit(BadgeCounts(unread: unread, newRequests: newRequests));
  }

  void clear() {
    unawaited(_inbox?.markAllRead());
    if (state == const BadgeCounts()) return;
    emit(const BadgeCounts());
  }

  void clearNewRequests() {
    unawaited(_inbox?.markAllNewRequestsSeenInFeed());
    if (state.newRequests == 0) return;
    emit(state.copyWith(newRequests: 0));
  }
}
