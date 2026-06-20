// P1 — orders-compose-request-in-chat (SC-030/SC-031, D83).
//
// Pins the compose-the-request-in-chat ENTRY: a successful request submit must
// open the ORDER-CHAT COMPOSE surface (`/chat/<requestId>`, the `chat-detail`
// route) rather than dead-ending back at the Requests tab (`/`). That surface
// is `ChatDetailScreen`, whose compose state fires the broadcast hook on the
// first message (live gateway `POST /v1/matching/find-jeebers` + `/v1/matching/
// broadcast`) → waiting-no-coverage.
//
// We assert the router LOCATION flips to `/chat/<requestId>` on submit. We do
// not mount the heavy `ChatDetailScreen` body (it self-resolves Dio/RoleCubit
// from the live tree); a minimal stub route stands in so the test stays a fast,
// deterministic navigation pin of the request-summary → compose-chat edge.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/request_summary/application/request_summary_cubit.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/presentation/request_summary_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_request_submission_service.dart';
import '../../support/sync_app_localizations.dart';

const _draft = RequestDraft(
  description: 'A box of pastries from Hamra',
  tierName: 'Express',
  pickupAddress: '12 Hamra St, Beirut',
  dropoffAddress: '88 Verdun Ave, Beirut',
);

/// Builds a 3-route GoRouter:
///   /summary       → the screen under test (BlocProvider-wrapped)
///   /chat/:id      → a stub that records the resolved id (the compose target)
///   /              → a stub Requests-tab landing (the fallback)
GoRouter _router(FakeRequestSubmissionService service) {
  return GoRouter(
    initialLocation: '/summary',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('requests-tab'))),
      ),
      GoRoute(
        path: '/summary',
        builder: (context, state) => BlocProvider<RequestSummaryCubit>(
          create: (_) =>
              RequestSummaryCubit(service)..setDraft(_draft),
          child: const RequestSummaryScreen(),
        ),
      ),
      GoRoute(
        path: '/chat/:id',
        name: 'chat-detail',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Text('compose-chat:${state.pathParameters['id']}'),
          ),
        ),
      ),
    ],
  );
}

Widget _harness(GoRouter router) {
  return MaterialApp.router(
    routerConfig: router,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  group('request-summary → compose-request-in-chat entry (P1)', () {
    testWidgets(
      'a successful submit opens /chat/<requestId> (the compose surface), '
      'NOT the Requests tab',
      (tester) async {
        final service = FakeRequestSubmissionService(requestId: 'req-9001');
        final router = _router(service);
        await tester.pumpWidget(_harness(router));
        await tester.pumpAndSettle();

        // Sanity: we start on the summary screen with the draft rendered.
        expect(find.text('A box of pastries from Hamra'), findsOneWidget);

        await tester.tap(
          find.widgetWithText(OmdsLoadingButton, 'Submit Request'),
        );
        await tester.pumpAndSettle();

        expect(service.submitCount, 1);
        // Landed on the order-chat compose surface keyed on the created id.
        expect(find.text('compose-chat:req-9001'), findsOneWidget);
        expect(find.text('requests-tab'), findsNothing);
        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          '/chat/req-9001',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a created request with a blank id falls back to the Requests tab '
      '(never routes to a bare /chat/)',
      (tester) async {
        final service = FakeRequestSubmissionService(requestId: '');
        final router = _router(service);
        await tester.pumpWidget(_harness(router));
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(OmdsLoadingButton, 'Submit Request'),
        );
        await tester.pumpAndSettle();

        expect(service.submitCount, 1);
        expect(find.text('requests-tab'), findsOneWidget);
        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          '/',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
