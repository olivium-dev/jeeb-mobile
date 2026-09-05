// EP-02 / ES-01 / EP-03 / SHELL-04 / SHELL-06 / LR-01: the inbox has a failure
// rung, a loading rung, a real empty rung, and a way back from all of them.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_pull_to_refresh.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_state_host.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_conversation_summary.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/shell/tabs/chat_tab.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

/// Answers whatever the script says, one call at a time; the last entry
/// repeats. `null` means "never answers".
class _ScriptedRepository implements ChatConversationsRepository {
  _ScriptedRepository(this._script);

  final List<Future<ChatConversationsPage> Function()?> _script;
  int calls = 0;

  @override
  Future<ChatConversationsPage> fetchConversations() {
    final entry = _script[calls < _script.length ? calls : _script.length - 1];
    calls++;
    if (entry == null) return Completer<ChatConversationsPage>().future;
    return entry();
  }
}

ChatConversationsPage _rows(int count) => ChatConversationsPage(
      conversations: <ChatConversationSummary>[
        for (int i = 0; i < count; i++)
          ChatConversationSummary(
            requestId: 'req-$i',
            conversationId: 'conv-$i',
            title: 'Row $i',
            status: OrderRequestStatus.enRoute,
          ),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  ChatConversationsRepository? repository, {
  Locale locale = const Locale('en'),
}) async {
  useReduceMotion(tester);
  await tester.pumpWidget(
    wrapForTest(
      Scaffold(body: ChatTab(repository: repository)),
      locale: locale,
    ),
  );
}

void main() {
  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String tag = locale.languageCode;

    testWidgets('$tag · the first frame is the LOADING rung', (tester) async {
      await _pump(tester, _ScriptedRepository(<Never Function()?>[null]),
          locale: locale);
      await tester.pump();

      expect(find.bySemanticsIdentifier('chat_tab_loading'), findsOneWidget);
      expect(find.bySemanticsIdentifier('chat_tab_empty'), findsNothing);
      expect(find.bySemanticsIdentifier('chat_tab_error'), findsNothing);
    });

    testWidgets('$tag · a 503 is the ERROR rung, never the empty one',
        (tester) async {
      await _pump(
        tester,
        _ScriptedRepository(<Future<ChatConversationsPage> Function()?>[
          () async => throw const ServerFailure(status: 503),
        ]),
        locale: locale,
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('chat_tab_error'), findsOneWidget);
      expect(find.bySemanticsIdentifier('chat_tab_retry_cta'), findsOneWidget);
      // The defect, pinned: "No conversations yet" over a gateway outage.
      expect(find.bySemanticsIdentifier('chat_tab_empty'), findsNothing);
    });

    testWidgets('$tag · a 200 with no rows is the EMPTY rung', (tester) async {
      await _pump(
        tester,
        _ScriptedRepository(<Future<ChatConversationsPage> Function()?>[
          () async => ChatConversationsPage.empty,
        ]),
        locale: locale,
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('chat_tab_empty'), findsOneWidget);
      expect(find.bySemanticsIdentifier('chat_tab_error'), findsNothing);
    });
  }

  testWidgets('tapping retry re-issues the read and lands the rows',
      (tester) async {
    final repo = _ScriptedRepository(<Future<ChatConversationsPage> Function()?>[
      () async => throw const ServerFailure(status: 503),
      () async => _rows(2),
    ]);
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('chat_tab_error'), findsOneWidget);

    await tester.tap(find.bySemanticsIdentifier('chat_tab_retry_cta'));
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
    expect(find.bySemanticsIdentifier('chat_tab_error'), findsNothing);
    expect(find.text('Row 0'), findsOneWidget);
  });

  // EP-03 / SHELL-04: the typed-only catch left `_loading` true forever.
  testWidgets('a parse failure ends in the ERROR rung, never a stuck spinner',
      (tester) async {
    await _pump(
      tester,
      _ScriptedRepository(<Future<ChatConversationsPage> Function()?>[
        () async => throw TypeError(),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('chat_tab_error'), findsOneWidget);
    expect(find.bySemanticsIdentifier('chat_tab_loading'), findsNothing);
  });

  // SHELL-06: an unresolvable repository rendered "No conversations yet".
  testWidgets('DI that resolves nothing is a FAILURE, not an empty inbox',
      (tester) async {
    await _pump(tester, null);
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('chat_tab_error'), findsOneWidget);
    expect(find.bySemanticsIdentifier('chat_tab_empty'), findsNothing);
  });

  // LR-01: the shell keeps the tab alive, so a rung with no way out is
  // permanent. Every rung is pullable or has a CTA.
  testWidgets('the list rung is pull-to-refreshable', (tester) async {
    await _pump(
      tester,
      _ScriptedRepository(<Future<ChatConversationsPage> Function()?>[
        () async => _rows(3),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(JeebPullToRefresh), findsOneWidget);
  });

  testWidgets('the empty rung is pull-to-refreshable too', (tester) async {
    await _pump(
      tester,
      _ScriptedRepository(<Future<ChatConversationsPage> Function()?>[
        () async => ChatConversationsPage.empty,
      ]),
    );
    await tester.pumpAndSettle();

    final JeebStateHost host =
        tester.widget(find.byType(JeebStateHost).first);
    expect(host.onRefresh, isNotNull);
  });

  // §3.3: a WARM failure keeps the rows and adds a note above them.
  testWidgets('a refresh failure keeps the rows and raises the warm note',
      (tester) async {
    final repo = _ScriptedRepository(<Future<ChatConversationsPage> Function()?>[
      () async => _rows(2),
      () async => throw const ServerFailure(status: 500),
    ]);
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Row 0'), findsOneWidget);

    await tester.fling(find.text('Row 0'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('chat_tab_refresh_error'), findsOneWidget);
    // Stale beats blank: the rows are still there and the cold rung is not.
    expect(find.text('Row 0'), findsOneWidget);
    expect(find.bySemanticsIdentifier('chat_tab_error'), findsNothing);
  });
}
