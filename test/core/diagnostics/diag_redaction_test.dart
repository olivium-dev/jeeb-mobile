import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag_redaction.dart';

void main() {
  group('redactToken', () {
    test('never returns the secret verbatim; keeps only a handle + last4', () {
      const secret = 'header.payload.super-secret-signature-ABCD';
      final handle = DiagRedaction.redactToken(secret);
      expect(handle, isNot(contains('super-secret-signature')));
      expect(handle, startsWith('tok:'));
      expect(handle, endsWith('ABCD'));
    });

    test('is stable — same secret maps to the same handle (correlation)', () {
      const secret = 'fcm-token-abcdef123456';
      expect(
        DiagRedaction.redactToken(secret),
        DiagRedaction.redactToken(secret),
      );
    });

    test('distinguishes different secrets', () {
      expect(
        DiagRedaction.redactToken('token-A-0001'),
        isNot(DiagRedaction.redactToken('token-B-0002')),
      );
    });

    test('null / empty degrade to a fixed sentinel', () {
      expect(DiagRedaction.redactToken(null), 'tok:∅');
      expect(DiagRedaction.redactToken(''), 'tok:∅');
    });

    // G4 diag-redaction rule: for SHORT secrets (a 4-digit handover OTP, a
    test('short secrets (OTP/PIN) redact to hash-only — no tail digits', () {
      const otp = '1234';
      final handle = DiagRedaction.redactToken(otp);
      expect(handle, startsWith('tok:'));
      expect(handle, isNot(contains('1234')));
      expect(handle, isNot(contains('~')));

      const pin = '987654';
      final pinHandle = DiagRedaction.redactToken(pin);
      expect(pinHandle, isNot(contains('9876')));
      expect(pinHandle, isNot(contains('7654')));
    });
  });

  group('redactHeaders', () {
    test('replaces Authorization and cookies, passes others through', () {
      final out = DiagRedaction.redactHeaders(<String, Object?>{
        'Authorization': 'Bearer eyJ.jwt.sig',
        'Content-Type': 'application/json',
        'Cookie': 'session=abc',
      });
      expect(out['Authorization'], startsWith('tok:'));
      expect(out['Authorization'], isNot(contains('jwt')));
      expect(out['Cookie'], startsWith('tok:'));
      expect(out['Content-Type'], 'application/json');
    });
  });

  group('scrubMap', () {
    test('redacts sensitive keys (case/underscore-insensitive), recurses', () {
      final out = DiagRedaction.scrubMap(<String, Object?>{
        'fcmToken': 'fcm-XXXX-1234',
        'deviceId': 'dev-1',
        'nested': <String, Object?>{'refresh_token': 'r-YYYY-refresh-5678'},
      });
      expect(out['fcmToken'], startsWith('tok:'));
      expect(out['fcmToken'], isNot(contains('XXXX')));
      expect(out['deviceId'], 'dev-1');
      final nested = out['nested'] as Map<String, Object?>;
      expect(nested['refresh_token'], startsWith('tok:'));
      expect(nested['refresh_token'], endsWith('5678'));
    });

    // G4: the delivery handover code must never reach a diag line — in any
    test('handoverCode-shaped keys are masked, raw digits never leak', () {
      final out = DiagRedaction.scrubMap(<String, Object?>{
        'handoverCode': '1234',
        'handover_code': '5678',
        'otpCode': '2468',
        'deliveryCode': '1357',
        'delivery': <String, Object?>{'handoverCode': '9999'},
        'deliveryId': 'DLV-1',
      });
      expect(out['handoverCode'], isNot(contains('1234')));
      expect(out['handover_code'], isNot(contains('5678')));
      expect(out['otpCode'], isNot(contains('2468')));
      expect(out['deliveryCode'], isNot(contains('1357')));
      final nested = out['delivery'] as Map<String, Object?>;
      expect(nested['handoverCode'], isNot(contains('9999')));
      // Non-secret sibling fields pass through.
      expect(out['deliveryId'], 'DLV-1');
    });

    // JEBV4-113: the KYC submit body carries the government-ID number
    test('KYC id_number / national_id never leak raw digits', () {
      final out = DiagRedaction.scrubMap(<String, Object?>{
        'id_number': '123456789012',
        'idNumber': '210987654321',
        'national_id': '111222333444',
        'id_type': 'national_id',
        'nested': <String, Object?>{'id_number': '999888777666'},
      });
      expect(out['id_number'], isNot(contains('123456789012')));
      expect(out['id_number'], startsWith('tok:'));
      expect(out['idNumber'], isNot(contains('210987654321')));
      expect(out['national_id'], isNot(contains('111222333444')));
      final nested = out['nested'] as Map<String, Object?>;
      expect(nested['id_number'], isNot(contains('999888777666')));
      // The TYPE is not a secret — it must pass through for diagnosability.
      expect(out['id_type'], 'national_id');
    });

    // Super-login hardening: the demo-users roster is a LIST of maps, each
    test('recurses into list elements so nested passcodes are redacted', () {
      final out = DiagRedaction.scrubMap(<String, Object?>{
        'users': <Object?>[
          <String, Object?>{
            'userId': 'u1',
            'name': 'Nour',
            'passcode': 'JEEB-SL-SECRET-VALUE',
          },
          <String, Object?>{'userId': 'u2', 'passcode': 'OTHER-SECRET'},
        ],
      });
      final users = out['users'] as List<Object?>;
      final row0 = users[0] as Map<String, Object?>;
      final row1 = users[1] as Map<String, Object?>;
      expect(row0['passcode'], startsWith('tok:'));
      expect(row0['passcode'], isNot(contains('SECRET')));
      expect(row0['userId'], 'u1');
      expect(row0['name'], 'Nour');
      expect(row1['passcode'], isNot(contains('SECRET')));
    });
  });

  group('scrubPath', () {
    test('strips query strings that may carry tokens', () {
      expect(
        DiagRedaction.scrubPath('/v1/requests?access_token=abc&x=1'),
        '/v1/requests',
      );
    });

    test('leaves a bare path pattern untouched', () {
      expect(DiagRedaction.scrubPath('/orders/:id'), '/orders/:id');
    });
  });

  group('OTP body suppression paths', () {
    test('matches request and verify across Dio path representations', () {
      for (final path in <String>[
        '/v1/auth/otp/request',
        '/v1/auth/otp/request/',
        'v1/auth/otp/verify',
        'HTTPS://app.jeeb.fds-1.com/v1/auth/otp/VERIFY?source=test',
        '/auth/otp/request',
        'auth/otp/verify/',
      ]) {
        expect(DiagRedaction.isBodySuppressedPath(path), isTrue, reason: path);
      }
    });

    test('does not suppress unrelated or merely similar endpoints', () {
      for (final path in <String>[
        '/v1/auth/login',
        '/v1/auth/otp/request-status',
        '/v1/auth/otp/verify/receipt',
        '/auth/otp/request-status',
        '/auth/otp/verify/receipt',
        '/v1/health?next=/v1/auth/otp/request',
      ]) {
        expect(DiagRedaction.isBodySuppressedPath(path), isFalse, reason: path);
      }
    });
  });
}
