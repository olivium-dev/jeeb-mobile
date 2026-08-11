// D-V5: /v1/users/me returns `phone-only+<hex>@jeeb.internal` as the email for
// phone-only signups; the profile header rendered that identifier verbatim.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/customer_profile/data/dio_customer_profile_repository.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);

  final Map<String, Object?> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

DioCustomerProfileRepository _repo(
  Map<String, Object?> body, {
  Future<String?> Function()? phoneFallback,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
    ..httpClientAdapter = _StubAdapter(body);
  return DioCustomerProfileRepository(dio, phoneFallback: phoneFallback);
}

void main() {
  group('synthetic email is never surfaced', () {
    test('the exact live handle is dropped', () async {
      final data = await _repo(const {
        'name': 'Sami Fawaz',
        'email': 'phone-only+59bd73c9b7b84b0d8f1a2b3c4d5e6f70@jeeb.internal',
      }).fetchProfile();

      expect(data.email, isNull);
      expect(data.name, 'Sami Fawaz');
    });

    test('any @jeeb.internal address is dropped', () async {
      final data = await _repo(const {
        'email': 'svc-account@jeeb.internal',
      }).fetchProfile();

      expect(data.email, isNull);
    });

    test('a real email is untouched', () async {
      final data = await _repo(const {
        'email': 'sami@example.com',
      }).fetchProfile();

      expect(data.email, 'sami@example.com');
    });

    test('a real address that merely contains "phone-only" survives', () async {
      final data = await _repo(const {
        'email': 'phone-only-support@example.com',
      }).fetchProfile();

      expect(data.email, 'phone-only-support@example.com');
    });
  });

  group('locally stored phone substitutes for the dropped handle', () {
    test('the OTP phone becomes the subtitle', () async {
      final data = await _repo(
        const {'email': 'phone-only+abc123@jeeb.internal'},
        phoneFallback: () async => '+96170123456',
      ).fetchProfile();

      expect(data.email, '+96170123456');
    });

    test('a real email is never overwritten by the fallback', () async {
      final data = await _repo(
        const {'email': 'sami@example.com'},
        phoneFallback: () async => '+96170123456',
      ).fetchProfile();

      expect(data.email, 'sami@example.com');
    });

    test('no stored phone leaves the subtitle absent, never the handle',
        () async {
      final data = await _repo(
        const {'email': 'phone-only+abc123@jeeb.internal'},
        phoneFallback: () async => null,
      ).fetchProfile();

      expect(data.email, isNull);
    });
  });
}
