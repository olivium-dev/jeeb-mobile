import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/devtool/env_index/env_index_client.dart';

// Envelope produced by jeeb-static-apis scripts/encrypt.py with this fixed
// key/nonce; the ciphertext carries the 16-byte GCM tag appended.
const String kTestKeyHex =
    '000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f';
const String kTestNonceB64 = 'Dw4NDAsKCQgHBgUE';
const String kTestCiphertextB64 =
    '3xLCPzOyws+9usMsUfXnI1NXM0K6KZUFIizKvkYoigg2uvF2BnlCoxCGDsGxaUZzfnKaPwXY'
    'MJ+HfnytCFUs7pANZXoVOM3eO3wamXJEFdO2Xm++twEzmCv0c+YrYqspd8+/9Npqw+++qPGN'
    'VaaN6QJxmUp0TVHB+WYa+Yes8YWwzOtxCPyhDYmS8rgxPt2ZXhcgQvspFu5qVLRI0sIFMqc0'
    'UltDAY4HFXYRmRZpdffe1uKag6NRi2qn1CAvb81X+MhZg2tFkx4snsdQczGWYkpTT5lmsft0'
    'kuDTSungj0j7sCaUyNwbG/k0F1Tsg74Qcx+QRepeQsfgy9USQGqmHgGLjaLNYVuLBnm4WshF'
    'OmlAPurYGdI1QknvJD+wYTNoOf86rrL4U9ws8C0Uu75XXVe2sZ1jCY2xnpb5XTpbpE6YMVmG'
    '4Gdz+c/w7evd6M9g2uR2WGYLOAy1MoU6tRQ2muwoFlAZe4YdzIp9Y3R3hM+sf8PLgZF4twI5'
    'FTANCucl1k2RmjS4jDAR9wceo+99akx3MFTN1unS7O8VN41/KMZWi6iw5fbmS/C7lYgsBuCH'
    '7GVi319rVmxGuRc7el2J9W9WgGizZjDMAqyddhUhR5nW+URkz9allHSmBjomzJuYOKjl9rDw'
    'O9zlUZfq0EHc';

Map<String, dynamic> testEnvelope() => <String, dynamic>{
  'version': 1,
  'alg': 'AES-256-GCM',
  'keyId': 'k1',
  'nonce': kTestNonceB64,
  'ciphertext': kTestCiphertextB64,
};

void main() {
  group('EnvIndexClient.decryptEnvelope', () {
    test('decrypts the fixture and parses both environments', () async {
      final environments = await EnvIndexClient.decryptEnvelope(
        testEnvelope(),
        keyHex: kTestKeyHex,
      );

      expect(environments, hasLength(2));

      final staging = environments[0];
      expect(staging.id, 'staging');
      expect(staging.label, 'Staging');
      expect(staging.gatewayBaseUrl, 'https://app.jeeb.fds-1.com');
      expect(
        staging.realtimeSocketUrl,
        'wss://app.jeeb.fds-1.com/socket/websocket',
      );
      expect(staging.cmsUrl, 'https://cms.jeeb.fds-1.com');
      expect(staging.reachability, 'public');
      expect(staging.cleartext, isFalse);
      expect(staging.notes, 'gh actions only');

      final msi = environments[1];
      expect(msi.id, 'dev-msi-lan');
      expect(msi.gatewayBaseUrl, 'http://192.168.2.39:10090');
      expect(msi.realtimeSocketUrl, isNull);
      expect(msi.cmsUrl, isNull);
      expect(msi.reachability, 'lan');
      expect(msi.cleartext, isTrue);
      expect(msi.notes, isNull);
    });

    test('rejects a wrong key with an authentication error', () {
      expect(
        () => EnvIndexClient.decryptEnvelope(
          testEnvelope(),
          keyHex: 'ff' * 32,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('rejects a truncated ciphertext', () {
      final envelope = testEnvelope()
        ..['ciphertext'] = base64Encode(List.filled(10, 0));
      expect(
        () => EnvIndexClient.decryptEnvelope(envelope, keyHex: kTestKeyHex),
        throwsFormatException,
      );
    });

    test('rejects a tampered ciphertext', () {
      final bytes = base64Decode(kTestCiphertextB64);
      bytes[0] ^= 0x01;
      final envelope = testEnvelope()..['ciphertext'] = base64Encode(bytes);
      expect(
        () => EnvIndexClient.decryptEnvelope(envelope, keyHex: kTestKeyHex),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });

  group('EnvIndexClient.hexToBytes', () {
    test('round-trips the test key', () {
      expect(
        EnvIndexClient.hexToBytes(kTestKeyHex),
        List.generate(32, (i) => i),
      );
    });

    test('rejects odd-length input', () {
      expect(() => EnvIndexClient.hexToBytes('abc'), throwsFormatException);
    });

    test('rejects non-hex input', () {
      expect(() => EnvIndexClient.hexToBytes('zz'), throwsFormatException);
    });
  });

  group('EnvIndexClient.isConfigured', () {
    test('is false when no JEEB_ENV_INDEX_KEY define is supplied', () {
      expect(EnvIndexClient.isConfigured, isFalse);
    });
  });

  group('EnvIndexClient.fetch', () {
    test('fetches the envelope over HTTP and decrypts it', () async {
      final dio = Dio()
        ..httpClientAdapter = _FixedResponseAdapter(
          jsonEncode(testEnvelope()),
        );
      final environments = await EnvIndexClient(
        dio: dio,
      ).fetch(keyHex: kTestKeyHex);
      expect(environments.map((e) => e.id), ['staging', 'dev-msi-lan']);
    });
  });
}

/// Serves one fixed JSON body for any request; keeps the test offline.
class _FixedResponseAdapter implements HttpClientAdapter {
  _FixedResponseAdapter(this.body);

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
