// Unit tests for NotificationsListCubit (JM-057). Proves the 4-state machine
// (40_GUARDRAILS_ARCH §2.2/§3) off a scripted NotificationsRepository (no DI,
// no network):
//   - load(): initial → loading → loaded, items newest-first by timestamp.
//   - load() failure maps the typed NotificationsFailure (network / unknown).
//   - load() guards re-entry (a second call is a no-op).
//   - refresh(): re-fetches without flipping status to loading.
//   - markRead(): optimistic local flip + swallows a PATCH failure (non-blocking).

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/notifications/application/notifications_list_cubit.dart';
import 'package:jeeb_mobile/features/notifications/application/notifications_list_state.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';

class _ScriptedRepository implements NotificationsRepository {
  _ScriptedRepository({
    List<NotificationItem>? items,
    this.fetchThrows,
    this.markThrows = false,
    this.confirmReceiptThrows = false,
  }) : _items = items ?? const <NotificationItem>[];

  List<NotificationItem> _items;
  final NotificationsFailure? fetchThrows;
  final bool markThrows;
  final bool confirmReceiptThrows;
  final List<String> markedRead = <String>[];
  final List<String> confirmedReceipts = <String>[];

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

  @override
  Future<void> confirmReceipt(String deliveryId) async {
    if (confirmReceiptThrows) {
      throw const NotificationsRepositoryException(NotificationsFailure.network);
    }
    confirmedReceipts.add(deliveryId);
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

  group('NotificationsListCubit.confirmReceipt (notif-inline-confirm-receipt)',
      () {
    test('confirms the delivery and marks the row confirmed', () async {
      final repo = _ScriptedRepository(items: [
        _item('n1', kind: NotificationKind.confirmReceipt, ref: 'DLV-9'),
      ]);
      final cubit = NotificationsListCubit(repository: repo);
      await cubit.load();

      await cubit.confirmReceipt(id: 'n1', deliveryId: 'DLV-9');

      expect(repo.confirmedReceipts, ['DLV-9']);
      expect(cubit.state.isReceiptConfirmed('n1'), isTrue);
      expect(cubit.state.isConfirmingReceipt('n1'), isFalse);
      expect(cubit.state.confirmReceiptFailedId, isNull);
      await cubit.close();
    });

    test('a failed confirm raises the one-shot failed id, not confirmed',
        () async {
      final repo = _ScriptedRepository(
        items: [
          _item('n1', kind: NotificationKind.confirmReceipt, ref: 'DLV-9'),
        ],
        confirmReceiptThrows: true,
      );
      final cubit = NotificationsListCubit(repository: repo);
      await cubit.load();

      await cubit.confirmReceipt(id: 'n1', deliveryId: 'DLV-9');

      expect(cubit.state.isReceiptConfirmed('n1'), isFalse);
      expect(cubit.state.confirmReceiptFailedId, 'n1');

      cubit.acknowledgeConfirmReceiptError();
      expect(cubit.state.confirmReceiptFailedId, isNull);
      await cubit.close();
    });

    test('empty deliveryId is a no-op (no call, no state churn)', () async {
      final repo = _ScriptedRepository(items: [
        _item('n1', kind: NotificationKind.confirmReceipt),
      ]);
      final cubit = NotificationsListCubit(repository: repo);
      await cubit.load();

      await cubit.confirmReceipt(id: 'n1', deliveryId: '');

      expect(repo.confirmedReceipts, isEmpty);
      expect(cubit.state.isConfirmingReceipt('n1'), isFalse);
      await cubit.close();
    });

    test('a second confirm on an already-confirmed row is a no-op', () async {
      final repo = _ScriptedRepository(items: [
        _item('n1', kind: NotificationKind.confirmReceipt, ref: 'DLV-9'),
      ]);
      final cubit = NotificationsListCubit(repository: repo);
      await cubit.load();
      await cubit.confirmReceipt(id: 'n1', deliveryId: 'DLV-9');
      await cubit.confirmReceipt(id: 'n1', deliveryId: 'DLV-9');
      expect(repo.confirmedReceipts, ['DLV-9']);
      await cubit.close();
    });
  });
}
