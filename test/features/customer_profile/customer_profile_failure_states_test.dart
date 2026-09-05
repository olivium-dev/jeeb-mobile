// UX-42 / UX-33 / RATE-01: `failed` is no longer dead, a warm failure keeps
// the identity card, a review-join outage does not read as "no reviews yet",
// and an unavailable store-review API is not a silent no-op.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/customer_profile_screen.dart';
import 'package:jeeb_mobile/features/customer_profile/presentation/widgets/customer_profile_status_block.dart';
import 'package:jeeb_mobile/features/rate_app/domain/app_review_launcher.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const CustomerProfileViewData _seeded = CustomerProfileViewData(
  name: 'Sami Fawaz',
  email: 'sami@example.com',
  rating: 4.9,
  ratingCount: 12,
);

class _FailingRepository implements CustomerProfileRepository {
  const _FailingRepository(this.kind, this.failure);

  final CustomerProfileFailure kind;
  final AppFailure failure;

  @override
  Future<CustomerProfileViewData> fetchProfile() async =>
      throw CustomerProfileRepositoryException.classified(
        kind,
        appFailure: failure,
      );
}

class _UnavailableReviewLauncher
    implements AppReviewLauncher, AppReviewOutcomeLauncher {
  const _UnavailableReviewLauncher();

  @override
  Future<void> requestReview() async {}

  @override
  Future<AppReviewOutcome> requestReviewOutcome() async =>
      AppReviewOutcome.unavailable;
}

class _WorkingReviewLauncher
    implements AppReviewLauncher, AppReviewOutcomeLauncher {
  const _WorkingReviewLauncher();

  @override
  Future<void> requestReview() async {}

  @override
  Future<AppReviewOutcome> requestReviewOutcome() async =>
      AppReviewOutcome.requested;
}

void main() {
  Widget harness({
    CustomerProfileViewData data = _seeded,
    CustomerProfileRepository? repository,
    AppReviewLauncher? reviewLauncher,
    Locale locale = const Locale('en'),
  }) {
    final router = GoRouter(
      initialLocation: '/profile',
      routes: <RouteBase>[
        GoRoute(
          path: '/profile',
          builder: (_, _) => CustomerProfileScreen(
            data: data,
            repository: repository,
            reviewLauncher: reviewLauncher,
          ),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (_, _) => const Scaffold(body: Text('login')),
        ),
      ],
    );
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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    );
  }

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  testWidgets('a cold blank read failure draws the error block', (
    tester,
  ) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      harness(
        data: const CustomerProfileViewData(),
        repository: const _FailingRepository(
          CustomerProfileFailure.network,
          NetworkFailure(offline: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(byId(CustomerProfileStatusBlock.errorIdentifier), findsOneWidget);
    expect(byId(CustomerProfileStatusBlock.retryIdentifier), findsOneWidget);
  });

  testWidgets('a warm failure keeps the identity card and rides the strip', (
    tester,
  ) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      harness(
        repository: const _FailingRepository(
          CustomerProfileFailure.network,
          NetworkFailure(offline: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // UX-42: the seeded profile is still on screen.
    expect(
      find.descendant(
        of: byId('customer_profile_name'),
        matching: find.text('Sami Fawaz'),
      ),
      findsOneWidget,
    );
    expect(
      byId(CustomerProfileStatusBlock.refreshErrorIdentifier),
      findsOneWidget,
    );
    expect(byId(CustomerProfileStatusBlock.errorIdentifier), findsNothing);
  });

  testWidgets('unauthorized gets the sign-in way out, never a Retry', (
    tester,
  ) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      harness(
        data: const CustomerProfileViewData(),
        repository: const _FailingRepository(
          CustomerProfileFailure.unauthorized,
          UnauthorizedFailure(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(byId(CustomerProfileStatusBlock.errorIdentifier), findsOneWidget);
    expect(byId('customer_profile_error_signin_cta'), findsOneWidget);
    expect(byId(CustomerProfileStatusBlock.retryIdentifier), findsNothing);
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] a review-join outage never reads as "no reviews yet"', (
      tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        harness(
          data: const CustomerProfileViewData(
            name: 'Sami Fawaz',
            ratingUnavailable: true,
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(byId('customer_profile_rating')),
      );
      final rating = byId('customer_profile_rating');
      expect(
        find.descendant(
          of: rating,
          matching: find.text(l10n.customerProfileRatingUnavailable),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: rating,
          matching: find.text(l10n.deliveryManProfileEmptyReviewsTitle),
        ),
        findsNothing,
      );
    });
  }

  testWidgets('an unavailable store review API snacks instead of no-op', (
    tester,
  ) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      harness(reviewLauncher: const _UnavailableReviewLauncher()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(byId('customer_profile_rate_app_row'));
    await tester.tap(byId('customer_profile_rate_app_row'));
    await tester.pumpAndSettle();

    expect(byId('customer_profile_rate_app_unavailable'), findsOneWidget);
  });

  testWidgets('a working store review API stays silent', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      harness(reviewLauncher: const _WorkingReviewLauncher()),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(byId('customer_profile_rate_app_row'));
    await tester.tap(byId('customer_profile_rate_app_row'));
    await tester.pumpAndSettle();

    expect(byId('customer_profile_rate_app_unavailable'), findsNothing);
  });
}
