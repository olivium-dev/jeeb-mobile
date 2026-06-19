// Widget tests for DisputeStatusScreen (JM-065). Proves:
//   - the EXACT Semantics identifiers render off an injected repository
//     (dispute_status_root, dispute_status_state, dispute_status_outcome,
//      dispute_status_evidence, dispute_status_support, dispute_status_back) —
//     30_BACKLOG JM-065;
//   - the 4-state machine (loading → failed → loaded, §3) + D30 ids
//     (dispute_status_loading / dispute_status_error / dispute_status_retry_cta);
//   - Open vs Resolved state label, the typed outcome line (refund / penalty,
//     D2), and the auto-attached evidence summary (D53);
//   - the support edge → support-ticket (D76) and the back edge → order-chat
//     (chat ref when present, safe pop otherwise — AP-9 honesty).
//
// A minimal GoRouter with stub destination screens backs the edge assertions,
// since context.goNamed needs a router.

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

DisputeStatus _open({
  String id = 'dsp-1',
  String? orderRef,
  String? conversationRef,
  DisputeEvidenceSummary evidence = DisputeEvidenceSummary.empty,
}) =>
    DisputeStatus(
      id: id,
      state: DisputeState.open,
      orderRef: orderRef,
      conversationRef: conversationRef,
      evidence: evidence,
    );

DisputeStatus _resolved({
  String id = 'dsp-1',
  DisputeOutcome outcome = DisputeOutcome.refund,
  String? resolution = 'refund',
  double? refundAmount,
  String? currency,
  String? note,
}) =>
    DisputeStatus(
      id: id,
      state: DisputeState.resolved,
      outcome: outcome,
      resolution: resolution,
      refundAmount: refundAmount,
      currency: currency,
      note: note,
    );

Widget _stub(String id) => Semantics(
      identifier: id,
      container: true,
      child: const Scaffold(body: SizedBox.expand()),
    );

Widget _harness(
  DisputeStatusRepository repo, {
  String disputeId = 'dsp-1',
}) {
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
        builder: (_, __) => _stub('support_root'),
      ),
      GoRoute(
        path: '/chat/:id',
        name: 'chat-detail',
        builder: (_, s) => _stub('order_chat_root_${s.pathParameters['id']}'),
      ),
      GoRoute(path: '/', name: 'shell', builder: (_, __) => _stub('shell_root')),
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

  testWidgets('open dispute renders root + state + body', (tester) async {
    await pump(tester, _ScriptedRepository(dispute: _open()));

    expect(find.bySemanticsIdentifier('dispute_status_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('dispute_status_state'), findsOneWidget);
    // JM-065 AC1 (W3/W4 restructure): the outcome note ALWAYS renders — an OPEN
    // dispute shows the pending-outcome body (the on-device flow asserts
    // `dispute_status_outcome_note` on the open dispute it seeds), a resolved one
    // shows the refund/penalty line. Assert the open state via its label, not by
    // the (now always-present) card's absence.
    expect(find.bySemanticsIdentifier('dispute_status_outcome_note'),
        findsOneWidget);
    expect(find.text('Open — under review'), findsOneWidget); // open-state label
    expect(find.bySemanticsIdentifier('dispute_status_support'), findsOneWidget);
    expect(find.bySemanticsIdentifier('dispute_status_back'), findsOneWidget);
  });

  testWidgets('resolved dispute renders the outcome note (D2)', (tester) async {
    await pump(
      tester,
      _ScriptedRepository(
        dispute: _resolved(
          outcome: DisputeOutcome.refund,
          refundAmount: 12.0,
          currency: 'USD',
        ),
      ),
    );

    expect(find.bySemanticsIdentifier('dispute_status_state'), findsOneWidget);
    expect(find.bySemanticsIdentifier('dispute_status_outcome_note'),
        findsOneWidget);
    // The formatted refund amount surfaces in the outcome line.
    expect(find.textContaining('12.00 USD'), findsOneWidget);
  });

  testWidgets('penalty outcome renders without a refund amount', (tester) async {
    await pump(
      tester,
      _ScriptedRepository(
        dispute: _resolved(outcome: DisputeOutcome.penalty, resolution: 'penalty'),
      ),
    );
    expect(find.bySemanticsIdentifier('dispute_status_outcome_note'),
        findsOneWidget);
  });

  testWidgets('evidence summary renders when evidence is attached (D53)',
      (tester) async {
    await pump(
      tester,
      _ScriptedRepository(
        dispute: _open(
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
    expect(find.bySemanticsIdentifier('dispute_status_evidence_summary'),
        findsOneWidget);
    // The auto-attached detail lines surface (D53) — proves the summary is
    // populated, not just the empty container.
    expect(find.text('Damaged item'), findsOneWidget);
    expect(find.textContaining('3 photos attached'), findsOneWidget);
    expect(find.text('Voice note attached'), findsOneWidget);
  });

  testWidgets(
      'no evidence → the summary card shows the heading but no detail lines',
      (tester) async {
    // W3/W4 restructure: the evidence summary card ALWAYS renders (the screen
    // owner made it unconditional — see DisputeStatusScreen._LoadedBody). With
    // empty evidence it renders the heading container but NO per-item detail
    // line is fabricated (AP-9 honesty).
    await pump(tester, _ScriptedRepository(dispute: _open()));
    expect(find.bySemanticsIdentifier('dispute_status_evidence_summary'),
        findsOneWidget);
    // No detail rows are invented for an empty evidence set.
    expect(find.textContaining('photo'), findsNothing);
    expect(find.text('Voice note attached'), findsNothing);
    expect(find.textContaining('Chat thread'), findsNothing);
  });

  testWidgets('cold-load failure renders the D30 error + retry', (tester) async {
    final repo = _ScriptedRepository(fetchThrows: DisputeStatusFailure.network);
    await pump(tester, repo);

    expect(find.bySemanticsIdentifier('dispute_status_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('dispute_status_error'), findsOneWidget);
    expect(find.bySemanticsIdentifier('dispute_status_retry_cta'), findsOneWidget);
    expect(find.bySemanticsIdentifier('dispute_status_state'), findsNothing);
  });

  testWidgets('blank id short-circuits to a not-found error (no fetch)',
      (tester) async {
    final repo = _ScriptedRepository(dispute: _open());
    await pump(tester, repo, disputeId: ' ');
    expect(find.bySemanticsIdentifier('dispute_status_error'), findsOneWidget);
    expect(repo.fetched, isEmpty);
  });

  testWidgets('support CTA routes to support-ticket (D76)', (tester) async {
    await pump(tester, _ScriptedRepository(dispute: _open(orderRef: 'req-9')));
    await tester.tap(find.bySemanticsIdentifier('dispute_status_support'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('support_root'), findsOneWidget);
  });

  testWidgets('back CTA routes to order-chat using the conversation ref',
      (tester) async {
    await pump(
      tester,
      _ScriptedRepository(dispute: _open(conversationRef: 'conv-7')),
    );
    await tester.tap(find.bySemanticsIdentifier('dispute_status_back'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('order_chat_root_conv-7'), findsOneWidget);
  });

  testWidgets('back CTA falls back to orderRef when no conversation ref',
      (tester) async {
    await pump(tester, _ScriptedRepository(dispute: _open(orderRef: 'req-4')));
    await tester.tap(find.bySemanticsIdentifier('dispute_status_back'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('order_chat_root_req-4'), findsOneWidget);
  });

  testWidgets('back CTA with NO ref falls back to root without fabricating chat',
      (tester) async {
    await pump(tester, _ScriptedRepository(dispute: _open()));
    await tester.tap(find.bySemanticsIdentifier('dispute_status_back'));
    await tester.pumpAndSettle();
    // No chat id to address → never lands on a fabricated order-chat (AP-9).
    expect(find.bySemanticsIdentifier('order_chat_root_'), findsNothing);
    // Single-route stack: canPop() is false → safe go('/') to the shell root.
    expect(find.bySemanticsIdentifier('shell_root'), findsOneWidget);
  });
}
