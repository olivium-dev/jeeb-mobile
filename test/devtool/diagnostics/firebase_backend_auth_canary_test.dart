import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/devtool/diagnostics/firebase_backend_auth_canary.dart';

const _uid = 'd1000000-0000-4000-8000-000000000001';
final _now = DateTime.utc(2026, 9, 14, 12);

String _segment(Map<String, Object?> value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

String _token({
  required String projectId,
  String uid = _uid,
  String? audience,
  String? issuer,
  String provider = 'custom',
}) {
  final nowSeconds = _now.millisecondsSinceEpoch ~/ 1000;
  return '${_segment(<String, Object?>{'alg': 'RS256', 'kid': 'fixture-key-id'})}.${_segment(<String, Object?>{
    'aud': audience ?? projectId,
    'iss': issuer ?? 'https://securetoken.google.com/$projectId',
    'sub': uid,
    'iat': nowSeconds - 10,
    'exp': nowSeconds + 3500,
    'firebase': <String, Object?>{'sign_in_provider': provider},
  })}.${base64Url.encode(<int>[1, 2, 3]).replaceAll('=', '')}';
}

class _RecordedPost {
  const _RecordedPost(this.route, this.payload);

  final Uri route;
  final Map<String, Object?> payload;
}

class _Probe {
  _Probe(this.statuses);

  final List<FirebaseCanaryHttpResult> statuses;
  final List<_RecordedPost> calls = <_RecordedPost>[];

  Future<FirebaseCanaryHttpResult> post(
    Uri route,
    Map<String, Object?> payload,
  ) async {
    calls.add(_RecordedPost(route, Map<String, Object?>.of(payload)));
    return statuses[calls.length - 1];
  }
}

FirebaseCanaryHttpResult _verified(
  String projectId, {
  String provider = 'custom',
  String uid = _uid,
}) => FirebaseCanaryHttpResult(
  status: 200,
  verified: true,
  projectId: projectId,
  provider: provider,
  subjectSha256: sha256.convert(utf8.encode(uid)).toString(),
);

FirebaseBackendAuthCanary _canary({
  required FirebaseCanaryIdentity identity,
  required _Probe probe,
  required String appFlavor,
  bool enabled = true,
}) => FirebaseBackendAuthCanary(
  enabled: enabled,
  appFlavor: appFlavor,
  now: () => _now,
  loadIdentity: () async => identity,
  post: probe.post,
);

void main() {
  test(
    'staging sends an in-memory token and a corrupted-signature control',
    () async {
      const projectId = 'jeeb-5a293';
      final token = _token(projectId: projectId);
      final probe = _Probe(<FirebaseCanaryHttpResult>[
        _verified(projectId),
        const FirebaseCanaryHttpResult(status: 401),
      ]);
      final result = await _canary(
        identity: FirebaseCanaryIdentity(
          uid: _uid,
          token: token,
          projectId: projectId,
        ),
        probe: probe,
        appFlavor: 'staging',
      ).run();

      expect(result.passed, isTrue);
      expect(result.reason, 'firebase_backend_token_verification_pass');
      expect(result.environment, 'staging');
      expect(result.projectId, projectId);
      expect(
        result.route,
        'https://app.jeeb.fds-1.com/v1/auth/diagnostics/firebase-token',
      );
      expect(result.provider, 'custom');
      expect(result.validTokenStatus, 200);
      expect(result.invalidSignatureStatus, 401);
      expect(
        result.userSha256Prefix,
        sha256.convert(utf8.encode(_uid)).toString().substring(0, 16),
      );
      expect(
        result.tokenSha256Prefix,
        sha256.convert(utf8.encode(token)).toString().substring(0, 16),
      );

      expect(probe.calls, hasLength(2));
      expect(
        probe.calls.map((call) => call.route.toString()),
        everyElement(
          'https://app.jeeb.fds-1.com/v1/auth/diagnostics/firebase-token',
        ),
      );
      final valid = probe.calls[0].payload;
      final invalid = probe.calls[1].payload;
      expect(valid.keys, <String>{
        'idToken',
        'expectedProjectId',
        'expectedSubject',
      });
      expect(valid['idToken'], token);
      expect(valid['expectedProjectId'], projectId);
      expect(valid['expectedSubject'], _uid);
      expect(invalid['expectedProjectId'], valid['expectedProjectId']);
      expect(invalid['expectedSubject'], valid['expectedSubject']);
      expect(invalid['idToken'], isNot(token));
      expect(
        (invalid['idToken']! as String).split('.').take(2),
        token.split('.').take(2),
      );

      final safeEvidence = jsonEncode(<String, Object?>{
        'environment': result.environment,
        'projectId': result.projectId,
        'route': result.route,
        'provider': result.provider,
        'validStatus': result.validTokenStatus,
        'invalidStatus': result.invalidSignatureStatus,
        'userHash': result.userSha256Prefix,
        'tokenHash': result.tokenSha256Prefix,
        'reason': result.reason,
      });
      expect(safeEvidence, isNot(contains(token)));
      expect(safeEvidence, isNot(contains(_uid)));
    },
  );

  test('development is pinned to the MSI verifier route', () async {
    const projectId = 'jeeb-development-msi';
    final token = _token(projectId: projectId, provider: 'google.com');
    final probe = _Probe(<FirebaseCanaryHttpResult>[
      _verified(projectId, provider: 'google.com'),
      const FirebaseCanaryHttpResult(status: 401),
    ]);
    final result = await _canary(
      identity: FirebaseCanaryIdentity(
        uid: _uid,
        token: token,
        projectId: projectId,
      ),
      probe: probe,
      appFlavor: 'dev',
    ).run();

    expect(result.passed, isTrue);
    expect(result.environment, 'development');
    expect(
      result.route,
      'https://msi.olivium.space/gateway/v1/auth/diagnostics/firebase-token',
    );
    expect(result.provider, 'google.com');
  });

  test('build and Firebase target mismatch fails before any request', () async {
    const projectId = 'jeeb-development-msi';
    final probe = _Probe(<FirebaseCanaryHttpResult>[]);
    final result = await _canary(
      identity: FirebaseCanaryIdentity(
        uid: _uid,
        token: _token(projectId: projectId),
        projectId: projectId,
      ),
      probe: probe,
      appFlavor: 'staging',
    ).run();

    expect(result.passed, isFalse);
    expect(result.reason, 'build_firebase_target_mismatch');
    expect(probe.calls, isEmpty);
  });

  test(
    'issuer, audience, and subject must match the target and user',
    () async {
      const projectId = 'jeeb-5a293';
      for (final mismatch in <String, String>{
        'firebase_issuer_mismatch': _token(
          projectId: projectId,
          issuer: 'https://securetoken.google.com/another-project',
        ),
        'firebase_audience_mismatch': _token(
          projectId: projectId,
          audience: 'another-project',
        ),
        'firebase_subject_mismatch': _token(
          projectId: projectId,
          uid: 'another-user',
        ),
      }.entries) {
        final probe = _Probe(<FirebaseCanaryHttpResult>[]);
        final result = await _canary(
          identity: FirebaseCanaryIdentity(
            uid: _uid,
            token: mismatch.value,
            projectId: projectId,
          ),
          probe: probe,
          appFlavor: 'staging',
        ).run();

        expect(result.reason, mismatch.key);
        expect(probe.calls, isEmpty);
      }
    },
  );

  test(
    'the valid request must pass and the corrupted signature must fail',
    () async {
      const projectId = 'jeeb-5a293';
      final identity = FirebaseCanaryIdentity(
        uid: _uid,
        token: _token(projectId: projectId),
        projectId: projectId,
      );

      final rejectedValid = await _canary(
        identity: identity,
        probe: _Probe(<FirebaseCanaryHttpResult>[
          const FirebaseCanaryHttpResult(status: 502),
          const FirebaseCanaryHttpResult(status: 401),
        ]),
        appFlavor: 'staging',
      ).run();
      expect(rejectedValid.passed, isFalse);
      expect(rejectedValid.reason, 'valid_token_rejected');

      final acceptedInvalid = await _canary(
        identity: identity,
        probe: _Probe(<FirebaseCanaryHttpResult>[
          _verified(projectId),
          const FirebaseCanaryHttpResult(status: 200),
        ]),
        appFlavor: 'staging',
      ).run();
      expect(acceptedInvalid.passed, isFalse);
      expect(acceptedInvalid.reason, 'invalid_signature_accepted');
    },
  );

  test('safe verifier evidence must match the local signed claims', () async {
    const projectId = 'jeeb-5a293';
    final result = await _canary(
      identity: FirebaseCanaryIdentity(
        uid: _uid,
        token: _token(projectId: projectId),
        projectId: projectId,
      ),
      probe: _Probe(<FirebaseCanaryHttpResult>[
        const FirebaseCanaryHttpResult(
          status: 200,
          verified: true,
          projectId: projectId,
          provider: 'custom',
          subjectSha256: '0000000000000000',
        ),
        const FirebaseCanaryHttpResult(status: 401),
      ]),
      appFlavor: 'staging',
    ).run();

    expect(result.passed, isFalse);
    expect(result.reason, 'valid_verifier_evidence_mismatch');
  });

  test('the compile-time gate fails closed before identity access', () async {
    var identityReads = 0;
    final probe = _Probe(<FirebaseCanaryHttpResult>[]);
    final canary = FirebaseBackendAuthCanary(
      enabled: false,
      appFlavor: 'staging',
      loadIdentity: () async {
        identityReads += 1;
        return null;
      },
      post: probe.post,
    );

    final result = await canary.run();

    expect(result.reason, 'dev_tool_disabled');
    expect(identityReads, 0);
    expect(probe.calls, isEmpty);
  });

  test(
    'source keeps bearer material out of logs, persistence, and shared Dio',
    () {
      final source = File(
        'lib/devtool/diagnostics/firebase_backend_auth_canary.dart',
      ).readAsStringSync();

      expect(source, contains('bool enabled = kDevToolEnabled'));
      expect(source, contains('ResponseType.stream'));
      expect(source, contains('stream.drain<void>()'));
      expect(source, isNot(contains('debugPrint')));
      expect(source, isNot(contains('Diag.')));
      expect(source, isNot(contains('CrashReporter')));
      expect(source, isNot(contains('SharedPreferences')));
      expect(source, isNot(contains("import 'dart:io'")));
      expect(source, isNot(contains('sl<Dio>')));
    },
  );

  test('no product source outside lib/devtool imports the canary', () {
    final importers = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) => file.readAsStringSync().contains(
            'firebase_backend_auth_canary.dart',
          ),
        )
        .map((file) => file.path.replaceAll('\\', '/'))
        .toList();

    expect(importers, <String>[
      'lib/devtool/diagnostics/chat_push_diagnostics_page.dart',
    ]);
  });
}
