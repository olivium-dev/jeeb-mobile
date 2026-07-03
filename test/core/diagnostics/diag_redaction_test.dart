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
    // 6-digit PIN) "the last 4 chars" is effectively the whole secret — the
    // handle must be hash-only, leaking not a single digit.
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
    // casing, nesting, or snake_case spelling. For a 4-digit code the handle
    // must not contain the digits at all (hash-only short-secret rule).
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
}
