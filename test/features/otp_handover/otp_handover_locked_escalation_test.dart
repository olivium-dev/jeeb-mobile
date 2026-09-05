// AE-03 — a 423 carries the case the gateway ALREADY opened; the dialog must
// point at it rather than offer to open a second one.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/features/otp_handover/application/otp_handover_cubit.dart';
import 'package:jeeb_mobile/features/otp_handover/data/dio_otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_repository.dart';
import 'package:jeeb_mobile/features/otp_handover/domain/otp_handover_result.dart';
import 'package:jeeb_mobile/features/otp_handover/presentation/otp_handover_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';
import '_scripted_dio.dart';

class _LockedRepository implements OtpHandoverRepository {
  const _LockedRepository();

  @override
  Future<OtpFetchResult> fetchHandoverCode({required String deliveryId}) async =>
      const OtpFetchResult(smsTriggered: true);

  @override
  Future<OtpHandoverResult> submitOtp({
    required String deliveryId,
    required String otp,
  }) async => throw OtpHandoverLocked(
        escalationId: 'ESC-9001',
        lockedAt: DateTime.utc(2026, 9, 5, 10),
      );
}

void main() {
  test('423 with an escalationId throws OtpHandoverLocked carrying it',
      () async {
    final repo = DioOtpHandoverRepository(
      scriptedDio(
        (_, r) => r.failWithStatus(423, body: <String, Object?>{
          'type': 'https://jeeb.app/errors/handover-locked',
          'title': 'server prose',
          'escalationId': 'ESC-9001',
          'lockedAt': '2026-09-05T10:00:00Z',
          'attemptsRemaining': 0,
        }),
      ),
    );

    try {
      await repo.submitOtp(deliveryId: 'DLV-1', otp: '1234');
      fail('expected OtpHandoverLocked');
    } on OtpHandoverLocked catch (e) {
      expect(e.kind, OtpHandoverErrorKind.locked);
      expect(e.escalationId, 'ESC-9001');
      expect(e.lockedAt, DateTime.utc(2026, 9, 5, 10));
      expect(e.attemptsRemaining, 0);
    }
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
  testWidgets('[${locale.languageCode}] the state carries the case and the '
      'dialog routes to /disputes', (tester) async {
    final cubit = OtpHandoverCubit(
      repository: const _LockedRepository(),
      deliveryId: 'DLV-770001',
      isClient: false,
    );
    addTearDown(cubit.close);

    final router = GoRouter(
      initialLocation: '/handover',
      routes: <RouteBase>[
        GoRoute(
          path: '/handover',
          builder: (_, _) => BlocProvider<OtpHandoverCubit>.value(
            value: cubit,
            child: const OtpHandoverScreen(
              deliveryId: 'DLV-770001',
              isClient: false,
            ),
          ),
        ),
        GoRoute(
          path: '/disputes/:id',
          builder: (_, state) =>
              Scaffold(body: Text('dispute-${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/orders/:id/escalate',
          builder: (_, _) => const Scaffold(body: Text('new-dispute-form')),
        ),
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

    await cubit.submitOtp('9999');
    await tester.pumpAndSettle();

    expect(cubit.state.escalationId, 'ESC-9001');
    // The screen itself stays findable by id while the dialog is up.
    expect(find.bySemanticsIdentifier('otp_handover_root'), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold).first));
    expect(find.text(l10n.otpHandoverLockedTitle), findsOneWidget);

    await tester.tap(find.text(l10n.otpHandoverLockedContactSupport));
    await tester.pumpAndSettle();

    // The existing case, never a second dispute form.
    expect(find.text('dispute-ESC-9001'), findsOneWidget);
    expect(find.text('new-dispute-form'), findsNothing);
  });
  }
}
