// Unit tests for NotificationsListCubit (JM-057). Proves the 4-state machine

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/notifications/application/notifications_list_cubit.dart';
import 'package:jeeb_mobile/features/notifications/application/notifications_list_state.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';

class _ScriptedRepository implements NotificationsRepository {
  _ScriptedRepository({
    List<NotificationItem>? items,
    this.fetchThrows,
    this.markThrows = false,
  }) : _items = items ?? const <NotificationItem>[];

  List<NotificationItem> _items;
  final NotificationsFailure? fetchThrows;
  final bool markThrows;
  final List<String> markedRead = <String>[];

  void seed(List<NotificationItem> items) => _items = items;

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    final f = fetchThrows;
    if (f != null) throw NotificationsRepositoryException(f);
    return _items;
  }

  @override
  Future<void> markRead(String id) async {
    if (markThrows) {
      throw const NotificationsRepositoryException(NotificationsFailure.network);
    }
    markedRead.add(id);
  }
}

NotificationItem _item(
  String id, {
  NotificationKind kind = NotificationKind.offer,
  String ts = '2026-06-18T10:00:00Z',
  bool read = false,
  String? ref,
}) =>
    NotificationItem(
      id: id,
      kind: kind,
      title: 't-$id',
      body: 'b-$id',
      timestamp: ts,
      read: read,
      ref: ref,
    );

void main() {
  group('NotificationsListCubit.load', () {
    test('initial → loaded with items newest-first by timestamp', () async {
      final repo = _ScriptedRepository(items: [
        _item('old', ts: '2026-06-18T09:00:00Z'),
        _item('new', ts: '2026-06-18T11:00:00Z'),
        _item('mid', ts: '2026-06-18T10:00:00Z'),
      ]);
      final cubit = NotificationsListCubit(repository: repo);
      expect(cubit.state.status, NotificationsListStatus.initial);

      await cubit.load();

      expect(cubit.state.status, NotificationsListStatus.loaded);
      expect(
        cubit.state.items.map((i) => i.id).toList(),
        ['new', 'mid', 'old'],
      );
      expect(cubit.state.hasItems, isTrue);
      await cubit.close();
    });

    test('loaded with an empty list (empty is a sub-state of loaded)', () async {
      final cubit = NotificationsListCubit(repository: _ScriptedRepository());
      await cubit.load();
      expect(cubit.state.status, NotificationsListStatus.loaded);
      expect(cubit.state.hasItems, isFalse);
      await cubit.close();
    });

    test('network failure → failed + typed NotificationsFailure.network',
        () async {
      final cubit = NotificationsListCubit(
        repository:
            _ScriptedRepository(fetchThrows: NotificationsFailure.network),
      );
      await cubit.load();
      expect(cubit.state.status, NotificationsListStatus.failed);
      expect(cubit.state.error, NotificationsFailure.network);
      await cubit.close();
    });

    test('re-entry guard: a second load() is a no-op', () async {
      final repo = _ScriptedRepository(items: [_item('a')]);
      final cubit = NotificationsListCubit(repository: repo);
      await cubit.load();
      repo.seed([_item('b'), _item('c')]);
      await cubit.load(); // guarded — status is no longer initial
      expect(cubit.state.items.map((i) => i.id).toList(), ['a']);
      await cubit.close();
    });
  });

  group('NotificationsListCubit.refresh', () {
    test('re-fetches and stays loaded (no loading flip)', () async {
      final repo = _ScriptedRepository(items: [_item('a')]);
      final cubit = NotificationsListCubit(repository: repo);
      await cubit.load();
      repo.seed([_item('a'), _item('b', ts: '2026-06-18T12:00:00Z')]);
      await cubit.refresh();
      expect(cubit.state.status, NotificationsListStatus.loaded);
      expect(cubit.state.items.map((i) => i.id).toList(), ['b', 'a']);
      await cubit.close();
    });
  });

  group('NotificationsListCubit.markRead', () {
    test('optimistically flips read and PATCHes the backend', () async {
      final repo = _ScriptedRepository(items: [_item('a'), _item('b')]);
      final cubit = NotificationsListCubit(repository: repo);
      await cubit.load();
      expect(cubit.state.unreadCount, 2);

      await cubit.markRead('a');

      expect(cubit.state.items.firstWhere((i) => i.id == 'a').read, isTrue);
      expect(cubit.state.unreadCount, 1);
      expect(repo.markedRead, ['a']);
      await cubit.close();
    });

    test('swallows a PATCH failure (read flag stays flipped, no error)',
        () async {
      final repo = _ScriptedRepository(
        items: [_item('a')],
        markThrows: true,
      );
      final cubit = NotificationsListCubit(repository: repo);
      await cubit.load();
      await cubit.markRead('a');
      expect(cubit.state.items.first.read, isTrue);
      expect(cubit.state.error, isNull);
      await cubit.close();
    });

    test('already-read row is a no-op', () async {
      final repo = _ScriptedRepository(items: [_item('a', read: true)]);
      final cubit = NotificationsListCubit(repository: repo);
      await cubit.load();
      await cubit.markRead('a');
      expect(repo.markedRead, isEmpty);
      await cubit.close();
    });
  });
}
