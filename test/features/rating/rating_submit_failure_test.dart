// UX-07 — a failed submit routed home exactly like a successful one: the
// rating was silently discarded and the user was told it had been sent.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/features/rating/presentation/rating_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _ScriptedRatingRepository implements RatingRepository {
  _ScriptedRatingRepository({this.throwOnSubmit = false});

  final bool throwOnSubmit;
  int submits = 0;

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {
    submits++;
    if (throwOnSubmit) {
      throw const RatingRepositoryException(RatingFailure.network);
    }
  }

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async =>
      RatingStatus(
        deliveryId: deliveryId,
        revealState: RatingRevealState.pendingMine,
      );
}

Future<GoRouter> _pumpRating(
  WidgetTester tester,
  RatingRepository repository, {
  Locale locale = const Locale('en'),
}) async {
  final router = GoRouter(
    initialLocation: '/rate',
    routes: <RouteBase>[
      GoRoute(
        path: '/rate',
        builder: (_, _) => RatingScreen(
          deliveryId: 'DLV-1',
          repository: repository,
          initialStars: 4,
        ),
      ),
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('home'))),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MaterialApp.router(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('a failed submit STAYS on the screen and says so, EN + AR',
      (tester) async {
    for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
      useReduceMotion(tester);
      final repo = _ScriptedRatingRepository(throwOnSubmit: true);
      await _pumpRating(tester, repo, locale: locale);

      await tester.tap(find.bySemanticsIdentifier('rating_submit_cta'));
      await tester.pumpAndSettle();

      expect(repo.submits, 1);
      expect(
        find.bySemanticsIdentifier('rating_root'),
        findsOneWidget,
        reason: 'locale: $locale — the screen must not route home',
      );
      expect(find.text('home'), findsNothing);
      expect(
        find.bySemanticsIdentifier('rating_submit_error'),
        findsOneWidget,
      );
      // The terminal screen must leave exactly one way out after a failure.
      expect(
        find.bySemanticsIdentifier('rating_skip_cta'),
        findsOneWidget,
      );
    }
  });

  testWidgets('the success path still routes home', (tester) async {
    useReduceMotion(tester);
    final repo = _ScriptedRatingRepository();
    await _pumpRating(tester, repo);

    await tester.tap(find.bySemanticsIdentifier('rating_submit_cta'));
    await tester.pumpAndSettle();

    expect(repo.submits, 1);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('the escape hatch routes home', (tester) async {
    useReduceMotion(tester);
    await _pumpRating(
      tester,
      _ScriptedRatingRepository(throwOnSubmit: true),
    );

    await tester.tap(find.bySemanticsIdentifier('rating_submit_cta'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsIdentifier('rating_skip_cta'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });
}
