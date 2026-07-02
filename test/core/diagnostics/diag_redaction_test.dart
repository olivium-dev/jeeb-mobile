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
        'nested': <String, Object?>{'refresh_token': 'r-YYYY-5678'},
      });
      expect(out['fcmToken'], startsWith('tok:'));
      expect(out['fcmToken'], isNot(contains('XXXX')));
      expect(out['deviceId'], 'dev-1');
      final nested = out['nested'] as Map<String, Object?>;
      expect(nested['refresh_token'], startsWith('tok:'));
      expect(nested['refresh_token'], endsWith('5678'));
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
