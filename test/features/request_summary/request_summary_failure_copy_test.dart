// EP-06/TEST-20 — the summary's submit failure is rendered by `failureCopy`,
// from a classified kind, in the user's locale. The cubit used to hold four
// hard-coded English sentences.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/request_summary/application/request_summary_cubit.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/request_summary/presentation/request_summary_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_request_submission_service.dart';
import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const RequestDraft _draft = RequestDraft(
  description: 'Two bags of ice',
  tierId: 'flash',
);

/// The English bodies `failureCopy` selects, keyed by kind.
const Map<String, String> _englishBody = <String, String>{
  'network': 'Check your connection and try again.',
  'server': "We couldn't complete that. Try again in a moment.",
  'validation': 'Check the details and try again.',
  'unauthorized': 'Sign in again to continue.',
};

Widget _harness(
  RequestSubmissionService service, {
  Locale locale = const Locale('en'),
}) {
  final GoRouter router = GoRouter(
    initialLocation: '/request-summary',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(
        path: '/request-summary',
        builder: (_, _) => BlocProvider<RequestSummaryCubit>(
          create: (_) => RequestSummaryCubit(service)..setDraft(_draft),
          child: const RequestSummaryScreen(),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

Future<void> _submit(
  WidgetTester tester,
  AppFailure failure, {
  Locale locale = const Locale('en'),
}) async {
  useReduceMotion(tester);
  await tester.pumpWidget(
    _harness(
      FakeRequestSubmissionService(
        error: RequestSubmissionException.classified(
          RequestSubmissionFailure.server,
          appFailure: failure,
        ),
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
  final Finder cta = find.bySemanticsIdentifier('request_summary_submit');
  await tester.ensureVisible(cta);
  await tester.pump();
  await tester.tap(cta);
  await tester.pumpAndSettle();
}

void main() {
  group('RequestSummaryScreen · submit failure copy', () {
    testWidgets('the failure lands on the identified snack', (
      WidgetTester tester,
    ) async {
      await _submit(tester, const NetworkFailure());

      expect(
        find.bySemanticsIdentifier('request_summary_submit_error'),
        findsOneWidget,
      );
    });

    for (final MapEntry<String, AppFailure> entry
        in const <String, AppFailure>{
      'network': NetworkFailure(),
      'server': ServerFailure(status: 500),
      'validation': ValidationFailure(),
      'unauthorized': UnauthorizedFailure(),
    }.entries) {
      testWidgets('${entry.key} renders its OWN body', (
        WidgetTester tester,
      ) async {
        await _submit(tester, entry.value);

        // The screen-state contract first, then the copy it carries.
        expect(
          find.bySemanticsIdentifier('request_summary_submit_error'),
          findsOneWidget,
        );
        expect(find.text(_englishBody[entry.key]!), findsOneWidget);
      });
    }

    // COPY-09: only Network/Timeout may blame the connection.
    testWidgets('a 500 never blames the connection', (
      WidgetTester tester,
    ) async {
      await _submit(tester, const ServerFailure(status: 500));

      expect(
        find.bySemanticsIdentifier('request_summary_submit_error'),
        findsOneWidget,
      );
      expect(find.textContaining('connection'), findsNothing);
    });

    // R6: a terminal kind never carries an inert Retry.
    testWidgets('a 401 snack offers no Retry; a 500 does', (
      WidgetTester tester,
    ) async {
      await _submit(tester, const UnauthorizedFailure());
      expect(find.widgetWithText(SnackBarAction, 'Retry'), findsNothing);

      await _submit(tester, const ServerFailure(status: 500));
      expect(find.widgetWithText(SnackBarAction, 'Retry'), findsOneWidget);
    });

    testWidgets('AR renders Arabic — no English literal reaches the tree', (
      WidgetTester tester,
    ) async {
      await _submit(
        tester,
        const NetworkFailure(),
        locale: const Locale('ar'),
      );

      expect(
        find.bySemanticsIdentifier('request_summary_submit_error'),
        findsOneWidget,
      );
      for (final String english in _englishBody.values) {
        expect(find.text(english), findsNothing);
      }
      // The cubit's four retired sentences must not survive anywhere.
      expect(
        find.textContaining('Something went wrong. Please try again.'),
        findsNothing,
      );
    });
  });

  group('RequestSummaryCubit · no prose escapes the cubit', () {
    test('the state carries an AppFailure, never a String', () async {
      final RequestSummaryCubit cubit = RequestSummaryCubit(
        FakeRequestSubmissionService(
          error: const RequestSubmissionException.classified(
            RequestSubmissionFailure.network,
            appFailure: NetworkFailure(offline: true),
          ),
        ),
      )..setDraft(_draft);

      await cubit.submit();

      expect(cubit.state.error, const NetworkFailure(offline: true));
      await cubit.close();
    });
  });
}
