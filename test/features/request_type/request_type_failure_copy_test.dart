// RTYPE-01/ES-12 — `/request-type`'s tier catalogue had ONE unavailable view
// serving loading, empty AND every failure kind, with `requestSummaryErrorNetwork`
// as the headline for a 403. The three rungs are now distinct and identified.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_type_screen.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _Throwing implements TierRepository {
  const _Throwing(this.failure);

  final AppFailure failure;

  @override
  Future<List<Tier>> fetchTiers() async => throw failure;
}

class _Empty implements TierRepository {
  const _Empty();

  @override
  Future<List<Tier>> fetchTiers() async => const <Tier>[];
}

class _Stalled implements TierRepository {
  const _Stalled();

  @override
  Future<List<Tier>> fetchTiers() => Completer<List<Tier>>().future;
}

Widget _harness(TierRepository repo, {Locale locale = const Locale('en')}) {
  final GoRouter router = GoRouter(
    initialLocation: '/request-type',
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
      GoRoute(
        path: '/request-type',
        builder: (_, _) => RequestTypeScreen(repository: repo),
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

Future<void> _pump(
  WidgetTester tester,
  TierRepository repo, {
  Locale locale = const Locale('en'),
  bool settle = true,
}) async {
  useReduceMotion(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(_harness(repo, locale: locale));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  group('RequestTypeScreen · the three tier rungs', () {
    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('a failure renders `_error` + its retry · '
          '${locale.languageCode}', (WidgetTester tester) async {
        await _pump(
          tester,
          const _Throwing(ServerFailure(status: 500)),
          locale: locale,
        );

        expect(
          find.bySemanticsIdentifier('request_type_tiers_error'),
          findsOneWidget,
        );
        // The frozen CTA identifier survives the port.
        expect(
          find.bySemanticsIdentifier('request_type_tiers_retry'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('request_type_tiers_empty'),
          findsNothing,
        );
      });

      testWidgets('an EMPTY catalogue renders `_empty`, never `_error` · '
          '${locale.languageCode}', (WidgetTester tester) async {
        await _pump(tester, const _Empty(), locale: locale);

        expect(
          find.bySemanticsIdentifier('request_type_tiers_empty'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier('request_type_tiers_error'),
          findsNothing,
        );
      });
    }

    testWidgets('the loading rung is identified', (WidgetTester tester) async {
      await _pump(tester, const _Stalled(), settle: false);

      expect(
        find.bySemanticsIdentifier('request_type_tiers_loading'),
        findsOneWidget,
      );
    });

    // COPY-09: `requestSummaryErrorNetwork` was the headline for EVERY kind.
    testWidgets('a 403 never blames the connection', (
      WidgetTester tester,
    ) async {
      await _pump(tester, const _Throwing(ForbiddenFailure()));

      expect(find.textContaining('connection'), findsNothing);
      // R6: a terminal kind gets a way out, never an inert Retry.
      expect(
        find.bySemanticsIdentifier('request_type_tiers_retry'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('request_type_tiers_exit_cta'),
        findsOneWidget,
      );
    });

    // §3.4 rule 7: no dead Continue over a list nothing can be picked from.
    testWidgets('the Continue footer is absent on all three rungs', (
      WidgetTester tester,
    ) async {
      for (final TierRepository repo in const <TierRepository>[
        _Empty(),
        _Throwing(ServerFailure(status: 500)),
      ]) {
        await _pump(tester, repo);
        expect(
          find.bySemanticsIdentifier('request_type_continue_cta'),
          findsNothing,
        );
      }

      await _pump(tester, const _Stalled(), settle: false);
      expect(
        find.bySemanticsIdentifier('request_type_continue_cta'),
        findsNothing,
      );
    });
  });
}
