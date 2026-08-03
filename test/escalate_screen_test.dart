// Widget tests for EscalateScreen / dispute-open-evidence (JM-060; ex T-MOB-022).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/features/escalate/application/escalate_cubit.dart';
import 'package:jeeb_mobile/features/escalate/domain/escalate_repository.dart';
import 'package:jeeb_mobile/features/escalate/presentation/escalate_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

class _FakeRepo implements EscalateRepository {
  const _FakeRepo({this.failWith});
  final EscalateErrorKind? failWith;

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) async =>
      const EscalateEvidence(
        chatSnapshotUrl: 'https://cdn.jeeb.app/snapshots/conv-1.html',
        chatMessageCount: 3,
        timeline: [EscalateTimelineEntry(status: 'Ordered')],
      );

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const [],
    String? voicePath,
    EscalateEvidence evidence = EscalateEvidence.empty,
  }) async {
    if (failWith != null) throw EscalateException(failWith!);
    return const EscalateResult(caseId: 'dispute-999', status: 'open');
  }
}

// A GoRouter so the success listener (goNamed dispute-status) + support link
GoRouter _router({EscalateRepository? repo}) {
  return GoRouter(
    initialLocation: '/orders/dlv-1/escalate',
    routes: [
      GoRoute(
        path: '/orders/:id/escalate',
        name: 'escalate',
        builder: (context, state) => BlocProvider<EscalateCubit>(
          create: (_) => EscalateCubit(
            repository: repo ?? const _FakeRepo(),
            deliveryId: state.pathParameters['id'] ?? '',
          ),
          child: const EscalateScreen(),
        ),
      ),
      GoRoute(
        path: '/disputes/:id',
        name: 'dispute-status',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('dispute-status:${state.pathParameters['id']}'),
          ),
        ),
      ),
      GoRoute(
        path: '/support',
        name: 'support-ticket',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('support'))),
      ),
      GoRoute(
        path: '/',
        name: 'shell',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('home'))),
      ),
    ],
  );
}

void main() {
  // Reuse the sync localizations delegate list from the shared helper.
  final delegates = (wrapForTest(const SizedBox()) as MaterialApp)
      .localizationsDelegates!;

  Widget build({EscalateRepository? repo, Locale locale = const Locale('en')}) {
    final router = _router(repo: repo);
    return MaterialApp.router(
      theme: ThemeData.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: delegates,
      routerConfig: router,
    );
  }

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  testWidgets('renders report title and reason options', (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    expect(find.text('Report an Issue'), findsOneWidget);
    expect(find.text('Damaged item'), findsOneWidget);
    expect(find.text('Fraud'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets('exposes the blueprint dispute identifiers', (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    for (final id in const [
      'dispute_reason',
      'dispute_photos',
      'dispute_voice',
      'dispute_submit_cta',
      'dispute_support_link',
      'dispute_back',
    ]) {
      expect(byId(id), findsWidgets, reason: 'missing identifier $id');
    }
  });

  testWidgets('submit button is disabled until reason selected',
      (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    // Tapping submit with no reason is a no-op (stays on the form).
    await tester.tap(find.text('Submit Report'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Submit Report'), findsOneWidget);
  });

  testWidgets('selecting a reason and submitting routes to dispute-status',
      (tester) async {
    await tester.pumpWidget(build());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Damaged item'));
    await tester.pump();

    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(find.text('dispute-status:dispute-999'), findsOneWidget);
  });

  testWidgets('server error shows error message', (tester) async {
    await tester.pumpWidget(
      build(repo: const _FakeRepo(failWith: EscalateErrorKind.server)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('No-show'));
    await tester.pump();
    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't submit"), findsOneWidget);
  });

  testWidgets('renders in Arabic locale', (tester) async {
    await tester.pumpWidget(build(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('الإبلاغ عن مشكلة'), findsOneWidget);
    expect(find.text('عنصر تالف'), findsOneWidget);

    final dir = Directionality.of(tester.element(find.byType(EscalateScreen)));
    expect(dir, TextDirection.rtl);
  });
}
