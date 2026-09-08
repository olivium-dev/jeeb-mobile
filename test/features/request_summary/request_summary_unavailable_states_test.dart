// ES-17/ES-18 — the unavailable screen's block used a SCREEN NAME as its
// headline and broke the `<screen>_error` identifier triple, and the summary's
// loading rung used the app-bar title as its headline.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/features/request_summary/application/request_summary_cubit.dart';
import 'package:jeeb_mobile/features/request_summary/presentation/request_summary_screen.dart';
import 'package:jeeb_mobile/features/request_summary/presentation/request_summary_unavailable_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_request_submission_service.dart';
import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

Widget _harness(Widget child, {Locale locale = const Locale('en')}) {
  final GoRouter router = GoRouter(
    initialLocation: '/x',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(path: '/x', builder: (_, _) => child),
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

void main() {
  group('RequestSummaryUnavailableScreen', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('carries the `_error` identifier and an exit CTA · '
          '${locale.languageCode}', (WidgetTester tester) async {
        useReduceMotion(tester);
        await tester.pumpWidget(
          _harness(const RequestSummaryUnavailableScreen(), locale: locale),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('request_summary_unavailable_error'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('request_summary_unavailable_exit_cta'),
          findsOneWidget,
        );
        // The pre-redesign hook stays wired.
        expect(
          find.byKey(const Key('request-summary-unavailable-state')),
          findsOneWidget,
        );
      });
    }

    testWidgets('the headline is an ABSENCE, not the screen name', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        _harness(const RequestSummaryUnavailableScreen()),
      );
      await tester.pumpAndSettle();

      final JeebEmptyState block =
          tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      expect(block.headline, 'This request is no longer available');
      expect(block.reason, JeebEmptyStateReason.notFound);
    });
  });

  group('RequestSummaryScreen · loading rung', () {
    testWidgets('uses its own headline, not the app-bar title', (
      WidgetTester tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        _harness(
          BlocProvider<RequestSummaryCubit>(
            create: (_) => RequestSummaryCubit(FakeRequestSubmissionService()),
            child: const RequestSummaryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('request_summary_loading'),
        findsOneWidget,
      );
      final JeebEmptyState block =
          tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));
      // The bar's own title is still on screen; the block must NOT repeat it.
      expect(block.headline, isNot('Review & send'));
      expect(block.status, JeebEmptyStateStatus.loading);
    });
  });
}
