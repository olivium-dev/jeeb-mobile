// UX-23 twin / NET-09: `_fetchMe` coalesced userId/email to '' and the PUT
// then blanked the stored email; `_mapDioFailure` was a bespoke predicate.
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/kyc/domain/cdn_asset_gateway.dart';
import 'package:jeeb_mobile/features/settings/data/dio_avatar_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/avatar_repository.dart';

/// A plain (NON-idempotent) CDN gateway — proves the `is` fallback path.
class _PlainCdn implements CdnAssetGateway {
  const _PlainCdn();

  @override
  Future<String> uploadAsset({
    required CdnUploadSlot slot,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async =>
      'kyc/objects/abc123';

  @override
  Future<Uint8List> fetchAsset(String objectRef) async => Uint8List(0);
}

({Dio dio, List<Map<String, dynamic>> puts}) _dio({
  required Map<String, dynamic> me,
  int putStatus = 204,
}) {
  final puts = <Map<String, dynamic>>[];
  final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/v1/users/me') {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: me,
            ),
          );
          return;
        }
        puts.add(options.data! as Map<String, dynamic>);
        if (putStatus >= 200 && putStatus < 300) {
          handler.resolve(
            Response<dynamic>(requestOptions: options, statusCode: putStatus),
          );
          return;
        }
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: putStatus,
            ),
          ),
        );
      },
    ),
  );
  return (dio: dio, puts: puts);
}

void main() {
  test('a /v1/users/me with no email OMITS the field instead of blanking it',
      () async {
    final scripted = _dio(me: <String, dynamic>{'userId': 'u-1', 'name': 'Sami'});
    final repo = DioAvatarRepository(scripted.dio, const _PlainCdn());

    await repo.uploadAvatar(Uint8List(4));

    expect(scripted.puts, hasLength(1));
    expect(scripted.puts.single.containsKey('email'), isFalse);
    expect(scripted.puts.single['username'], 'Sami');
    expect(scripted.puts.single['userId'], 'u-1');
  });

  test('a body with no userId aborts BEFORE any PUT is issued', () async {
    final scripted = _dio(me: <String, dynamic>{'email': 'a@b.c'});
    final repo = DioAvatarRepository(scripted.dio, const _PlainCdn());

    await expectLater(
      repo.uploadAvatar(Uint8List(4)),
      throwsA(
        isA<AvatarRepositoryException>().having(
          (e) => e.failure,
          'failure',
          AvatarUploadFailure.unauthorized,
        ),
      ),
    );
    expect(scripted.puts, isEmpty);
  });

  test('a 413 on the PUT is tooLarge, not a generic unknown', () async {
    final scripted = _dio(
      me: <String, dynamic>{'userId': 'u-1'},
      putStatus: 413,
    );
    final repo = DioAvatarRepository(scripted.dio, const _PlainCdn());

    await expectLater(
      repo.uploadAvatar(Uint8List(4)),
      throwsA(
        isA<AvatarRepositoryException>().having(
          (e) => e.failure,
          'failure',
          AvatarUploadFailure.tooLarge,
        ),
      ),
    );
  });

  test('a 403 on the PUT is unauthorized', () async {
    final scripted = _dio(
      me: <String, dynamic>{'userId': 'u-1'},
      putStatus: 403,
    );
    final repo = DioAvatarRepository(scripted.dio, const _PlainCdn());

    await expectLater(
      repo.uploadAvatar(Uint8List(4)),
      throwsA(
        isA<AvatarRepositoryException>().having(
          (e) => e.failure,
          'failure',
          AvatarUploadFailure.unauthorized,
        ),
      ),
    );
  });

  test('removeAvatar preserves username while clearing profilePic', () async {
    final scripted = _dio(
      me: <String, dynamic>{'userId': 'u-1', 'name': 'Sami', 'email': 'a@b.c'},
    );
    final repo = DioAvatarRepository(scripted.dio, const _PlainCdn());

    await repo.removeAvatar();

    expect(scripted.puts.single['profilePic'], '');
    expect(scripted.puts.single['username'], 'Sami');
    expect(scripted.puts.single['email'], 'a@b.c');
  });
}
