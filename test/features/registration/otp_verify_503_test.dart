// AE-16 / F29: every non-401/429/410/403 collapsed to `networkError`, so a 503
// `identity_unavailable` told the user to check a connection that was fine.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/data/dio_otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/registration/presentation/otp_verification_screen.dart';

import '../../support/sync_app_localizations.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final ResponseBody Function(RequestOptions options, int hit) _respond;
  int hits = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    hits += 1;
    return _respond(options, hits);
  }

  @override
  void close({bool force = false}) {}
}

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

class _MockOtpService extends Mock implements OtpService {}

ResponseBody _problem(int status, String typeSuffix) =>
    ResponseBody.fromString(
      jsonEncode(<String, Object?>{
        'type': 'https://problems.jeeb.lb/errors/$typeSuffix',
        'status': status,
      }),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

DioOtpService _service(int status, String typeSuffix) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
    ..httpClientAdapter = _ScriptedAdapter((_, _) => _problem(status, typeSuffix));
  return DioOtpService(dio, _MockAuthTokenStore());
}

void main() {
  group('DioOtpService.verifyCode classification', () {
    test('503 identity_unavailable → serviceUnavailable', () async {
      final OtpVerifyOutcome outcome = await _service(503, 'identity_unavailable')
          .verifyCode(e164Phone: '+96170000001', code: '1234');
      expect(outcome, OtpVerifyOutcome.serviceUnavailable);
      expect(outcome, isNot(OtpVerifyOutcome.networkError));
    });

    test('502 and 504 are service-unavailable too', () async {
      for (final int status in <int>[502, 504]) {
        expect(
          await _service(status, 'identity_unavailable')
              .verifyCode(e164Phone: '+96170000001', code: '1234'),
          OtpVerifyOutcome.serviceUnavailable,
          reason: '$status',
        );
      }
    });

    test('500 → serverError, never networkError', () async {
      final OtpVerifyOutcome outcome = await _service(500, 'internal')
          .verifyCode(e164Phone: '+96170000001', code: '1234');
      expect(outcome, OtpVerifyOutcome.serverError);
      expect(outcome, isNot(OtpVerifyOutcome.networkError));
    });
  });

  group('the OTP screen copy per kind', () {
    late _MockOtpService otp;
    late StreamController<DateTime> ticker;

    setUp(() {
      otp = _MockOtpService();
      ticker = StreamController<DateTime>.broadcast();
      when(() => otp.sendCode(any()))
          .thenAnswer((_) async => OtpSendOutcome.sent);
    });

    tearDown(() async => ticker.close());

    Future<RegistrationCubit> onOtpStep(OtpVerifyOutcome outcome) async {
      when(
        () => otp.verifyCode(
          e164Phone: any(named: 'e164Phone'),
          code: any(named: 'code'),
        ),
      ).thenAnswer((_) async => outcome);
      final RegistrationCubit cubit = RegistrationCubit(
        otpService: otp,
        tickerFactory: () => ticker.stream,
      )..phoneChanged('71123456');
      await cubit.sendCode();
      await cubit.verifyCode('1234');
      return cubit;
    }

    Future<AppLocalizations> pumpOtp(
      WidgetTester tester,
      OtpVerifyOutcome outcome,
      Locale locale,
    ) async {
      final RegistrationCubit cubit = await onOtpStep(outcome);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        wrapForTest(
          BlocProvider<RegistrationCubit>.value(
            value: cubit,
            child: const OtpVerificationScreen(),
          ),
          locale: locale,
        ),
      );
      await tester.pump();
      return AppLocalizations.of(
        tester.element(find.byType(OtpVerificationScreen)),
      );
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      final String tag = locale.languageCode;

      testWidgets('serviceUnavailable prints its own line ($tag)',
          (tester) async {
        final AppLocalizations l10n = await pumpOtp(
          tester,
          OtpVerifyOutcome.serviceUnavailable,
          locale,
        );
        expect(find.text(l10n.registrationOtpServiceUnavailable), findsOneWidget);
        expect(find.text(l10n.registrationOtpNetworkError), findsNothing);
      });

      testWidgets('serverError prints its own line ($tag)', (tester) async {
        final AppLocalizations l10n = await pumpOtp(
          tester,
          OtpVerifyOutcome.serverError,
          locale,
        );
        expect(find.text(l10n.registrationOtpServerError), findsOneWidget);
        expect(find.text(l10n.registrationOtpNetworkError), findsNothing);
      });
    }
  });
}
