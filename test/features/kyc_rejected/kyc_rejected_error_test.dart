// KYCR-01: a failed status read emitted `error`, which `shouldLeaveRejectedRoute`
// turned into a silent redirect off the appeal screen — the one surface the
// user needs when they have been rejected.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc_rejected/application/kyc_rejected_cubit.dart';
import 'package:jeeb_mobile/features/kyc_rejected/application/kyc_rejected_state.dart';
import 'package:jeeb_mobile/features/kyc_rejected/presentation/kyc_rejected_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _ThrowingGateway extends FakeKycGateway {
  _ThrowingGateway();

  int reads = 0;

  @override
  Future<KycSubmission> fetchStatus() async {
    reads++;
    throw const KycGatewayException(ServerFailure(status: 503));
  }
}

Widget _harness(KycGateway gateway, {Locale locale = const Locale('en')}) {
  final GoRouter router = GoRouter(
    initialLocation: '/kyc/rejected',
    routes: <RouteBase>[
      GoRoute(
        path: '/kyc/rejected',
        builder: (_, _) => KycRejectedScreen(gateway: gateway),
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
      GoRoute(
        name: 'kyc-status',
        path: '/profile/kyc',
        builder: (_, _) => const Scaffold(body: Text('KYC_STATUS')),
      ),
    ],
  );
  addTearDown(router.dispose);
  return MaterialApp.router(
    theme: AppTheme.midnight(),
    routerConfig: router,
    locale: locale,
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
  );
}

void main() {
  test('a failed read does NOT ask the route to leave', () async {
    final cubit = KycRejectedCubit(_ThrowingGateway());
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.status, KycRejectedStatus.error);
    expect(cubit.state.failure, isA<ServerFailure>());
    expect(cubit.state.shouldLeaveRejectedRoute, isFalse);
  });

  test('an authoritative non-rejected decision DOES redirect', () async {
    final cubit = KycRejectedCubit(
      FakeKycGateway(initial: const KycSubmission(status: KycStatus.approved)),
    );
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.shouldLeaveRejectedRoute, isTrue);
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('${locale.languageCode} · the error rung owns the screen and '
        'retries in place', (tester) async {
      useReduceMotion(tester);
      final gateway = _ThrowingGateway();

      await tester.pumpWidget(_harness(gateway, locale: locale));
      await tester.pumpAndSettle();

      expect(find.text('KYC_STATUS'), findsNothing);
      expect(find.bySemanticsIdentifier('kyc_rejected_error'), findsOneWidget);

      await tester.tap(
        find.bySemanticsIdentifier('kyc_rejected_retry_cta'),
      );
      await tester.pumpAndSettle();

      expect(gateway.reads, 2);
      expect(find.bySemanticsIdentifier('kyc_rejected_error'), findsOneWidget);
    });
  }

  testWidgets('the loading rung is the empty family, not OmdsLoadingState',
      (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      _harness(
        FakeKycGateway(initial: const KycSubmission(status: KycStatus.pending)),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsIdentifier('kyc_rejected_loading'), findsOneWidget);
  });
}
