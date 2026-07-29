// WHAT THIS CANNOT PROVE: `Firebase.apps` is empty in every widget test in this
// repo, so no test here can observe a real Firestore query, a real filter, or a
// real rule evaluation. This source-text pin proves only that the clause has not
// been silently deleted; the filter's real behaviour is observable only on a
// device against live rules.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firestore message LIST keeps VisibleTo before CreatedAt ordering', () {
    final file = File(
      'lib/features/chat/data/firestore_chat_realtime_source.dart',
    );
    expect(
      file.existsSync(),
      isTrue,
      reason: 'test must run from the package root',
    );

    final source = file.readAsStringSync();
    const chainStartToken = '.collection(kConversationsCollection)';
    const chainEndToken = '.snapshots()';
    const whereToken = '.where(kChatMessageVisibleToField, arrayContains:';
    const orderByToken = '.orderBy(';

    final chainStart = source.indexOf(chainStartToken);
    expect(chainStart, greaterThanOrEqualTo(0));

    final chainEnd = source.indexOf(chainEndToken, chainStart);
    expect(chainEnd, greaterThan(chainStart));

    final queryChain = source.substring(chainStart, chainEnd);
    final whereIndex = queryChain.indexOf(whereToken);
    final orderByIndex = queryChain.indexOf(orderByToken);
    expect(
      whereIndex,
      greaterThanOrEqualTo(0),
      reason: 'the rules require the message LIST to filter on VisibleTo',
    );
    expect(
      orderByIndex,
      greaterThan(whereIndex),
      reason: 'VisibleTo must be in the same query chain before orderBy',
    );
  });
}
