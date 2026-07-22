import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/observability/session_trace/secret_redactor.dart';

const String _fakeJwt =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1LTEiLCJleHAiOjk5OTk5OTk5OTl9.S3cReTtOkEnLeAk';

/// The exact leak signature a run-mission gate would grep for: a raw
/// `Bearer ` header value or a JWT-shaped `eyJ…` token.
final RegExp _secretPattern = RegExp(r'Bearer |eyJ[A-Za-z0-9_-]{10,}\.');

void main() {
  group('redactString', () {
    test('replaces a Bearer-prefixed token as one unit', () {
      final out = SecretRedactor.redactString('Authorization: Bearer $_fakeJwt');
      expect(out, isNot(contains(_fakeJwt)));
      expect(out, isNot(contains('Bearer ')));
      expect(out, contains(SecretRedactor.redacted));
    });

    test('replaces a bare JWT-shaped string with no Bearer prefix', () {
      final out = SecretRedactor.redactString('token=$_fakeJwt;ok');
      expect(out, isNot(contains(_fakeJwt)));
      expect(out, contains(SecretRedactor.redacted));
    });

    test('replaces a long opaque/hex token embedding a digit', () {
      const fcmLike = 'dXXXXXXXXXXXXXXXXXXXXXXXX12:APA91bH0abcdef1234567890XYZ';
      final out = SecretRedactor.redactString('fcm=$fcmLike');
      expect(out, isNot(contains(fcmLike)));
      expect(out, contains(SecretRedactor.redacted));
    });

    test('leaves ordinary short prose completely untouched', () {
      const prose = 'Your order is on the way to Riyadh.';
      expect(SecretRedactor.redactString(prose), prose);
    });

    test('is null-safe on empty input', () {
      expect(SecretRedactor.redactString(''), '');
    });
  });

  group('redactHeaders', () {
    test('redacts Authorization/Cookie, passes non-sensitive ones through',
        () {
      final out = SecretRedactor.redactHeaders(<String, Object?>{
        'Authorization': 'Bearer $_fakeJwt',
        'Content-Type': 'application/json',
        'Cookie': 'session=abc',
      });
      expect(out['Authorization'], startsWith('tok:'));
      expect(out['Authorization'], isNot(contains(_fakeJwt)));
      expect(out['Cookie'], startsWith('tok:'));
      expect(out['Content-Type'], 'application/json');
    });
  });

  group('redactBody — sensitive keys (hard floor, both full modes)', () {
    for (final full in [true, false]) {
      test('token/authorization/password/passcode/otp/fcm/secret/apiKey '
          'keys never leak raw (full=$full)', () {
        final out = SecretRedactor.redactBody(<String, Object?>{
          'token': 'raw-token-value-0001',
          'authorization': 'Bearer $_fakeJwt',
          'password': 'hunter2-super-secret',
          'passcode': '1234',
          'otp': '446789',
          'fcmToken': 'fcm-registration-abcdef123456',
          'secret': 'shh-do-not-log-this',
          'apiKey': 'sk_live_ABCDEF1234567890',
          'apiSecret': 'as_live_ABCDEF1234567890',
          'clientSecret': 'cs_ABCDEF1234567890',
          'accessToken': _fakeJwt,
          'refreshToken': 'refresh-abcdef123456',
          'idToken': _fakeJwt,
          'deviceToken': 'device-abcdef123456',
          'nonSecretField': 'this is fine to show',
        }, full: full) as Map<String, Object?>;

        for (final key in [
          'token',
          'authorization',
          'password',
          'passcode',
          'otp',
          'fcmToken',
          'secret',
          'apiKey',
          'apiSecret',
          'clientSecret',
          'accessToken',
          'refreshToken',
          'idToken',
          'deviceToken',
        ]) {
          expect(out[key], startsWith('tok:'), reason: 'key: $key');
        }
        expect(out['nonSecretField'], 'this is fine to show');
      });
    }

    test('recurses into nested maps regardless of full', () {
      final out = SecretRedactor.redactBody(<String, Object?>{
        'nested': <String, Object?>{'password': 'deep-secret-value'},
      }, full: false) as Map<String, Object?>;
      final nested = out['nested'] as Map<String, Object?>;
      expect(nested['password'], startsWith('tok:'));
      expect(nested['password'], isNot(contains('deep-secret-value')));
    });

    test('recurses into list-of-maps (a roster) so no row leaks a secret',
        () {
      final out = SecretRedactor.redactBody(<String, Object?>{
        'users': <Object?>[
          <String, Object?>{'userId': 'u1', 'passcode': 'ROSTER-SECRET-1'},
          <String, Object?>{'userId': 'u2', 'passcode': 'ROSTER-SECRET-2'},
        ],
      }, full: true) as Map<String, Object?>;
      final users = out['users'] as List<Object?>;
      final row0 = users[0] as Map<String, Object?>;
      final row1 = users[1] as Map<String, Object?>;
      expect(row0['passcode'], startsWith('tok:'));
      expect(row0['userId'], 'u1');
      expect(row1['passcode'], isNot(contains('ROSTER-SECRET-2')));
    });

    test('a JWT embedded in a NON-sensitive-keyed string is still caught '
        '(pattern floor applies everywhere, full=false too)', () {
      final out = SecretRedactor.redactBody(<String, Object?>{
        'message': 'auth failed for Bearer $_fakeJwt',
      }, full: false) as Map<String, Object?>;
      expect(out['message'], isNot(contains(_fakeJwt)));
      expect(out['message'], isNot(contains('Bearer ')));
    });

    test('null body redacts to null', () {
      expect(SecretRedactor.redactBody(null, full: true), isNull);
    });

    test('a bare scalar (String) is pattern-scanned directly', () {
      expect(
        SecretRedactor.redactBody('Bearer $_fakeJwt', full: true),
        isNot(contains(_fakeJwt)),
      );
    });

    test('numbers/bools pass through untouched', () {
      final out = SecretRedactor.redactBody(<String, Object?>{
        'count': 3,
        'active': true,
      }, full: true) as Map<String, Object?>;
      expect(out['count'], 3);
      expect(out['active'], true);
    });

    test('full=true additionally masks long bare digit runs (phone/account '
        'numbers) that are not behind a named sensitive key', () {
      final out = SecretRedactor.redactBody(<String, Object?>{
        'notes': 'call 5551234567890 to confirm',
      }, full: true) as Map<String, Object?>;
      expect(out['notes'], isNot(contains('5551234567890')));
    });

    test('full=false relaxes ONLY that extra digit-run precaution — the '
        'hard floor (keys + patterns) is unchanged', () {
      final out = SecretRedactor.redactBody(<String, Object?>{
        'notes': 'call 5551234567890 to confirm',
        'password': 'still-a-secret-value',
      }, full: false) as Map<String, Object?>;
      expect(out['notes'], contains('5551234567890'));
      expect(out['password'], startsWith('tok:'));
    });
  });

  group('redactAndTruncate', () {
    test('a small redacted body passes through unchanged', () {
      final out = SecretRedactor.redactAndTruncate(
        <String, Object?>{'ok': true},
        full: true,
        maxBytes: 8192,
      );
      expect(out, {'ok': true});
    });

    test('an oversized body collapses to a truncated-bytes marker', () {
      final big = <String, Object?>{'blob': 'x' * 10000};
      final out = SecretRedactor.redactAndTruncate(
        big,
        full: true,
        maxBytes: 100,
      );
      expect(out, isA<String>());
      expect(out.toString(), startsWith('<truncated '));
      expect(out.toString(), endsWith(' bytes>'));
    });

    test('null passes through as null', () {
      expect(
        SecretRedactor.redactAndTruncate(null, full: true, maxBytes: 10),
        isNull,
      );
    });
  });

  group('redactLabel', () {
    test('null-safe', () {
      expect(SecretRedactor.redactLabel(null), isNull);
    });

    test('scrubs a secret pattern embedded in a Semantics label', () {
      final out = SecretRedactor.redactLabel('session Bearer $_fakeJwt');
      expect(out, isNot(contains(_fakeJwt)));
    });

    test('passes an ordinary label through untouched', () {
      expect(SecretRedactor.redactLabel('Submit order'), 'Submit order');
    });
  });

  group('isSensitiveKey', () {
    test('is case/underscore/dash-insensitive over the full key set', () {
      for (final key in [
        'apiKey',
        'api_key',
        'API-KEY',
        'authToken',
        'auth_token',
        'sessionToken',
        'clientSecret',
      ]) {
        expect(SecretRedactor.isSensitiveKey(key), isTrue, reason: key);
      }
      expect(SecretRedactor.isSensitiveKey('orderId'), isFalse);
    });
  });

  group('SECURITY GATE: no secret survives verbatim across the whole shape',
      () {
    Map<String, Object?> buildLeakyPayload() => <String, Object?>{
          'headers': <String, Object?>{
            'Authorization': 'Bearer $_fakeJwt',
          },
          'body': <String, Object?>{
            'password': 'p@ssW0rd-super-secret',
            'otp': '048213',
            'fcmToken': 'fcm-abcdef1234567890XYZ',
            'nested': <String, Object?>{'apiKey': 'sk_live_ABCDEF123456'},
            'roster': <Object?>[
              <String, Object?>{'passcode': 'HANDOVER-0001'},
            ],
            'freeText': 'auth via Bearer $_fakeJwt failed',
          },
        };

    for (final full in [true, false]) {
      test('holds with full=$full', () {
        final leaky = buildLeakyPayload();
        final redactedHeaders = SecretRedactor.redactHeaders(
          leaky['headers']! as Map<String, Object?>,
        );
        final redactedBody =
            SecretRedactor.redactBody(leaky['body'], full: full);
        final serialized =
            jsonEncode(redactedHeaders) + jsonEncode(redactedBody);

        expect(serialized, isNot(contains(_fakeJwt)));
        expect(serialized, isNot(contains('p@ssW0rd-super-secret')));
        expect(serialized, isNot(contains('048213')));
        expect(serialized, isNot(contains('fcm-abcdef1234567890XYZ')));
        expect(serialized, isNot(contains('sk_live_ABCDEF123456')));
        expect(serialized, isNot(contains('HANDOVER-0001')));
        expect(_secretPattern.hasMatch(serialized), isFalse,
            reason: 'no Bearer/JWT pattern may ever survive:\n$serialized');
      });
    }
  });
}
