// Regression locks for the live decision-violation fixes carried on
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc_rejected/presentation/kyc_rejected_screen.dart';
import 'package:jeeb_mobile/features/rating/application/mutual_rating_cubit.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/features/rating/presentation/mutual_rating_screen.dart';
import 'package:jeeb_mobile/core/jeeb_commission.dart';
import 'package:jeeb_mobile/features/offers/presentation/offer_composer_l10n.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

class _NoopRatingRepo implements RatingRepository {
  const _NoopRatingRepo();

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {}

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) {
    throw UnimplementedError();
  }
}

/// Router shell carrying the named routes the kyc-rejected CTAs target, so the
/// screen's `goNamed` edges resolve without throwing.
Widget _routerHarness(Widget screen) {
  final router = GoRouter(
    initialLocation: '/kyc/rejected',
    routes: [
      GoRoute(
        path: '/kyc/rejected',
        builder: (_, _) => screen,
      ),
      GoRoute(
        name: 'support-ticket',
        path: '/support',
        builder: (_, _) => const Scaffold(body: Text('SUPPORT')),
      ),
      GoRoute(
        name: 'customer-profile',
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('PROFILE')),
      ),
    ],
  );
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

void main() {
  group('D56 — mandatory rating has no escape affordance', () {
    testWidgets('MutualRatingScreen suppresses back and offers no close/skip',
        (tester) async {
      final cubit = MutualRatingCubit(
        repository: const _NoopRatingRepo(),
        deliveryId: 'DLV-1',
        isClient: true,
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        wrapForTest(
          BlocProvider<MutualRatingCubit>.value(
            value: cubit,
            child: const MutualRatingScreen(),
          ),
        ),
      );
      await tester.pump();

      // The mandatory terminal renders (signature id present).
      expect(find.bySemanticsIdentifier('rating_root'), findsOneWidget);

      // D56: the system back gesture is suppressed via PopScope(canPop:false).
      final popScope = tester.widget<PopScope>(find.byType(PopScope));
      expect(popScope.canPop, isFalse);

      // D56: no leading back/close and no skip control of any kind.
      expect(find.byType(BackButton), findsNothing);
      expect(find.byType(CloseButton), findsNothing);
      expect(find.bySemanticsIdentifier('rating_close_cta'), findsNothing);
      expect(find.text('Skip'), findsNothing);
    });
  });

  group('D52 — final KYC rejection has no resubmit CTA', () {
    testWidgets('KycRejectedScreen shows appeal + back, never a resubmit CTA',
        (tester) async {
      await tester.pumpWidget(
        _routerHarness(KycRejectedScreen(gateway: FakeKycGateway())),
      );
      await tester.pump();

      expect(find.bySemanticsIdentifier('kyc_rejected_root'), findsOneWidget);

      // The only forward paths are appeal-via-support and back-to-profile.
      expect(
        find.bySemanticsIdentifier('kyc_rejected_appeal_cta'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('kyc_rejected_back_cta'),
        findsOneWidget,
      );

      // D52: a FINAL rejection must NEVER offer resubmit.
      expect(
        find.bySemanticsIdentifier('kyc_rejected_resubmit_cta'),
        findsNothing,
      );
      expect(find.textContaining('Resubmit'), findsNothing);
      expect(find.textContaining('resubmit'), findsNothing);
    });
  });

  group('D20 — vehicle is not part of the contract', () {
    test('the en/ar ARB carry no "Vehicle number" contract strings', () {
      final en = File('lib/l10n/app_en.arb').readAsStringSync();
      final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
      // The stale per-screen contract keys were removed to align with the
      for (final key in const [
        'dmOnboardingAddressVehicleNumberLabel',
        'dmOnboardingAddressVehicleNumberHint',
        'kycWizardStepVehicleLabel',
        'kycVehicleStepTitle',
        'kycVehicleRegistrationLabel',
        'kycStatusResubmitCta',
        'dmOnboardingServiceAreaDistanceLabel',
      ]) {
        expect(en.contains('"$key"'), isFalse, reason: '$key must be gone (en)');
        expect(ar.contains('"$key"'), isFalse, reason: '$key must be gone (ar)');
      }
    });
  });

  group('Earnings framing — fee-only, not gross/commission', () {
    // RE-HOMED from the deleted SettlementDetailScreen (M3-15/16 orphan
    // deletion) onto the offer composer — the one shipped screen still drawing
    // a platform-fee line, which is the "already-shipped screen" leg the kit's
    // JeebMoneyBreakdown asserts cannot cover on their own.
    AppLocalizations arb(String tag) => debugLoadAppLocalizationsSync(
          Locale(tag),
          File('lib/l10n/app_$tag.arb').readAsStringSync(),
        );

    test('the composer fee line reads "Platform fee", never "Commission"', () {
      final en = OfferComposerL10n(arb('en'), false);
      final ar = OfferComposerL10n(arb('ar'), true);

      for (final label in [en.feeRowLabel, en.feeLinePending]) {
        expect(label, contains('Platform fee'));
        expect(label.toLowerCase(), isNot(contains('commission')));
      }
      // AR: "رسوم المنصة" (platform fee), never "عمولة" (commission).
      for (final label in [ar.feeRowLabel, ar.feeLinePending]) {
        expect(label, contains('رسوم المنصة'));
        expect(label, isNot(contains('عمولة')));
      }
    });

    test('the fee percentage derives from kJeebCommissionPercent', () {
      expect(
        OfferComposerL10n(arb('en'), false).feeRowLabel,
        contains('$kJeebCommissionPercent%'),
      );
    });
  });
}
