// M3-31 per-element Midnight assertions for ReviewsListScreen.
//
// Goldens are evidence, not gates (02-STUDY-NOTES, wave-C fixup): the shared
// comparator tolerates 5% pixel diff, so re-inking five 16dp stars is invisible
// to it. Every ruling this row landed is read back off the built widget here,
// including the orange-budget defect the pass-1 code carried.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_avatar.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:jeeb_mobile/features/reviews/presentation/reviews_list_screen.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const ReviewItem _review = ReviewItem(
  id: 'review-001',
  reviewerFirstName: 'Ahmad',
  score: 4,
  timestamp: '2026-08-01T10:00:00Z',
  body: 'Arrived early and kept me posted the whole way.',
);

class _StaticRepository implements ReviewsRepository {
  const _StaticRepository(this.page);

  final ReviewsPage page;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async => this.page;

  @override
  Future<void> reportReview(String reviewId) async {}
}

class _FailingRepository implements ReviewsRepository {
  const _FailingRepository(this.failure);

  final ReviewsFailure failure;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async => throw ReviewsRepositoryException(failure);

  @override
  Future<void> reportReview(String reviewId) async {}
}

/// Never completes — holds the screen on its first-load frame.
class _PendingRepository implements ReviewsRepository {
  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) {
    return Completer<ReviewsPage>().future;
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}

Widget _harness(ReviewsRepository repository) {
  return MaterialApp(
    theme: AppTheme.midnight(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: ReviewsListScreen(jeeberId: 'jeeber-1', repository: repository),
  );
}

ReviewsPage _loadedPage({
  bool coldStart = false,
  int reviewCount = 12,
  double? averageScore = 4.6,
}) => ReviewsPage(
  reviews: const <ReviewItem>[_review],
  page: 1,
  totalPages: 1,
  coldStart: coldStart,
  reviewCount: reviewCount,
  averageScore: averageScore,
);

Color _iconColor(WidgetTester tester, Finder finder) =>
    tester.widget<Icon>(finder).color!;

TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  final JeebSemanticColors semantic = JeebSemanticColors.midnight();
  final ColorScheme scheme = AppTheme.midnight().colorScheme;

  Future<void> pumpLoaded(
    WidgetTester tester, {
    bool coldStart = false,
    int reviewCount = 12,
    double? averageScore = 4.6,
  }) async {
    await tester.pumpWidget(
      _harness(
        _StaticRepository(
          _loadedPage(
            coldStart: coldStart,
            reviewCount: reviewCount,
            averageScore: averageScore,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('field', () {
    testWidgets('content variant, glow topEnd, wash topStart, decor still', (
      tester,
    ) async {
      await pumpLoaded(tester);

      final JeebMidnightField field = tester.widget<JeebMidnightField>(
        find.byType(JeebMidnightField),
      );
      expect(field.variant, JeebFieldVariant.content);
      // Glow (orange) and wash (periwinkle) are separate layers; the M3 Tier-1
      // pairing for an R21-derived screen is topEnd + topStart.
      expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
      expect(field.washPlacement, JeebFieldWashPlacement.topStart);
      // R15 and R21 are both zero-motion tiles.
      expect(field.animateDecor, isFalse);
    });

    testWidgets('the Scaffold does not paint over the field', (tester) async {
      await pumpLoaded(tester);

      final Scaffold scaffold = tester.widget<Scaffold>(
        find.descendant(
          of: find.bySemanticsIdentifier('reviews_root'),
          matching: find.byType(Scaffold),
        ),
      );
      expect(scaffold.backgroundColor, Colors.transparent);
    });
  });

  group('row ink — the orange-budget defect', () {
    testWidgets('the five row stars are amber, never colorScheme.primary', (
      tester,
    ) async {
      await pumpLoaded(tester);

      final Finder stars = find.descendant(
        of: find.bySemanticsIdentifier('review_review-001'),
        matching: find.byIcon(Icons.star),
      );
      // score 4 → four filled amber, one empty at white 22%.
      expect(stars, findsNWidgets(5));
      for (int i = 0; i < 4; i++) {
        expect(_iconColor(tester, stars.at(i)), semantic.amber);
      }
      expect(_iconColor(tester, stars.at(4)), semantic.glassBorderVivid);
      // The pass-1 ink. Under Midnight `primary` IS `#D73B00`.
      expect(semantic.amber, isNot(scheme.primary));
      for (int i = 0; i < 5; i++) {
        expect(_iconColor(tester, stars.at(i)), isNot(scheme.primary));
      }
    });

    testWidgets('the reviewer name is onSurface, never primary', (
      tester,
    ) async {
      await pumpLoaded(tester);

      expect(_styleOf(tester, 'Ahmad').color, scheme.onSurface);
      expect(_styleOf(tester, 'Ahmad').color, isNot(scheme.primary));
    });

    testWidgets('the relative-time meta reads onSurfaceVariant', (
      tester,
    ) async {
      await pumpLoaded(tester);

      final Text meta = tester.widget<Text>(
        find.descendant(
          of: find.bySemanticsIdentifier('review_review-001'),
          matching: find.byWidgetPredicate(
            (w) => w is Text && (w.data ?? '').endsWith('ago'),
          ),
        ),
      );
      expect(meta.style!.color, scheme.onSurfaceVariant);
      // inkSoft is R21's LIT-row ink; a resting row does not take it.
      expect(meta.style!.color, isNot(scheme.onSecondaryContainer));
    });

    testWidgets('the row disc takes the glass fill', (tester) async {
      await pumpLoaded(tester);

      final JeebAvatar avatar = tester.widget<JeebAvatar>(
        find.descendant(
          of: find.bySemanticsIdentifier('review_review-001'),
          matching: find.byType(JeebAvatar),
        ),
      );
      expect(avatar.fill, JeebAvatarFill.glass);
    });
  });

  group('aggregate header', () {
    testWidgets('the score reads onSurface and its star is amber', (
      tester,
    ) async {
      await pumpLoaded(tester);

      final Text score = tester.widget<Text>(
        find.descendant(
          of: find.bySemanticsIdentifier('reviews_aggregate'),
          matching: find.byType(Text),
        ),
      );
      expect(score.style!.color, scheme.onSurface);
      expect(score.style!.color, isNot(scheme.primary));

      // The aggregate star is the first star on the screen (above the rows).
      final Color aggregateStar = _iconColor(
        tester,
        find.byIcon(Icons.star).first,
      );
      expect(aggregateStar, semantic.amber);
    });

    testWidgets('the halo is a RadialGradient, not a BoxShadow', (
      tester,
    ) async {
      await pumpLoaded(tester);

      final Iterable<BoxDecoration> halos = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.gradient is RadialGradient);
      final BoxDecoration halo = halos.firstWhere(
        (d) =>
            (d.gradient! as RadialGradient).colors.first.a > 0 &&
            (d.gradient! as RadialGradient).colors.first.r == semantic.amber.r,
      );
      final RadialGradient gradient = halo.gradient! as RadialGradient;
      expect(gradient.colors.first, semantic.amber.withValues(alpha: 0.32));
      expect(gradient.colors.last.a, 0);
      // A BoxShadow halo paints nothing on this canvas.
      expect(halo.boxShadow, isNull);
    });

    testWidgets('cold-start (<5) hides the score and shows the note', (
      tester,
    ) async {
      await pumpLoaded(tester, coldStart: true, reviewCount: 2);

      expect(find.bySemanticsIdentifier('reviews_new_badge'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('reviews_hidden_score_note'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('reviews_aggregate'), findsNothing);
    });
  });

  group('states — all four on the JeebEmptyState family', () {
    testWidgets('empty mounts the parcel variant on reviews_empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const _StaticRepository(
            ReviewsPage(reviews: <ReviewItem>[], page: 1, totalPages: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final JeebEmptyState state = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      expect(state.identifier, 'reviews_empty');
      expect(state.variant, JeebEmptyStateVariant.parcel);
      expect(state.status, JeebEmptyStateStatus.empty);
    });

    testWidgets('first load mounts the loading twin on reviews_loading', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(_PendingRepository()));
      await tester.pump();

      final JeebEmptyState state = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      expect(state.identifier, 'reviews_loading');
      expect(state.variant, JeebEmptyStateVariant.parcel);
      expect(state.status, JeebEmptyStateStatus.loading);
    });

    testWidgets('error mounts the error twin and keeps the retry node', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const _FailingRepository(ReviewsFailure.network)),
      );
      await tester.pumpAndSettle();

      final JeebEmptyState state = tester.widget<JeebEmptyState>(
        find.byType(JeebEmptyState),
      );
      expect(state.identifier, 'reviews_error');
      expect(state.variant, JeebEmptyStateVariant.parcel);
      expect(state.effectiveStatus, JeebEmptyStateStatus.error);
      expect(state.reason, JeebEmptyStateReason.failed);

      final JeebCtaButton retry = tester.widget<JeebCtaButton>(
        find.byType(JeebCtaButton),
      );
      expect(retry.identifier, 'reviews_retry_cta');
      // The kit's failure block draws Retry as the glass pill.
      expect(retry.variant, JeebCtaVariant.outline);
    });

    testWidgets('the in-list page footer draws no grey OMDS shimmer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const _StaticRepository(
            ReviewsPage(
              reviews: <ReviewItem>[_review],
              page: 1,
              totalPages: 2,
              reviewCount: 12,
              averageScore: 4.6,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('reviews_load_more'), findsOneWidget);
      // `OmdsShimmer` falls back to Colors.grey.shade300 — a light-palette slab
      // on the Midnight field, and a shimmer that never settles.
      expect(find.byType(OmdsListItemShimmer), findsNothing);
      expect(find.byType(OmdsShimmer), findsNothing);
    });

    testWidgets('the header renders in every state', (tester) async {
      await tester.pumpWidget(
        _harness(const _FailingRepository(ReviewsFailure.unknown)),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('reviews_back'), findsOneWidget);
      expect(find.bySemanticsIdentifier('reviews_root'), findsOneWidget);
    });
  });

  // ORPHAN ruling: KEEP + restyle, BOTH ROUTES. The query-param twin is the
  // live one; the path-param twin is pinned by Maestro jm-068.
  group('both routes still resolve after the restyle', () {
    late GoRouter router;
    late List<BlocBase<Object?>> owned;

    Future<void> pumpRouter(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app.onboarding.completed': true,
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final OnboardingCubit onboarding = OnboardingCubit(prefs: prefs);
      final RoleCubit role = RoleCubit(prefs: prefs);
      final RoleEligibilityCubit eligibility = RoleEligibilityCubit();
      final LocaleCubit locale = LocaleCubit(prefs: prefs);
      owned = <BlocBase<Object?>>[onboarding, role, eligibility, locale];
      router = AppRouter.create(
        onboarding: onboarding,
        biometricLock: BiometricLockCubit(
          preference: BiometricPreferenceRepositoryImpl(prefs: prefs),
          gateway: const UnavailableBiometricGateway(),
          pinRepository: SharedPrefsPinRepository(prefs: prefs),
        ),
        session: const AlwaysAuthenticatedSessionGate(),
      );
      addTearDown(() async {
        for (final BlocBase<Object?> b in owned) {
          await b.close();
        }
        router.dispose();
        await GetIt.instance.reset();
      });

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: <BlocProvider<Object?>>[
            BlocProvider<RoleCubit>.value(value: role),
            BlocProvider<RoleEligibilityCubit>.value(value: eligibility),
            BlocProvider<LocaleCubit>.value(value: locale),
          ],
          child: MaterialApp.router(
            // The shared W3/W4 harness mounts NO theme, so any screen doing
            // `extension<JeebSemanticColors>()!` throws there. Midnight here.
            theme: AppTheme.midnight(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            localizationsDelegates: const <LocalizationsDelegate<Object?>>[
              SyncAppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    String location() =>
        router.routerDelegate.currentConfiguration.uri.toString();

    testWidgets('query-param twin — the LIVE inbound from the jeeber profile', (
      tester,
    ) async {
      await pumpRouter(tester);
      router.goNamed(
        'reviews-list',
        queryParameters: <String, String>{'jeeberId': 'jeeber-1'},
      );
      await tester.pumpAndSettle();

      expect(location(), '/profile/delivery-man/reviews?jeeberId=jeeber-1');
      expect(find.byType(ReviewsListScreen), findsOneWidget);
      expect(find.bySemanticsIdentifier('reviews_root'), findsOneWidget);
    });

    testWidgets('path-param twin — the one Maestro jm-068 pins', (
      tester,
    ) async {
      await pumpRouter(tester);
      router.goNamed(
        'reviews-list-by-id',
        pathParameters: <String, String>{'jeeberId': 'user-jeeber-002'},
      );
      await tester.pumpAndSettle();

      expect(location(), '/profile/delivery-man/user-jeeber-002/reviews');
      expect(find.byType(ReviewsListScreen), findsOneWidget);
      expect(find.bySemanticsIdentifier('reviews_root'), findsOneWidget);
    });
  });

  testWidgets('all 11 frozen identifiers survive the restyle', (tester) async {
    await pumpLoaded(tester);

    for (final String id in <String>[
      'reviews_root',
      'reviews_back',
      'reviews_aggregate',
      'review_review-001_reviewer_name',
      'review_review-001_report_cta',
    ]) {
      expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
    }
  });
}
