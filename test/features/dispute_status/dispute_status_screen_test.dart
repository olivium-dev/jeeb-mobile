// Widget tests for DisputeStatusScreen (JM-065). Proves:

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/features/dispute_status/domain/dispute_status_repository.dart';
import 'package:jeeb_mobile/features/dispute_status/presentation/dispute_status_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _ScriptedRepository implements DisputeStatusRepository {
  _ScriptedRepository({this.dispute, this.fetchThrows});

  final DisputeStatus? dispute;
  final DisputeStatusFailure? fetchThrows;
  final List<String> fetched = <String>[];

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async {
    fetched.add(disputeId);
    final f = fetchThrows;
    if (f != null) throw DisputeStatusRepositoryException(f);
    return dispute!;
  }
}

DisputeStatus _pending({
  String id = 'dsp-1',
  String? orderRef,
  String? conversationRef,
  DisputeEvidenceSummary evidence = DisputeEvidenceSummary.empty,
}) => DisputeStatus(
  id: id,
  state: DisputeState.pending,
  orderRef: orderRef,
  conversationRef: conversationRef,
  evidence: evidence,
);

DisputeStatus _fixed({String id = 'dsp-1', String? note}) =>
    DisputeStatus(id: id, state: DisputeState.fixed, note: note);

Widget _stub(String id) => Semantics(
  identifier: id,
  container: true,
  child: const Scaffold(body: SizedBox.expand()),
);

Widget _harness(DisputeStatusRepository repo, {String disputeId = 'dsp-1'}) {
  final router = GoRouter(
    initialLocation: '/disputes/$disputeId',
    routes: [
      GoRoute(
        path: '/disputes/:id',
        name: 'dispute-status',
        builder: (_, s) => DisputeStatusScreen(
          disputeId: s.pathParameters['id'] ?? '',
          repository: repo,
        ),
      ),
      GoRoute(
        path: '/support',
        name: 'support-ticket',
        builder: (_, _) => _stub('support_root'),
      ),
      GoRoute(
        path: '/chat/:id',
        name: 'chat-detail',
        builder: (_, s) => _stub('order_chat_root_${s.pathParameters['id']}'),
      ),
      GoRoute(path: '/', name: 'shell', builder: (_, _) => _stub('shell_root')),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    // The pre-load frames mount JeebEmptyState, whose radar loops by design, so
    // pumpAndSettle can only settle under reduce motion (02-STUDY-NOTES).
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  );
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    DisputeStatusRepository repo, {
    String disputeId = 'dsp-1',
  }) async {
    await tester.pumpWidget(_harness(repo, disputeId: disputeId));
    await tester.pumpAndSettle();
  }

  testWidgets('pending dispute renders root + state + body', (tester) async {
    await pump(tester, _ScriptedRepository(dispute: _pending()));

    expect(find.bySemanticsIdentifier('dispute_status_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('dispute_status_state'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('dispute_status_outcome'),
      findsOneWidget,
    );
    expect(find.text('Pending'), findsWidgets);
    expect(
      find.bySemanticsIdentifier('dispute_status_support'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('dispute_status_back'), findsOneWidget);
  });

  testWidgets('fixed dispute renders a neutral read-only resolution note', (
    tester,
  ) async {
    await pump(
      tester,
      _ScriptedRepository(dispute: _fixed(note: 'Issue corrected by support.')),
    );

    expect(find.bySemanticsIdentifier('dispute_status_state'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('dispute_status_outcome'),
      findsOneWidget,
    );
    expect(find.text('Issue corrected by support.'), findsOneWidget);
    expect(find.textContaining('refund', findRichText: true), findsNothing);
  });

  testWidgets('closed is read-only and exposes no close action', (
    tester,
  ) async {
    await pump(
      tester,
      _ScriptedRepository(
        dispute: const DisputeStatus(
          id: 'dsp-1',
          state: DisputeState.closed,
          note: 'Review complete.',
        ),
      ),
    );
    expect(
      find.bySemanticsIdentifier('dispute_status_outcome'),
      findsOneWidget,
    );
    expect(find.text('Closed'), findsWidgets);
    expect(find.textContaining('Close dispute'), findsNothing);
  });

  testWidgets('evidence summary renders when evidence is attached (D53)', (
    tester,
  ) async {
    await pump(
      tester,
      _ScriptedRepository(
        dispute: _pending(
          evidence: const DisputeEvidenceSummary(
            reason: 'damaged',
            comment: 'box was crushed',
            photoCount: 3,
            hasVoice: true,
            hasChatSnapshot: true,
            chatMessageCount: 8,
            timelineCount: 4,
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsIdentifier('dispute_status_evidence_summary'),
      findsOneWidget,
    );
    // The auto-attached detail lines surface (D53) — proves the summary is
    expect(find.text('Damaged item'), findsOneWidget);
    expect(find.textContaining('3 photos attached'), findsOneWidget);
    expect(find.text('Voice note attached'), findsOneWidget);
  });

  testWidgets(
    'no evidence → the summary card shows the heading but no detail lines',
    (tester) async {
      // W3/W4 restructure: the evidence summary card ALWAYS renders (the screen
      await pump(tester, _ScriptedRepository(dispute: _pending()));
      expect(
        find.bySemanticsIdentifier('dispute_status_evidence_summary'),
        findsOneWidget,
      );
      // No detail rows are invented for an empty evidence set.
      expect(find.textContaining('photo'), findsNothing);
      expect(find.text('Voice note attached'), findsNothing);
      expect(find.textContaining('Chat thread'), findsNothing);
    },
  );

  testWidgets('cold-load failure renders the D30 error + retry', (
    tester,
  ) async {
    final repo = _ScriptedRepository(fetchThrows: DisputeStatusFailure.network);
    await pump(tester, repo);

    expect(find.bySemanticsIdentifier('dispute_status_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('dispute_status_error'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('dispute_status_retry_cta'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('dispute_status_state'), findsNothing);
  });

  testWidgets('blank id short-circuits to a not-found error (no fetch)', (
    tester,
  ) async {
    final repo = _ScriptedRepository(dispute: _pending());
    await pump(tester, repo, disputeId: ' ');
    expect(find.bySemanticsIdentifier('dispute_status_error'), findsOneWidget);
    expect(repo.fetched, isEmpty);
  });

  testWidgets('support CTA routes to support-ticket (D76)', (tester) async {
    await pump(
      tester,
      _ScriptedRepository(dispute: _pending(orderRef: 'req-9')),
    );
    await tester.tap(find.bySemanticsIdentifier('dispute_status_support'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('support_root'), findsOneWidget);
  });

  testWidgets('back CTA routes to order-chat using the conversation ref', (
    tester,
  ) async {
    await pump(
      tester,
      _ScriptedRepository(dispute: _pending(conversationRef: 'conv-7')),
    );
    await tester.tap(find.bySemanticsIdentifier('dispute_status_back'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsIdentifier('order_chat_root_conv-7'),
      findsOneWidget,
    );
  });

  testWidgets('back CTA falls back to orderRef when no conversation ref', (
    tester,
  ) async {
    await pump(
      tester,
      _ScriptedRepository(dispute: _pending(orderRef: 'req-4')),
    );
    await tester.tap(find.bySemanticsIdentifier('dispute_status_back'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('order_chat_root_req-4'), findsOneWidget);
  });

  testWidgets(
    'back CTA with NO ref falls back to root without fabricating chat',
    (tester) async {
      await pump(tester, _ScriptedRepository(dispute: _pending()));
      await tester.tap(find.bySemanticsIdentifier('dispute_status_back'));
      await tester.pumpAndSettle();
      // No chat id to address → never lands on a fabricated order-chat (AP-9).
      expect(find.bySemanticsIdentifier('order_chat_root_'), findsNothing);
      // Single-route stack: canPop() is false → safe go('/') to the shell root.
      expect(find.bySemanticsIdentifier('shell_root'), findsOneWidget);
    },
  );
}
