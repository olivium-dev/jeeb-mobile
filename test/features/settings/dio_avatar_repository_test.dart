import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/kyc/domain/cdn_asset_gateway.dart';
import 'package:jeeb_mobile/features/settings/data/dio_avatar_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/avatar_repository.dart';

class _MockDio extends Mock implements Dio {}

class _MockCdnAssetGateway extends Mock implements CdnAssetGateway {}

void main() {
  late _MockDio dio;
  late _MockCdnAssetGateway cdn;
  late DioAvatarRepository repo;

  const userId = 'u-1234';
  const email = 'sami@example.com';
  const name = 'Sami';
  const baseUrl = 'https://gw.test';

  setUpAll(() {
    registerFallbackValue(CdnUploadSlot.avatar);
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    dio = _MockDio();
    cdn = _MockCdnAssetGateway();
    when(() => dio.options).thenReturn(BaseOptions(baseUrl: baseUrl));
    repo = DioAvatarRepository(dio, cdn);
  });

  Response<Map<String, dynamic>> meResponse({String? avatarUrl}) =>
      Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/v1/users/me'),
        statusCode: 200,
        data: <String, dynamic>{
          'userId': userId,
          'email': email,
          'name': name,
          'avatarUrl': ?avatarUrl,
        },
      );

  void stubMe({String? avatarUrl}) {
    when(() => dio.get<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => meResponse(avatarUrl: avatarUrl));
  }

  void stubPutOk() {
    when(() => dio.put<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        )).thenAnswer((_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/api/User/profile'),
          statusCode: 200,
          data: const <String, dynamic>{},
        ));
  }

  group('DioAvatarRepository.uploadAvatar', () {
    test('uploads via the CDN gateway on the avatar slot, then commits the '
        'BARE object_ref — never the display URL — while still returning the '
        'display URL and preserving the current username', () async {
      stubMe();
      stubPutOk();
      when(() => cdn.uploadAsset(
            slot: any(named: 'slot'),
            bytes: any(named: 'bytes'),
          )).thenAnswer((_) async => 'profile_avatar/abc123.jpg');

      final bytes = Uint8List.fromList(List<int>.filled(10, 1));
      final url = await repo.uploadAvatar(bytes);

      final slotCall = verify(() => cdn.uploadAsset(
            slot: captureAny(named: 'slot'),
            bytes: captureAny(named: 'bytes'),
          )).captured;
      expect(slotCall[0], CdnUploadSlot.avatar);
      expect(slotCall[1], bytes);

      // The UI still gets a display URL for the optimistic preview.
      expect(url, startsWith('$baseUrl/api/users/$userId/avatar?v='));

      final put = verify(() => dio.put<Map<String, dynamic>>(
            captureAny(),
            data: captureAny(named: 'data'),
          )).captured;
      expect(put[0], '/api/User/profile');
      final body = put[1] as Map<String, dynamic>;
      expect(body['userId'], userId);
      expect(body['email'], email);
      expect(body['username'], name); // preserved, never blanked
      // F5 contract: the wire carries the bare CDN ref, NOT a self-referential URL.
      expect(body['profilePic'], 'profile_avatar/abc123.jpg');
      expect(body['profilePic'], isNot(contains('/api/users/')));
    });

    test('rejects an oversize payload client-side without ever calling the '
        'CDN gateway', () async {
      final oversize = Uint8List(DioAvatarRepository.maxUploadBytes + 1);
      await expectLater(
        repo.uploadAvatar(oversize),
        throwsA(isA<AvatarRepositoryException>().having(
          (e) => e.failure,
          'failure',
          AvatarUploadFailure.tooLarge,
        )),
      );
      verifyNever(() => cdn.uploadAsset(
            slot: any(named: 'slot'),
            bytes: any(named: 'bytes'),
          ));
    });

    test('maps a CDN upload failure to AvatarUploadFailure.network',
        () async {
      when(() => cdn.uploadAsset(
            slot: any(named: 'slot'),
            bytes: any(named: 'bytes'),
          )).thenThrow(const CdnUploadException('broker down'));

      await expectLater(
        repo.uploadAvatar(Uint8List(4)),
        throwsA(isA<AvatarRepositoryException>().having(
          (e) => e.failure,
          'failure',
          AvatarUploadFailure.network,
        )),
      );
    });

    test('maps a 401 on the profile PUT to AvatarUploadFailure.unauthorized',
        () async {
      stubMe();
      when(() => cdn.uploadAsset(
            slot: any(named: 'slot'),
            bytes: any(named: 'bytes'),
          )).thenAnswer((_) async => 'kyc/objects/abc123');
      when(() => dio.put<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/api/User/profile'),
        response: Response<void>(
          requestOptions: RequestOptions(path: '/api/User/profile'),
          statusCode: 401,
        ),
      ));

      await expectLater(
        repo.uploadAvatar(Uint8List(4)),
        throwsA(isA<AvatarRepositoryException>().having(
          (e) => e.failure,
          'failure',
          AvatarUploadFailure.unauthorized,
        )),
      );
    });

    test('maps a 502 from the profile PUT to AvatarUploadFailure.serverError',
        () async {
      stubMe();
      when(() => cdn.uploadAsset(
            slot: any(named: 'slot'),
            bytes: any(named: 'bytes'),
          )).thenAnswer((_) async => 'kyc/objects/abc123');
      when(() => dio.put<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/api/User/profile'),
        response: Response<void>(
          requestOptions: RequestOptions(path: '/api/User/profile'),
          statusCode: 502,
        ),
      ));

      await expectLater(
        repo.uploadAvatar(Uint8List(4)),
        throwsA(isA<AvatarRepositoryException>().having(
          (e) => e.failure,
          'failure',
          AvatarUploadFailure.serverError,
        )),
      );
    });
  });

  group('DioAvatarRepository.removeAvatar', () {
    test('sends an explicit blank profilePic — the one deliberate clear '
        'shape — while preserving userId/email/username', () async {
      stubMe(avatarUrl: 'https://gw.test/api/users/$userId/avatar?v=1');
      stubPutOk();

      await repo.removeAvatar();

      final put = verify(() => dio.put<Map<String, dynamic>>(
            any(),
            data: captureAny(named: 'data'),
          )).captured;
      final body = put.single as Map<String, dynamic>;
      expect(body['profilePic'], '');
      expect(body['username'], name);
      expect(body['userId'], userId);
    });
  });
}
