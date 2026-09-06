// The two OTP-handover surfaces the lane added and nothing asserted: the
// inline resend failure and the cold-load exit CTA.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_cubit.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_result.dart';
import 'package:jeeb_mobile/features/otp_handover/presentation/otp_handover_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

/// The code lands once; every resend is refused.
class _ResendRefusingRepository implements OtpHandoverRepository {
  int reads = 0;

  @override
  Future<OtpFetchResult> fetchHandoverCode({required String deliveryId}) async {
    reads++;
    if (reads == 1) return const OtpFetchResult(code: '2144');
    throw const OtpHandoverException(OtpHandoverErrorKind.network);
  }

  @override
  Future<OtpHandoverResult> submitOtp({
    required String deliveryId,
    required String otp,
  }) async => const OtpHandoverResult(success: true);
}

/// The cold read never lands — the error rung, with a 404 that cannot retry.
class _NotFoundRepository implements OtpHandoverRepository {
  const _NotFoundRepository();

  @override
  Future<OtpFetchResult> fetchHandoverCode({required String deliveryId}) async =>
      throw const OtpHandoverException(OtpHandoverErrorKind.notFound);

  @override
  Future<OtpHandoverResult> submitOtp({
    required String deliveryId,
    required String otp,
  }) async => const OtpHandoverResult(success: true);
}

Widget _harness(OtpHandoverCubit cubit, Locale locale) {
  final GoRouter router = GoRouter(
    initialLocation: '/handover',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/handover',
        builder: (_, _) => BlocProvider<OtpHandoverCubit>.value(
          value: cubit,
          child: const OtpHandoverScreen(
            deliveryId: 'DLV-770001',
            isClient: true,
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  return MaterialApp.router(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: router,
  );
}

void main() {
  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String tag = locale.languageCode;

    testWidgets('[$tag] a refused resend renders otp_handover_resend_error',
        (WidgetTester tester) async {
      useReduceMotion(tester);
      final OtpHandoverCubit cubit = OtpHandoverCubit(
        repository: _ResendRefusingRepository(),
        deliveryId: 'DLV-770001',
        isClient: true,
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(_harness(cubit, locale));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('otp_handover_resend_error'),
        findsNothing,
      );

      await cubit.resendSms();
      await tester.pumpAndSettle();

      expect(cubit.state.resendFailed, isTrue);
      expect(
        find.bySemanticsIdentifier('otp_handover_resend_error'),
        findsOneWidget,
      );
    });

    testWidgets('[$tag] a 404 cold read offers otp_handover_exit_cta, not a '
        'Retry that cannot win', (WidgetTester tester) async {
      useReduceMotion(tester);
      final OtpHandoverCubit cubit = OtpHandoverCubit(
        repository: const _NotFoundRepository(),
        deliveryId: 'DLV-770001',
        isClient: true,
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(_harness(cubit, locale));
      await tester.pumpAndSettle();

      expect(find.bySemanticsIdentifier('otp_handover_error'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('otp_handover_retry_cta'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('otp_handover_exit_cta'),
        findsOneWidget,
      );

      // The exit is not inert on a deep-link root: it lands home.
      await tester.tap(find.bySemanticsIdentifier('otp_handover_exit_cta'));
      await tester.pumpAndSettle();
      expect(find.text('home'), findsOneWidget);
    });
  }
}
