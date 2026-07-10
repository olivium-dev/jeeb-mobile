import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/features/rating/presentation/rating_screen.dart';
import 'package:jeeb_mobile/features/rating/presentation/widgets/feedback_avatar.dart';
import 'package:jeeb_mobile/features/rating/presentation/widgets/feedback_star_input.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

/// Router-aware wrapper (the JM-034 submit navigates via `context.go('/')`, so
/// the screen-under-test needs a GoRouter in scope).
Widget _wrapRouter(GoRouter router) {
  return MaterialApp.router(
    theme: ThemeData.light(),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: router,
  );
}

/// Records the submit call so the test can assert the mandatory rating reached
/// the repository before navigating home (JM-034 AC2/AC3).
class _RecordingRatingRepo implements RatingRepository {
  int? submittedStars;
  bool? submittedIsClient;

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {
    submittedStars = stars;
    submittedIsClient = isClient;
  }

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('renders title, ratee name, avatar, stars and submit',
      (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        const RatingScreen(deliveryId: 'd-1', rateeName: 'Sami'),
      ),
    );
    await tester.pump();

    expect(find.text('We appreciate your feedback'), findsOneWidget);
    expect(find.text('Rate Sami'), findsOneWidget);
    expect(find.byKey(FeedbackAvatar.rootKey), findsOneWidget);
    expect(find.byKey(FeedbackStarInput.rootKey), findsOneWidget);
    expect(find.text('Submit feedback'), findsOneWidget);
  });

  testWidgets('client audience shows the delivery-man subtitle', (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        const RatingScreen(deliveryId: 'd-1', rateeName: 'Sami'),
      ),
    );
    await tester.pump();
    expect(
      find.textContaining('evaluate the delivery man'),
      findsOneWidget,
    );
  });

  testWidgets('jeeber audience shows the client subtitle', (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        const RatingScreen(
          deliveryId: 'd-1',
          isClient: false,
          rateeName: 'Lina',
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('evaluate the client'), findsOneWidget);
    expect(find.text('Rate Lina'), findsOneWidget);
  });

  testWidgets(
    'JM-034: selecting stars + submit persists the rating and routes to the '
    'role-aware shell (no pop, no skip control)',
    (tester) async {
      final repo = _RecordingRatingRepo();
      final router = GoRouter(
        initialLocation: '/orders/d-1/feedback',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: Center(child: Text('HOME_SHELL')),
            ),
          ),
          GoRoute(
            path: '/orders/:id/feedback',
            builder: (_, _) => RatingScreen(
              deliveryId: 'd-1',
              rateeName: 'Sami',
              repository: repo,
            ),
          ),
        ],
      );
      await tester.pumpWidget(_wrapRouter(router));
      await tester.pumpAndSettle();

      // No skip/close affordance on the mandatory path (D56).
      expect(
        find.bySemanticsIdentifier('feedback_close_button'),
        findsNothing,
      );

      // Tap the 4th star then submit. The OMDS [OmdsStarRating] renders empty
      // stars as `Icons.star_border` until selected (filled = `Icons.star`), so
      // with the initial rating of 0 the tappable stars are the borders.
      final emptyStars = find.byIcon(Icons.star_border);
      await tester.ensureVisible(emptyStars.at(3));
      await tester.pump();
      await tester.tap(emptyStars.at(3));
      await tester.pump();
      await tester.tap(find.bySemanticsIdentifier('rating_submit_cta'));
      await tester.pumpAndSettle();

      expect(repo.submittedStars, 4);
      expect(repo.submittedIsClient, true);
      // AC2: routed to the role-aware shell.
      expect(find.text('HOME_SHELL'), findsOneWidget);
    },
  );

  testWidgets('renders mirrored under Arabic locale', (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        const RatingScreen(deliveryId: 'd-1', rateeName: 'Sami'),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();

    final dir = Directionality.of(tester.element(find.byType(RatingScreen)));
    expect(dir, TextDirection.rtl);
    expect(find.text('نقدّر ملاحظاتك'), findsOneWidget);
    expect(find.text('إرسال الملاحظات'), findsOneWidget);
  });
}
