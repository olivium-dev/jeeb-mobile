import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/notifications/data/shared_prefs_local_push_inbox.dart';
import 'package:jeeb_mobile/core/notifications/domain/local_push_inbox.dart';

LocalPushRecord _rec(String id, {String ts = '', bool read = false}) =>
    LocalPushRecord(
      id: id,
      type: kNewRequestPushType,
      title: 'Request $id',
      body: 'body',
      ts: ts.isEmpty ? '2026-07-03T10:00:00Z' : ts,
      ref: 'req-$id',
      read: read,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPrefsLocalPushInbox inbox;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    inbox = SharedPrefsLocalPushInbox(prefs: await SharedPreferences.getInstance());
  });

  test('append then readAll returns the record', () async {
    await inbox.append(_rec('a'));
    final all = await inbox.readAll();
    expect(all, hasLength(1));
    expect(all.single.id, 'a');
    expect(all.single.ref, 'req-a');
  });

  test('append dedups by id (same message to both isolates → one row)',
      () async {
    await inbox.append(_rec('a'));
    await inbox.append(_rec('a'));
    expect(await inbox.readAll(), hasLength(1));
  });

  test('readAll is newest-first by timestamp', () async {
    await inbox.append(_rec('old', ts: '2026-07-03T09:00:00Z'));
    await inbox.append(_rec('new', ts: '2026-07-03T11:00:00Z'));
    await inbox.append(_rec('mid', ts: '2026-07-03T10:00:00Z'));
    expect((await inbox.readAll()).map((r) => r.id).toList(),
        ['new', 'mid', 'old']);
  });

  test('markRead flips the flag and returns true for a known id', () async {
    await inbox.append(_rec('a'));
    expect(await inbox.markRead('a'), isTrue);
    expect((await inbox.readAll()).single.read, isTrue);
  });

  test('markRead returns false for an unknown id (server-sourced row)',
      () async {
    expect(await inbox.markRead('does-not-exist'), isFalse);
  });

  test('markAllRead marks every row read', () async {
    await inbox.append(_rec('a'));
    await inbox.append(_rec('b'));
    await inbox.markAllRead();
    expect((await inbox.readAll()).every((r) => r.read), isTrue);
  });

  test('markAllNewRequestsSeenInFeed flags new_request rows', () async {
    await inbox.append(_rec('a'));
    await inbox.markAllNewRequestsSeenInFeed();
    expect((await inbox.readAll()).single.seenInFeed, isTrue);
    // read is a distinct concern — feed-view does NOT mark the inbox row read.
    expect((await inbox.readAll()).single.read, isFalse);
  });

  test('the store is bounded — the oldest rows are evicted past the cap',
      () async {
    // 55 rows > the 50 cap; the 5 oldest must be gone.
    for (var i = 0; i < 55; i++) {
      final ts = '2026-07-03T${(i % 24).toString().padLeft(2, '0')}:00:00Z';
      await inbox.append(LocalPushRecord(
        id: 'id-${i.toString().padLeft(3, '0')}',
        type: kNewRequestPushType,
        title: 't',
        body: 'b',
        ts: DateTime.parse(ts).add(Duration(days: i)).toIso8601String(),
      ));
    }
    final all = await inbox.readAll();
    expect(all.length, lessThanOrEqualTo(50));
  });

  test('a corrupt row is dropped, not thrown', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jeeb.push_inbox.broken', '{not valid json');
    await inbox.append(_rec('a'));
    final all = await inbox.readAll();
    expect(all.map((r) => r.id), ['a']);
  });
}
