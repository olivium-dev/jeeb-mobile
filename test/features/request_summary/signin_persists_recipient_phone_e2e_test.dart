import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/registration/data/dio_otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';
import 'package:jeeb_mobile/features/request_summary/data/chained_recipient_phone_resolver.dart';
import 'package:jeeb_mobile/features/request_summary/data/dio_recipient_phone_resolver.dart';
import 'package:jeeb_mobile/features/request_summary/data/dio_request_submission_service.dart';
import 'package:jeeb_mobile/features/request_summary/data/shared_prefs_recipient_phone_resolver.dart';
import 'package:jeeb_mobile/features/request_summary/domain/recipient_phone_resolver.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/settings/data/shared_prefs_profile_repository.dart';

/// BUG-7 regression (physical-run6): prove the FULL runtime path — NOT a mock
/// that hides the gap.
///
/// physical-run6 showed unit tests passing while the wire still omitted
/// `recipientPhone`, because the tests stubbed the resolver. Here we exercise
/// the REAL chain end-to-end:
///   1. A phone-OTP sign-in ([DioOtpService.verifyCode]) with the live-gateway
///      response shape (its `user` object carries NO phone).
///   2. The DEFAULT resolver DI actually wires
///      (SharedPrefs → live `GET /v1/users/me`), with the "profile phone
///      unavailable" condition simulated exactly as prod: an EMPTY
///      SharedPreferences AND a `/v1/users/me` body with NO `phone` field
///      (verified live against `:10090` — it exposes only
///      {userId, active_role, available_roles, name, email, avatarUrl}).
///   3. The real [DioRequestSubmissionService] building the create body.
///
/// The pre-fix behaviour (sign-in persisting only the JWT) made this chain
/// return null and drop `recipientPhone`. The fix persists the sign-in phone to
/// `settings.profile.v1`, so the chain now returns the signed-in E.164 number
/// and the create body carries it — even though the server profile has no phone.
class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

/// A [Dio] that resolves POST `/v1/auth/otp/verify` with the LIVE-gateway
/// response shape (no `phone` on `user`) so the sign-in path is exercised for
/// real without a network.
Dio _otpVerifyDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'accessToken': 'access-abc',
            'refreshToken': 'refresh-xyz',
            // Live gateway `/v1/auth/otp/verify` user object — NO phone.
            'user': <String, dynamic>{
              'userId': 'user-123',
              'active_role': 'client',
              'available_roles': <String>['client'],
            },
          },
        ),
      ),
    ),
  );
  return dio;
}

/// A [Dio] whose GET `/v1/users/me` returns the EXACT live-gateway body (verified
/// against `:10090`): it exposes NO `phone` field, so the
/// [DioRecipientPhoneResolver] leg genuinely misses (profile phone unavailable).
Dio _usersMeNoPhoneDio() {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<dynamic>(
          requestOptions: options,
          statusCode: 200,
          data: <String, dynamic>{
            'userId': 'user-123',
            'active_role': 'client',
            'available_roles': <String>['client'],
            'name': 'jeeb-f9899d16f934',
            'email': 'phone-only+045f7411@jeeb.internal',
            'avatarUrl': null,
          },
        ),
      ),
    ),
  );
  return dio;
}

/// A [Dio] that captures the create POST body into [sink] and returns 201 {id}.
Dio _captureCreateDio(void Function(Map<String, dynamic>?) sink) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        sink(options.data as Map<String, dynamic>?);
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 201,
            data: <String, dynamic>{'id': 'req-e2e', 'status': 'pending'},
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  const signInPhone = '+96170123456';

  late _MockAuthTokenStore tokenStore;

  setUp(() {
    // Start with EMPTY prefs → the profile phone is genuinely unavailable, as
    // it was for the seeded run-6 customer (the key is written by no one until
    // sign-in now writes it).
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tokenStore = _MockAuthTokenStore();
    when(() => tokenStore.save(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async {});
  });

  test(
      'sign-in persists E.164 phone → resolver returns it → create body carries '
      'recipientPhone, even when the server profile has NO phone', () async {
    final prefs = await SharedPreferences.getInstance();
    final profileRepo = SharedPrefsProfileRepository(prefs: prefs);

    // Precondition: profile phone is unavailable before sign-in (the run-6 gap).
    final preSignIn = SharedPrefsRecipientPhoneResolver(
      profileRepository: profileRepo,
    );
    expect(
      await preSignIn.resolve(),
      isNull,
      reason: 'no profile phone is persisted before sign-in',
    );

    // 1) Real phone-OTP sign-in with the live-gateway (no-phone) response.
    final otp = DioOtpService(
      _otpVerifyDio(),
      tokenStore,
      profileRepository: profileRepo,
    );
    final outcome = await otp.verifyCode(e164Phone: signInPhone, code: '1234');
    expect(outcome, OtpVerifyOutcome.verified);

    // 2) The DEFAULT resolver DI wires: SharedPrefs (now populated by sign-in)
    //    → live GET /v1/users/me (NO phone). Simulate "profile phone
    //    unavailable" on the Dio leg via the no-phone users/me body.
    final RecipientPhoneResolver resolver =
        ChainedRecipientPhoneResolver(<RecipientPhoneResolver>[
      SharedPrefsRecipientPhoneResolver(profileRepository: profileRepo),
      DioRecipientPhoneResolver(_usersMeNoPhoneDio()),
    ]);

    // The Dio (users/me) leg alone STILL misses — proving the guarantee comes
    // from the persisted sign-in phone, not from the server profile.
    expect(
      await DioRecipientPhoneResolver(_usersMeNoPhoneDio()).resolve(),
      isNull,
      reason: 'live GET /v1/users/me exposes no phone',
    );

    // The chain now returns the signed-in E.164 phone (from SharedPrefs).
    expect(await resolver.resolve(), signInPhone);

    // 3) Real submission service → create body carries the E.164 recipientPhone.
    Map<String, dynamic>? body;
    final service = DioRequestSubmissionService(
      _captureCreateDio((b) => body = b),
      resolver,
    );

    // Draft with NO compose-form phone → the resolver default must fill it.
    final id = await service.submit(
      const RequestDraft(description: 'Parcel to Verdun'),
    );
    expect(id, 'req-e2e');

    final phone = body?['recipientPhone'] as String?;
    expect(phone, isNotNull, reason: 'BUG-7: create body must carry the field');
    expect(phone, signInPhone);
    expect(phone, isNotEmpty);
    expect(phone, startsWith('+'), reason: 'E.164');
  });

  test('sign-in phone MERGES over an existing profile (name/photo survive)',
      () async {
    // A user who had edited their profile before (name set, no phone) signs in;
    // the phone must be added without clobbering the name.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'settings.profile.v1':
          '{"phoneE164":"","name":"Layla","photoUrl":"https://cdn/a.jpg"}',
    });
    final prefs = await SharedPreferences.getInstance();
    final profileRepo = SharedPrefsProfileRepository(prefs: prefs);

    final otp = DioOtpService(
      _otpVerifyDio(),
      tokenStore,
      profileRepository: profileRepo,
    );
    await otp.verifyCode(e164Phone: signInPhone, code: '1234');

    final saved = await profileRepo.load();
    expect(saved?.phoneE164, signInPhone);
    expect(saved?.name, 'Layla', reason: 'existing name preserved on merge');
    expect(saved?.photoUrl, 'https://cdn/a.jpg');
  });

  test('an explicit compose-form phone still WINS over the persisted default',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final profileRepo = SharedPrefsProfileRepository(prefs: prefs);
    final otp = DioOtpService(
      _otpVerifyDio(),
      tokenStore,
      profileRepository: profileRepo,
    );
    await otp.verifyCode(e164Phone: signInPhone, code: '1234');

    final RecipientPhoneResolver resolver =
        ChainedRecipientPhoneResolver(<RecipientPhoneResolver>[
      SharedPrefsRecipientPhoneResolver(profileRepository: profileRepo),
      DioRecipientPhoneResolver(_usersMeNoPhoneDio()),
    ]);

    Map<String, dynamic>? body;
    final service = DioRequestSubmissionService(
      _captureCreateDio((b) => body = b),
      resolver,
    );

    await service.submit(
      const RequestDraft(
        description: 'Parcel with an explicit recipient',
        recipientPhone: '+96171999999',
      ),
    );

    expect(body?['recipientPhone'], '+96171999999');
  });
}
