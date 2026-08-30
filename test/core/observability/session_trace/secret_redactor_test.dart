import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/observability/session_trace/audited_interaction_identifiers.dart';
import 'package:jeeb_mobile/core/observability/session_trace/secret_redactor.dart';

import 'static_interaction_inventory.dart';

const String _fakeJwt =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1LTEiLCJleHAiOjk5OTk5OTk5OTl9.S3cReTtOkEnLeAk';

/// The exact leak signature a run-mission gate would grep for: a raw
/// `Bearer ` header value or a JWT-shaped `eyJ…` token.
final RegExp _secretPattern = RegExp(r'Bearer |eyJ[A-Za-z0-9_-]{10,}\.');

const List<String> _sensitiveControlSuffixes = <String>[
  '_body',
  '_composer',
  '_field',
  '_input',
  '_search',
];

const List<String> _sensitiveControlMarkers = <String>[
  'comment_field',
  'description_input',
  'description_field',
  'name_field',
  'name_input',
  'note_field',
  'passcode',
  'password',
  'price_field',
  'search_field',
  'search_input',
  'user_id',
];

void main() {
  group('redactString', () {
    test('replaces a Bearer-prefixed token as one unit', () {
      final out = SecretRedactor.redactString(
        'Authorization: Bearer $_fakeJwt',
      );
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
    test('redacts Authorization/Cookie, passes non-sensitive ones through', () {
      final out = SecretRedactor.redactHeaders(<String, Object?>{
        'Authorization': 'Bearer $_fakeJwt',
        'Content-Type': 'application/json',
        'Cookie': 'session=abc',
      });
      expect(out['Authorization'], SecretRedactor.redacted);
      expect(out['Authorization'], isNot(contains(_fakeJwt)));
      expect(out['Cookie'], SecretRedactor.redacted);
      expect(out['Content-Type'], 'application/json');
    });

    test('replaces every unaudited header name, including short secrets', () {
      const decoratedSecret = 'x-private-swordfish-secret';
      const shortSecret = 'swordfish';
      final out = SecretRedactor.redactHeaders(<String, Object?>{
        decoratedSecret: 'ignored',
        shortSecret: 'ignored',
      });
      final encoded = jsonEncode(out);

      expect(encoded, isNot(contains(decoratedSecret)));
      expect(encoded, isNot(contains(shortSecret)));
      expect(out, hasLength(2));
      expect(
        out.keys.where((key) => key.startsWith(SecretRedactor.redactedMapKey)),
        hasLength(2),
      );
    });

    test('bounds nested header lists and terminates cyclic lists', () {
      final oversized = List<Object?>.filled(
        SecretRedactor.maxCollectionEntries * 100,
        'application/json',
      );
      final cyclic = <Object?>[];
      cyclic.add(cyclic);

      final oversizedOut = SecretRedactor.redactHeaders(<String, Object?>{
        'Accept': oversized,
      });
      final cyclicOut = SecretRedactor.redactHeaders(<String, Object?>{
        'Accept': cyclic,
      });

      final bounded = oversizedOut['Accept']! as List<Object?>;
      expect(
        bounded.length,
        lessThanOrEqualTo(SecretRedactor.maxCollectionEntries + 1),
      );
      expect(bounded.last, SecretRedactor.truncated);
      expect(cyclicOut['Accept'], <Object?>[SecretRedactor.truncated]);
    });
  });

  group('redactBody — sensitive keys (non-disableable hard floor)', () {
    test('sanitizes sensitive map keys without collisions', () {
      const emailKey = 'victim@example.invalid';
      const phoneKey = '+31612345678';
      const bearerKey = 'Bearer $_fakeJwt';
      const decoratedSecretKey = 'hunter2-super-secret';
      const shortSecretKey = 'swordfish';
      const rawMarkerKey = SecretRedactor.redactedMapKey;
      final out =
          SecretRedactor.redactBody(<String, Object?>{
                rawMarkerKey: 'accepted',
                emailKey: 'accepted',
                phoneKey: 'accepted',
                bearerKey: 'accepted',
                _fakeJwt: 'accepted',
                decoratedSecretKey: 'accepted',
                shortSecretKey: 'accepted',
              })!
              as Map<String, Object?>;
      final encoded = jsonEncode(out);

      for (final canary in <String>[
        emailKey,
        phoneKey,
        bearerKey,
        _fakeJwt,
        decoratedSecretKey,
        shortSecretKey,
      ]) {
        expect(encoded, isNot(contains(canary)), reason: canary);
      }
      expect(out, hasLength(7));
      expect(
        out.keys.where((key) => key.startsWith(SecretRedactor.redactedMapKey)),
        hasLength(7),
      );
    });

    test('token/authorization/password/passcode/otp/fcm/secret/apiKey '
        'keys never leak raw', () {
      final out =
          SecretRedactor.redactBody(<String, Object?>{
                'token': 'raw-token-value-0001',
                'authorization': 'Bearer $_fakeJwt',
                'password': 'hunter2-super-secret',
                'passcode': '1234',
                'otp': '446789',
                'fcmToken': 'fcm-registration-abcdef123456',
                'secret': 'shh-do-not-log-this',
                'apiKey': 'test-key-not-real',
                'apiSecret': 'test-secret-not-real',
                'clientSecret': 'test-client-secret-not-real',
                'accessToken': _fakeJwt,
                'refreshToken': 'refresh-abcdef123456',
                'idToken': _fakeJwt,
                'deviceToken': 'device-abcdef123456',
                'kind': 'parcel',
              })
              as Map<String, Object?>;

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
        expect(out[key], SecretRedactor.redacted, reason: 'key: $key');
      }
      expect(out['kind'], 'parcel');
    });

    test('recurses into nested maps', () {
      final out =
          SecretRedactor.redactBody(<String, Object?>{
                'nested': <String, Object?>{'password': 'deep-secret-value'},
              })
              as Map<String, Object?>;
      final nested = out['nested'] as Map<String, Object?>;
      expect(nested['password'], SecretRedactor.redacted);
      expect(nested['password'], isNot(contains('deep-secret-value')));
    });

    test('recurses into list-of-maps (a roster) so no row leaks a secret', () {
      final out =
          SecretRedactor.redactBody(<String, Object?>{
                'users': <Object?>[
                  <String, Object?>{
                    'userId': 'u1',
                    'passcode': 'ROSTER-SECRET-1',
                  },
                  <String, Object?>{
                    'userId': 'u2',
                    'passcode': 'ROSTER-SECRET-2',
                  },
                ],
              })
              as Map<String, Object?>;
      final users = out['users'] as List<Object?>;
      final row0 = users[0] as Map<String, Object?>;
      final row1 = users[1] as Map<String, Object?>;
      expect(row0['passcode'], SecretRedactor.redacted);
      expect(row0['userId'], SecretRedactor.redacted);
      expect(row1['passcode'], isNot(contains('ROSTER-SECRET-2')));
    });

    test('a JWT embedded in a NON-sensitive-keyed string is still caught '
        '(pattern floor applies everywhere)', () {
      final out =
          SecretRedactor.redactBody(<String, Object?>{
                'message': 'auth failed for Bearer $_fakeJwt',
              })
              as Map<String, Object?>;
      expect(out['message'], isNot(contains(_fakeJwt)));
      expect(out['message'], isNot(contains('Bearer ')));
    });

    test('null body redacts to null', () {
      expect(SecretRedactor.redactBody(null), isNull);
    });

    test('a bare scalar (String) is pattern-scanned directly', () {
      expect(
        SecretRedactor.redactBody('Bearer $_fakeJwt'),
        isNot(contains(_fakeJwt)),
      );
    });

    test('numbers/bools pass through untouched', () {
      final out =
          SecretRedactor.redactBody(<String, Object?>{
                'count': 3,
                'active': true,
              })
              as Map<String, Object?>;
      expect(out['count'], 3);
      expect(out['active'], true);
    });

    test('unknown strings and generic code fields redact by default while '
        'audited enum fields remain useful', () {
      final out =
          SecretRedactor.redactBody(<String, Object?>{
                'unknown': 'arbitrary customer prose',
                'kind': 'parcel',
                'outcome': 'accepted',
                'code': 'invalid_amount',
                'codeWithSpaces': 'invalid amount for John',
              })!
              as Map<String, Object?>;

      expect(out['unknown'], SecretRedactor.redacted);
      expect(out['kind'], 'parcel');
      expect(out['outcome'], 'accepted');
      expect(out['code'], SecretRedactor.redacted);
      expect(out['codeWithSpaces'], SecretRedactor.redacted);
    });

    test(
      'generic code fields reject enum-like, capability, and OTP values',
      () {
        final out =
            SecretRedactor.redactBody(<String, Object?>{
                  'enumLike': <String, Object?>{'code': 'invalid_amount'},
                  'capabilityA': <String, Object?>{'code': 'ABCD-EFGH'},
                  'capabilityB': <String, Object?>{'code': 'test-placeholder'},
                  'code': 'otp_482913',
                  'kind': 'delivery_4829',
                })!
                as Map<String, Object?>;

        expect(out['code'], SecretRedactor.redacted);
        expect(out['kind'], SecretRedactor.redacted);
        for (final key in <String>['enumLike', 'capabilityA', 'capabilityB']) {
          expect(
            (out[key] as Map<String, Object?>)['code'],
            SecretRedactor.redacted,
            reason: key,
          );
        }
      },
    );

    test(
      'numeric OTPs and unknown numeric identifiers are denied by default',
      () {
        final out =
            SecretRedactor.redactBody(<String, Object?>{
                  'code': 482913,
                  'customerId': 739281,
                  'items': <Object?>[884422],
                  'count': 3,
                })!
                as Map<String, Object?>;

        expect(out['code'], SecretRedactor.redacted);
        expect(out['customerId'], SecretRedactor.redacted);
        expect(out['items'], <Object?>[SecretRedactor.redacted]);
        expect(out['count'], 3);
        expect(SecretRedactor.redactBody(482913), SecretRedactor.redacted);
      },
    );

    test('marker-shaped user strings cannot bypass default-deny', () {
      const canary = '<non-serializable body: PRIVATE-CANARY>';
      expect(SecretRedactor.redactBody(canary), SecretRedactor.redacted);
      expect(
        SecretRedactor.redactBody('<non-serializable body>'),
        '<non-serializable body>',
      );
    });

    test('all concrete PII and free-text field canaries are redacted', () {
      const canary = 'RAW-PRIVATE-CANARY';
      final keys = <String>[
        'transcription',
        'caption',
        'label',
        'building',
        'floorApt',
        'deliveryNotes',
        'name',
        'username',
        'targetLabel',
        'firstName',
        'lastName',
        'fullName',
        'customerName',
      ];
      final out =
          SecretRedactor.redactBody(<String, Object?>{
                for (final key in keys) key: '$canary-$key',
              })!
              as Map<String, Object?>;

      for (final key in keys) {
        expect(out[key], SecretRedactor.redacted, reason: key);
      }
      expect(jsonEncode(out), isNot(contains(canary)));
    });

    test('always masks long bare digit runs and free-text fields', () {
      final out =
          SecretRedactor.redactBody(<String, Object?>{
                'notes': 'call 5551234567890 to confirm',
              })
              as Map<String, Object?>;
      expect(out['notes'], isNot(contains('5551234567890')));
      expect(out['notes'], SecretRedactor.redacted);
    });

    test('the legacy full=false argument cannot relax redaction', () {
      final out =
          SecretRedactor.redactBody(<String, Object?>{
                'phone': '+31 6 1234 5678',
                'freeText': 'private typed value',
              }, full: false)
              as Map<String, Object?>;

      expect(out['phone'], SecretRedactor.redacted);
      expect(out['freeText'], SecretRedactor.redacted);
    });
  });

  group('redactAndTruncate', () {
    test('a small redacted body passes through unchanged', () {
      final out = SecretRedactor.redactAndTruncate(<String, Object?>{
        'ok': true,
      }, maxBytes: 8192);
      expect(out, {'ok': true});
    });

    test('an oversized body collapses to a truncated-bytes marker', () {
      final big = <String, Object?>{'samples': List<int>.filled(10000, 7)};
      final out = SecretRedactor.redactAndTruncate(big, maxBytes: 100);
      expect(out, isA<String>());
      expect(out.toString(), startsWith('<truncated '));
      expect(out.toString(), endsWith(' bytes>'));
    });

    test('null passes through as null', () {
      expect(SecretRedactor.redactAndTruncate(null, maxBytes: 10), isNull);
    });

    test('caps collection traversal before walking an oversized list', () {
      final huge = List<Object?>.filled(
        SecretRedactor.maxCollectionEntries * 100,
        <String, Object?>{'status': 'accepted'},
      );

      final out = SecretRedactor.redactAndTruncate(huge, maxBytes: 8192);

      expect(out, isA<List<Object?>>());
      expect(
        (out! as List<Object?>).length,
        SecretRedactor.maxCollectionEntries + 1,
      );
    });

    test('caps recursive depth and safely terminates cyclic bodies', () {
      final cyclic = <String, Object?>{};
      cyclic['data'] = cyclic;

      final out = SecretRedactor.redactAndTruncate(cyclic, maxBytes: 8192);
      final encoded = jsonEncode(out);

      expect(encoded, contains(SecretRedactor.truncated));
      expect(encoded.length, lessThan(8192));
    });

    test('rejects oversized strings before secret scanning or encoding', () {
      final hugeCanary = 'private-canary-${'x'.padRight(1000000, 'x')}';

      final out =
          SecretRedactor.redactAndTruncate(<String, Object?>{
                'status': hugeCanary,
              }, maxBytes: 8192)!
              as Map<String, Object?>;

      expect(out['status'], SecretRedactor.truncated);
      expect(jsonEncode(out), isNot(contains('private-canary')));
    });

    test('enforces a global input-byte budget across many safe fields', () {
      final body = <String, Object?>{
        for (var i = 0; i < SecretRedactor.maxCollectionEntries; i++)
          'status_$i': 'a'.padRight(SecretRedactor.maxStringCodeUnits, 'a'),
      };

      final out =
          SecretRedactor.redactAndTruncate(body, maxBytes: 8192)!
              as Map<String, Object?>;
      final encoded = jsonEncode(out);

      expect(out.values, contains(SecretRedactor.truncated));
      expect(encoded.length, lessThan(8192));
      expect(encoded, isNot(contains('a'.padRight(128, 'a'))));
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

    test('redacts an ordinary label because labels can contain user text', () {
      expect(
        SecretRedactor.redactLabel('Submit order'),
        SecretRedactor.redacted,
      );
    });
  });

  group('redactIdentifier', () {
    test('keeps a stable semantics id but rejects prose and numeric OTPs', () {
      expect(
        SecretRedactor.redactIdentifier('checkout.submit-button'),
        'checkout.submit-button',
      );
      expect(
        SecretRedactor.redactIdentifier('John Smith'),
        SecretRedactor.redacted,
      );
      expect(
        SecretRedactor.redactIdentifier('482913'),
        SecretRedactor.redacted,
      );
      expect(
        SecretRedactor.redactIdentifier('otp-482913'),
        SecretRedactor.redacted,
      );
      expect(
        SecretRedactor.redactIdentifier('phone_otp_keypad_3'),
        SecretRedactor.redacted,
      );
      expect(
        SecretRedactor.redactIdentifier('phone_otp_keypad_7'),
        SecretRedactor.redacted,
      );
    });

    test('interaction identifiers allow only audited exact literals', () {
      expect(
        SecretRedactor.redactInteractionIdentifier('client_home_retry_cta'),
        'client_home_retry_cta',
      );
      expect(
        SecretRedactor.redactInteractionIdentifier('shell_tab_dashboard'),
        'shell_tab_dashboard',
      );
      for (final dynamicId in <String>[
        'phone_otp_keypad_5',
        'review_rev-secret_report_cta',
        'jeeber_feed_request_offer_request-secret',
        'swordfish',
      ]) {
        expect(
          SecretRedactor.redactInteractionIdentifier(dynamicId),
          SecretRedactor.redacted,
          reason: dynamicId,
        );
      }
    });

    test(
      'every resolved static production identifier is classified',
      () async {
        final identifiers = await resolvedStaticInteractionIdentifiers();
        final buckets = <Set<String>>[
          kAuditedStaticInteractionIdentifiers,
          kAuditedStaticInteractionAliases.keys.toSet(),
          kExplicitlyRedactedStaticInteractionIdentifiers,
        ];
        final missing = identifiers.difference(
          buckets.expand((b) => b).toSet(),
        );
        if (missing.isNotEmpty) {
          fail(
            'Unclassified static interaction identifiers:\n'
            '${(missing.toList()..sort()).join('\n')}',
          );
        }
        for (final identifier in identifiers) {
          expect(
            buckets.where((bucket) => bucket.contains(identifier)),
            hasLength(1),
            reason: '$identifier must have exactly one classification',
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );

    test('static action registry never admits free-text controls', () {
      final rejectedByIdentifierFloor = <String>[];
      for (final identifier in kAuditedStaticInteractionIdentifiers) {
        final normalized = identifier.toLowerCase().replaceAll('-', '_');
        expect(
          _sensitiveControlMarkers.any(normalized.contains) ||
              _sensitiveControlSuffixes.any(normalized.endsWith),
          isFalse,
          reason: identifier,
        );
        if (SecretRedactor.redactIdentifier(identifier) != identifier) {
          rejectedByIdentifierFloor.add(identifier);
        }
      }
      expect(rejectedByIdentifierFloor, isEmpty);
      for (final entry in kAuditedStaticInteractionAliases.entries) {
        expect(entry.key, isNot(entry.value));
        expect(
          SecretRedactor.redactIdentifier(entry.value),
          entry.value,
          reason: entry.key,
        );
      }
      final capturedIdentifiers = <String>{
        ...kAuditedStaticInteractionIdentifiers,
        ...kAuditedStaticInteractionAliases.values,
      };
      expect(
        capturedIdentifiers,
        hasLength(
          kAuditedStaticInteractionIdentifiers.length +
              kAuditedStaticInteractionAliases.length,
        ),
        reason: 'static actions must not collapse onto the same captured ID',
      );
      for (final identifier
          in kExplicitlyRedactedStaticInteractionIdentifiers) {
        expect(
          SecretRedactor.redactInteractionIdentifier(identifier),
          SecretRedactor.redacted,
          reason: identifier,
        );
      }
    });

    test('profile actions stay distinct without retaining sensitive names', () {
      const sourceIds = <String>[
        'customer_profile_password_row',
        'customer_profile_notifications_row',
        'customer_profile_language_row',
        'customer_profile_addresses_row',
        'customer_profile_contact_row',
        'customer_profile_rate_app_row',
        'customer_profile_logout_row',
      ];
      final captured = sourceIds
          .map(SecretRedactor.redactInteractionIdentifier)
          .toList();

      expect(captured, isNot(contains(SecretRedactor.redacted)));
      expect(captured.toSet(), hasLength(sourceIds.length));
      expect(captured, contains('customer_profile_security_row'));
      expect(captured, contains('customer_profile_saved_places_row'));
      expect(captured.join(' '), isNot(contains('password')));
      expect(captured.join(' '), isNot(contains('address')));
    });

    test(
      'same-screen request, verification, and security actions stay distinct',
      () {
        const actionGroups = <List<String>>[
          <String>[
            'request_summary_change_route',
            'request_summary_change_tier',
            'request_summary_submit',
          ],
          <String>[
            'phone_otp_back_cta',
            'phone_otp_change_phone_cta',
            'phone_otp_resend_cta',
            'phone_otp_verify_cta',
          ],
          <String>[
            'password_back',
            'password_confirm_visibility_toggle',
            'password_new_visibility_toggle',
            'password_submit_cta',
          ],
        ];
        for (final sourceIds in actionGroups) {
          final captured = sourceIds
              .map(SecretRedactor.redactInteractionIdentifier)
              .toList();
          expect(captured, isNot(contains(SecretRedactor.redacted)));
          expect(captured.toSet(), hasLength(sourceIds.length));
        }
      },
    );

    test('conversation and place actions stay useful through safe aliases', () {
      const sourceIds = <String>[
        'order_chat_quick_reply_door',
        'order_chat_quick_reply_home',
        'order_chat_quick_reply_thanks',
        'capture_location_back',
        'capture_location_pin_cta',
        'capture_location_zoom_in',
        'capture_location_zoom_out',
      ];
      final captured = sourceIds
          .map(SecretRedactor.redactInteractionIdentifier)
          .toList();

      expect(captured, isNot(contains(SecretRedactor.redacted)));
      expect(captured.toSet(), hasLength(sourceIds.length));
      expect(captured.join(' '), isNot(contains('chat')));
      expect(captured.join(' '), isNot(contains('location')));
      expect(captured.join(' '), isNot(contains('gps')));
    });
  });

  group('redactPath', () {
    test('retains safe named routes for screen events', () {
      expect(SecretRedactor.redactRoute('shell'), 'shell');
      final out =
          SecretRedactor.redactBody(<String, Object?>{
                'route': 'shell',
                'screen': 'shell',
                'prev': 'login',
              })!
              as Map<String, Object?>;

      expect(out, <String, Object?>{
        'route': 'shell',
        'screen': 'shell',
        'prev': 'login',
      });
    });

    test('named routes stay default-deny and paths remain slash-only', () {
      final out =
          SecretRedactor.redactBody(<String, Object?>{
                'route': 'Karim profile',
                'screen': 'otp_482913',
                'path': 'orders',
                'deeplink': 'delivery',
              })!
              as Map<String, Object?>;

      expect(out.values, everyElement(SecretRedactor.redacted));
    });

    test('retains stable paths and rejects OTP-shaped path segments', () {
      expect(SecretRedactor.redactPath('/orders/d-1'), '/orders/d-1');
      expect(
        SecretRedactor.redactPath('/recover/482913'),
        SecretRedactor.redacted,
      );
    });

    test('network paths retain only audited endpoint/template segments', () {
      expect(
        SecretRedactor.redactNetworkPath(
          '/v1/requests/alice-passport/ABCD-EFGH?token=raw#private',
        ),
        '/v1/requests/:value/:value',
      );
      expect(
        SecretRedactor.redactNetworkPath('/v1/requests/:id/offers'),
        '/v1/requests/:id/offers',
      );
    });

    test('off-origin absolute network URLs collapse to one fixed sentinel', () {
      expect(
        SecretRedactor.redactNetworkPath(
          'https://signed.cdn.test/alice-passport/ABCD-EFGH'
          '?signature=test-placeholder#private',
          baseUrl: 'https://gateway.test/v1',
        ),
        SecretRedactor.externalUploadPath,
      );
      expect(
        SecretRedactor.redactNetworkPath(
          'https://gateway.test/v1/requests/alice-passport',
          baseUrl: 'https://gateway.test/api',
        ),
        '/v1/requests/:value',
      );
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

  group(
    'SECURITY GATE: no secret survives verbatim across the whole shape',
    () {
      Map<String, Object?> buildLeakyPayload() => <String, Object?>{
        'headers': <String, Object?>{'Authorization': 'Bearer $_fakeJwt'},
        'body': <String, Object?>{
          'password': 'p@ssW0rd-super-secret',
          'otp': '048213',
          'fcmToken': 'test-fcm-token-not-real',
          'nested': <String, Object?>{'apiKey': 'test-key-not-real'},
          'roster': <Object?>[
            <String, Object?>{'passcode': 'HANDOVER-0001'},
          ],
          'freeText': 'auth via Bearer $_fakeJwt failed',
        },
      };

      test('holds without any runtime redaction mode', () {
        final leaky = buildLeakyPayload();
        final redactedHeaders = SecretRedactor.redactHeaders(
          leaky['headers']! as Map<String, Object?>,
        );
        final redactedBody = SecretRedactor.redactBody(leaky['body']);
        final serialized =
            jsonEncode(redactedHeaders) + jsonEncode(redactedBody);

        expect(serialized, isNot(contains(_fakeJwt)));
        expect(serialized, isNot(contains('p@ssW0rd-super-secret')));
        expect(serialized, isNot(contains('048213')));
        expect(serialized, isNot(contains('fcm-abcdef1234567890XYZ')));
        expect(serialized, isNot(contains('test-key-not-real')));
        expect(serialized, isNot(contains('HANDOVER-0001')));
        expect(
          _secretPattern.hasMatch(serialized),
          isFalse,
          reason: 'no Bearer/JWT pattern may ever survive:\n$serialized',
        );
      });
    },
  );
}
