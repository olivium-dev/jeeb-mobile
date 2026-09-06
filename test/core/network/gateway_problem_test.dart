import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/gateway_problem.dart';

void main() {
  group('GatewayProblem.tryParse — non-problem bodies', () {
    test('returns null for a null, empty or list body', () {
      expect(GatewayProblem.tryParse(null), isNull);
      expect(GatewayProblem.tryParse(''), isNull);
      expect(GatewayProblem.tryParse(const <Object?>[]), isNull);
      expect(GatewayProblem.tryParse(const <String, Object?>{}), isNull);
    });

    test('returns null for a non-JSON HTML error page', () {
      const html = '<!DOCTYPE html><html><head><title>502 Bad Gateway</title>'
          '</head><body><h1>502 Bad Gateway</h1><hr>nginx</body></html>';
      expect(GatewayProblem.tryParse(html), isNull);
    });

    test('returns null for a bare string body', () {
      expect(GatewayProblem.tryParse('Service Unavailable'), isNull);
      expect(GatewayProblem.tryParse('boom'), isNull);
      expect(GatewayProblem.tryParse('42'), isNull);
    });

    test('returns null for a map carrying no RFC 7807 member', () {
      expect(
        GatewayProblem.tryParse(const <String, Object?>{'foo': 1, 'bar': true}),
        isNull,
      );
    });

    test('never reads code/error/message', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'code': 'OFFER_CAP',
        'error': 'offer cap reached',
        'message': 'You already have 20 offers',
      });
      expect(problem, isNull);
    });

    test('parses a problem body delivered as an undecoded JSON string', () {
      final problem = GatewayProblem.tryParse(
        '{"type":"https://jeeb.dev/errors/offer-already-exists",'
        '"title":"Conflict","status":409}',
      );
      expect(problem, isNotNull);
      expect(problem!.typeSuffix, 'offer-already-exists');
      expect(problem.status, 409);
    });
  });

  group('GatewayProblem.tryParse — typeSuffix', () {
    test('takes the last path segment of the type URI', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/offer-already-exists',
        'title': 'Conflict',
      });
      expect(problem!.typeSuffix, 'offer-already-exists');
    });

    test('keeps snake_case suffixes as the gateway spells them', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/invalid_otp',
        'status': 401,
      });
      expect(problem!.typeSuffix, 'invalid_otp');
    });

    test('is null for about:blank and for a body without a type', () {
      final blank = GatewayProblem.tryParse(
        const <String, Object?>{'type': 'about:blank', 'status': 500},
      );
      expect(blank!.typeSuffix, isNull);
      final untyped =
          GatewayProblem.tryParse(const <String, Object?>{'title': 'Oops'});
      expect(untyped!.typeSuffix, isNull);
    });

    test('ignores a query string and fragment', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/request-expired?lang=ar#detail',
        'status': 409,
      });
      expect(problem!.typeSuffix, 'request-expired');
    });

    test('an RFC status link is not a domain code', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://tools.ietf.org/html/rfc9110#section-15.5.2',
        'title': 'Unauthorized',
        'status': 401,
      });
      expect(
        problem!.typeSuffix,
        isNull,
        reason: 'a consumer switching on typeSuffix must never learn "rfc9110"',
      );
    });
  });

  group('GatewayProblem.tryParse — RFC 7807 members', () {
    test('reads type, title, detail, status, instance and traceId', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/validation-failed',
        'title': 'One or more validation errors occurred.',
        'detail': 'Pickup address is required.',
        'status': 400,
        'instance': '/v1/requests',
        'traceId': '00-8f3a2c-9b1d-01',
      });
      expect(problem!.type, 'https://jeeb.dev/errors/validation-failed');
      expect(problem.title, 'One or more validation errors occurred.');
      expect(problem.detail, 'Pickup address is required.');
      expect(problem.status, 400);
      expect(problem.instance, '/v1/requests');
      expect(problem.traceId, '00-8f3a2c-9b1d-01');
    });

    test('accepts a numeric status sent as a string', () {
      final problem = GatewayProblem.tryParse(
        const <String, Object?>{'title': 'Conflict', 'status': '409'},
      );
      expect(problem!.status, 409);
    });

    test('reads errors{} as field → messages, dropping empty entries', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/validation-failed',
        'status': 400,
        'field': 'pickup.address',
        'errors': <String, Object?>{
          'pickup.address': <String>['The address is required.'],
          'dropoff': <String>['Too far from pickup.', 'Outside coverage.'],
          'notes': 'Too long.',
          'ignored': <Object?>[],
        },
      });
      expect(problem!.errors.keys,
          containsAll(<String>['pickup.address', 'dropoff', 'notes']));
      expect(problem.errors['dropoff'], hasLength(2));
      expect(problem.errors['notes'], <String>['Too long.']);
      expect(problem.errors.containsKey('ignored'), isFalse);
      expect(problem.field, 'pickup.address');
    });

    test('an errors{} body alone is still a problem document', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'errors': <String, Object?>{
          'phone': <String>['Invalid number.'],
        },
      });
      expect(problem, isNotNull);
      expect(problem!.errors['phone'], <String>['Invalid number.']);
    });

    test('extensions hold every non-reserved member only', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/rate-limited',
        'status': 429,
        'traceId': 'abc',
        'errors': <String, Object?>{},
        'retryAfter': 30,
        'scope': 'otp',
      });
      expect(problem!.extensions.keys, containsAll(<String>['retryAfter', 'scope']));
      expect(problem.extensions.containsKey('type'), isFalse);
      expect(problem.extensions.containsKey('status'), isFalse);
      expect(problem.extensions.containsKey('traceId'), isFalse);
      expect(problem.extensions.containsKey('errors'), isFalse);
    });
  });

  group('GatewayProblem — typed getters', () {
    test('retryAfter accepts seconds sent as a number or a string', () {
      final numeric = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/rate-limited',
        'status': 429,
        'retryAfter': 30,
      });
      expect(numeric!.retryAfter, const Duration(seconds: 30));
      final text = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/too-many-attempts',
        'status': 429,
        'retryAfter': '45',
      });
      expect(text!.retryAfter, const Duration(seconds: 45));
    });

    test('retryAfter is null when absent or non-positive', () {
      final absent =
          GatewayProblem.tryParse(const <String, Object?>{'status': 429});
      expect(absent!.retryAfter, isNull);
      final zero = GatewayProblem.tryParse(
        const <String, Object?>{'status': 429, 'retryAfter': 0},
      );
      expect(zero!.retryAfter, isNull);
    });

    test('attemptsRemaining survives the OTP 401 body', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/invalid_otp',
        'title': 'Invalid code',
        'status': 401,
        'attemptsRemaining': 2,
      });
      expect(problem!.attemptsRemaining, 2);
      expect(problem.typeSuffix, 'invalid_otp');
    });

    test('escalationId and lockedAt survive the handover 423 body', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/handover-locked',
        'title': 'Handover locked',
        'status': 423,
        'escalationId': 'esc_9f21',
        'lockedAt': '2026-09-04T10:15:00Z',
      });
      expect(problem!.escalationId, 'esc_9f21');
      expect(problem.lockedAt, DateTime.utc(2026, 9, 4, 10, 15));
    });

    test('lockedAt is null when the timestamp is unparseable', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'status': 423,
        'lockedAt': 'yesterday',
      });
      expect(problem!.lockedAt, isNull);
    });

    test('matches reads plain keywords and {keyword} objects', () {
      final objects = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/prohibited-item-requires-ack',
        'status': 409,
        'matches': <Object?>[
          <String, Object?>{'keyword': 'knife', 'category': 'weapons'},
          <String, Object?>{'keyword': 'gas canister'},
          <String, Object?>{'category': 'no-keyword'},
        ],
      });
      expect(objects!.matches, <String>['knife', 'gas canister']);
      final strings = GatewayProblem.tryParse(const <String, Object?>{
        'status': 409,
        'matches': <Object?>['knife', '', 'lighter'],
      });
      expect(strings!.matches, <String>['knife', 'lighter']);
      final none =
          GatewayProblem.tryParse(const <String, Object?>{'status': 409});
      expect(none!.matches, isEmpty);
    });

    test('reads the funding shortfall extensions', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/insufficient-funds',
        'status': 409,
        'needed': 12.5,
        'available': 3,
        'currency': 'USD',
      });
      expect(problem!.needed, 12.5);
      expect(problem.available, 3.0);
      expect(problem.currency, 'USD');
    });

    test('reads reason, reasonCode and accountStatus from a 403', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/account-suspended',
        'title': 'Forbidden',
        'status': 403,
        'reason': 'Account under review',
        'reasonCode': 'account_suspended',
        'accountStatus': 'suspended',
      });
      expect(problem!.reason, 'Account under review');
      expect(problem.reasonCode, 'account_suspended');
      expect(problem.accountStatus, 'suspended');
    });

    test('reads upstreamCode and existingCaseId', () {
      final upstream = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/identity-unavailable',
        'status': 503,
        'upstreamCode': 'identity_unavailable',
      });
      expect(upstream!.upstreamCode, 'identity_unavailable');
      final support = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/case-already-open',
        'status': 409,
        'existingCaseId': 'case_77',
      });
      expect(support!.existingCaseId, 'case_77');
    });

    test('typed getters are null when the extension has the wrong shape', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'status': 409,
        'escalationId': 42,
        'attemptsRemaining': 'many',
        'needed': 'lots',
        'matches': 'knife',
      });
      expect(problem!.escalationId, isNull);
      expect(problem.attemptsRemaining, isNull);
      expect(problem.needed, isNull);
      expect(problem.matches, isEmpty);
    });
  });

  group('GatewayProblem — value semantics', () {
    test('is const-constructible', () {
      const problem = GatewayProblem(status: 500, title: 'Server error');
      expect(identical(problem, const GatewayProblem(status: 500, title: 'Server error')), isTrue);
    });

    test('== and hashCode compare members and parsed maps', () {
      const body = <String, Object?>{
        'type': 'https://jeeb.dev/errors/validation-failed',
        'status': 400,
        'errors': <String, Object?>{
          'phone': <String>['Invalid number.'],
        },
        'field': 'phone',
      };
      final a = GatewayProblem.tryParse(body);
      final b = GatewayProblem.tryParse(body);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      final other = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/validation-failed',
        'status': 422,
      });
      expect(a == other, isFalse);
    });

    test('toString carries the discriminator, not the server prose', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/validation-failed',
        'title': 'One or more validation errors occurred.',
        'detail': 'Recipient 03 555 123 is not reachable.',
        'status': 400,
        'traceId': 'trace-77',
        'errors': <String, Object?>{
          'phone': <String>['Invalid number.'],
        },
      });
      final text = problem.toString();
      expect(text, contains('validation-failed'));
      expect(text, contains('status: 400'));
      expect(text, contains('traceId: trace-77'));
      expect(text, isNot(contains('Recipient')));
      expect(text, isNot(contains('One or more')));
    });
  });
}
