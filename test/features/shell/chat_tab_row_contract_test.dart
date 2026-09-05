// SHELL-02 / SHELL-03 / SHELL-07: what a real `/v1/requests` row renders as.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_conversation_summary.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/shell/tabs/chat_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _CannedRepository implements ChatConversationsRepository {
  const _CannedRepository(this._page);

  final ChatConversationsPage _page;

  @override
  Future<ChatConversationsPage> fetchConversations() async => _page;
}

Future<void> _pump(
  WidgetTester tester,
  ChatConversationsPage page, {
  Locale locale = const Locale('en'),
}) async {
  useReduceMotion(tester);
  await tester.pumpWidget(
    wrapForTest(
      Scaffold(body: ChatTab(repository: _CannedRepository(page))),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

/// Gate 11 — assert against the ARB the app actually ships, never a literal.
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ChatTab)));

const List<Locale> _locales = <Locale>[Locale('en'), Locale('ar')];

void main() {
  // SHELL-02, P0: the live gateway row omits `conversationId`, and every one
  // of those rows used to be skipped — the inbox read empty for everyone.
  for (final Locale locale in _locales) {
    testWidgets('${locale.languageCode} · a row with no conversationId renders '
        'and routes on requestId', (tester) async {
      await _pump(
        tester,
        const ChatConversationsPage(
          conversations: <ChatConversationSummary>[
            ChatConversationSummary(
              requestId: 'req-1',
              conversationId: '',
              title: 'Pharmacy run',
              status: OrderRequestStatus.enRoute,
            ),
          ],
        ),
        locale: locale,
      );

      expect(find.bySemanticsIdentifier('chat_tab_row_req-1'), findsOneWidget);
      expect(find.text('Pharmacy run'), findsOneWidget);
    });

    testWidgets('${locale.languageCode} · an unroutable row raises the '
        'partial-load note', (tester) async {
      await _pump(
        tester,
        const ChatConversationsPage(
          conversations: <ChatConversationSummary>[
            ChatConversationSummary(
              requestId: 'req-1',
              conversationId: '',
              status: OrderRequestStatus.matched,
            ),
          ],
          skippedRows: 1,
        ),
        locale: locale,
      );

      expect(
        find.bySemanticsIdentifier('chat_tab_partial_note'),
        findsOneWidget,
      );
      expect(find.text(_l10n(tester).chatPartialLoadBody), findsOneWidget);
    });
  }

  testWidgets('no skipped rows means no note at all', (tester) async {
    await _pump(
      tester,
      const ChatConversationsPage(
        conversations: <ChatConversationSummary>[
          ChatConversationSummary(
            requestId: 'req-1',
            conversationId: 'conv-1',
            status: OrderRequestStatus.matched,
          ),
        ],
      ),
    );

    expect(find.bySemanticsIdentifier('chat_tab_partial_note'), findsNothing);
  });

  // SHELL-03: the wire token never reaches the subtitle.
  for (final Locale locale in _locales) {
    testWidgets('${locale.languageCode} · InTransit renders the localized '
        'status, not the token', (tester) async {
      await _pump(
        tester,
        ChatConversationsPage(
          conversations: <ChatConversationSummary>[
            ChatConversationSummary(
              requestId: 'req-1',
              conversationId: 'conv-1',
              title: 'Pharmacy run',
              status: OrderRequestStatus.parse('InTransit'),
            ),
          ],
        ),
        locale: locale,
      );

      expect(
        find.text(_l10n(tester).orderHistoryStatusEnRoute),
        findsOneWidget,
      );
      expect(find.text('InTransit'), findsNothing);
    });

    testWidgets('${locale.languageCode} · an unrecognised status renders NO '
        'subtitle', (tester) async {
      await _pump(
        tester,
        ChatConversationsPage(
          conversations: <ChatConversationSummary>[
            ChatConversationSummary(
              requestId: 'req-1',
              conversationId: 'conv-1',
              title: 'Pharmacy run',
              status: OrderRequestStatus.parse('awaiting_jeeber_acceptance'),
            ),
          ],
        ),
        locale: locale,
      );

      final AppLocalizations l10n = _l10n(tester);
      expect(find.text('Pharmacy run'), findsOneWidget);
      expect(find.text('awaiting_jeeber_acceptance'), findsNothing);
      expect(find.text(l10n.orderHistoryStatusPending), findsNothing);
      expect(find.text(l10n.orderHistoryStatusEnRoute), findsNothing);
    });
  }

  // SHELL-07: the fallback title used to be a hard-coded English literal.
  for (final Locale locale in _locales) {
    testWidgets('a title-less row falls back to the localized title '
        '(${locale.languageCode})', (tester) async {
      await _pump(
        tester,
        const ChatConversationsPage(
          conversations: <ChatConversationSummary>[
            ChatConversationSummary(
              requestId: 'req-1',
              conversationId: 'conv-1',
              status: OrderRequestStatus.pending,
            ),
          ],
        ),
        locale: locale,
      );

      expect(
        find.text(_l10n(tester).chatConversationFallbackTitle),
        findsOneWidget,
      );
      expect(find.text('Delivery'), findsNothing);
    });
  }
}
