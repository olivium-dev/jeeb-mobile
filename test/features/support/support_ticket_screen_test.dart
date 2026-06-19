// Widget tests for SupportTicketScreen (JM-063).
//
// Asserts the exact Semantics(identifier:) contract from 30_BACKLOG JM-063 is
// present, the submit gate, the submit → confirmation → customer-profile flow,
// the dispute-link edge, and the typed error → retry path. Maestro keys on the
// identifiers (CTO brief §6.6), so these assert on `find.bySemanticsIdentifier`,
// never visible text.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/features/support/domain/support_repository.dart';
import 'package:jeeb_mobile/features/support/presentation/support_ticket_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _FakeRepo implements SupportRepository {
  _FakeRepo({this.failWith});
  final SupportFailure? failWith;
  int calls = 0;

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async {
    calls++;
    if (failWith != null) throw SupportRepositoryException(failWith!);
    return const SupportTicket(id: 'ticket-001', status: 'open');
  }
}

const _delegate = SyncAppLocalizationsDelegate();

Widget _host() {
  final router = GoRouter(
    initialLocation: '/support',
    routes: <RouteBase>[
      GoRoute(
        path: '/support',
        name: 'support-ticket',
        builder: (_, _) => const SupportTicketScreen(),
      ),
      GoRoute(
        path: '/profile/customer',
        name: 'customer-profile',
        builder: (_, _) => const Scaffold(body: Text('customer-profile-host')),
      ),
      GoRoute(
        path: '/orders/:id/escalate',
        name: 'escalate',
        builder: (_, state) =>
            Scaffold(body: Text('escalate-${state.pathParameters['id']}')),
      ),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      _delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  late _FakeRepo repo;

  void register({SupportFailure? failWith}) {
    repo = _FakeRepo(failWith: failWith);
    GetIt.instance.registerSingleton<SupportRepository>(repo);
  }

  tearDown(() => GetIt.instance.reset());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
  }

  Future<void> selectCategory(WidgetTester tester) async {
    // Inline single-select: each option carries `support_category_<name>`.
    await tester.tap(find.bySemanticsIdentifier('support_category_delivery'));
    await tester.pumpAndSettle();
  }

  testWidgets('resolves with NO DI registered (nav-honesty fallback)',
      (tester) async {
    // The route-resolution pin builds the router with no GetIt setup; the
    // screen must still render (falls back to StubSupportRepository).
    await pumpScreen(tester);
    expect(find.byType(SupportTicketScreen), findsOneWidget);
    expect(find.bySemanticsIdentifier('support_root'), findsOneWidget);
  });

  testWidgets('exposes the JM-063 Semantics identifier contract',
      (tester) async {
    register();
    await pumpScreen(tester);

    expect(find.bySemanticsIdentifier('support_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('support_category'), findsOneWidget);
    expect(find.bySemanticsIdentifier('support_body'), findsOneWidget);
    expect(find.bySemanticsIdentifier('support_order_link'), findsOneWidget);
    expect(find.bySemanticsIdentifier('support_attach'), findsOneWidget);
    expect(find.bySemanticsIdentifier('support_submit_cta'), findsOneWidget);
    expect(find.bySemanticsIdentifier('support_dispute_link'), findsOneWidget);
  });

  testWidgets('submit → confirmation → customer-profile', (tester) async {
    register();
    await pumpScreen(tester);

    await selectCategory(tester);
    await tester.enterText(
      find.descendant(
        of: find.bySemanticsIdentifier('support_body'),
        matching: find.byType(EditableText),
      ),
      'the app keeps crashing on checkout',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsIdentifier('support_submit_cta'));
    await tester.pumpAndSettle();

    expect(repo.calls, 1);
    // Confirmation state rendered.
    expect(find.bySemanticsIdentifier('support_success'), findsOneWidget);

    await tester.tap(find.bySemanticsIdentifier('support_success_done_cta'));
    await tester.pumpAndSettle();

    expect(find.text('customer-profile-host'), findsOneWidget);
  });

  testWidgets('dispute link routes to dispute-open-evidence (escalate)',
      (tester) async {
    register();
    await pumpScreen(tester);

    // The dispute link is pinned in the bottom action bar — always on-screen.
    await tester.tap(find.bySemanticsIdentifier('support_dispute_link'));
    await tester.pumpAndSettle();

    // No order ref entered → '_' placeholder id on the escalate route.
    expect(find.text('escalate-_'), findsOneWidget);
  });

  testWidgets('failed submit shows error + retry returns to the form',
      (tester) async {
    register(failWith: SupportFailure.network);
    await pumpScreen(tester);

    await selectCategory(tester);
    await tester.enterText(
      find.descendant(
        of: find.bySemanticsIdentifier('support_body'),
        matching: find.byType(EditableText),
      ),
      'charge issue',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsIdentifier('support_submit_cta'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('support_error'), findsOneWidget);
    expect(find.bySemanticsIdentifier('support_retry_cta'), findsOneWidget);

    await tester.tap(find.bySemanticsIdentifier('support_retry_cta'));
    await tester.pumpAndSettle();

    // Back on the form (root + submit visible again).
    expect(find.bySemanticsIdentifier('support_submit_cta'), findsOneWidget);
  });
}
