// Unit coverage for the FR-P0-3 SessionCubit token classifier.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/session/auth_loss_signals.dart';
import 'package:jeeb_mobile/core/session/session_cubit.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';
import 'package:jeeb_mobile/core/session/session_state.dart';

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

/// Builds a structurally-valid JWT (header.payload.signature) whose payload
/// carries the given `exp` (seconds since epoch). Signature is unverified — the
String _jwtWithExp(int expSeconds) {
  String seg(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final header = seg({'alg': 'HS256', 'typ': 'JWT'});
  final payload = seg({'sub': 'user-1', 'exp': expSeconds});
  return '$header.$payload.sig-not-verified';
}

void main() {
  late _MockAuthTokenStore store;

  setUp(() => store = _MockAuthTokenStore());

  SessionCubit build({DateTime Function()? clock}) =>
      SessionCubit(tokenStore: store, clock: clock);

  group('cold start (unknown phase)', () {
    test('starts in unknown and is INERT for the gate', () {
      final cubit = build();
      expect(cubit.state.status, SessionStatus.unknown);
      expect(cubit.state.isKnown, isFalse);
      // The router reads isUnauthenticated; unknown must NOT trigger a redirect.
      expect(cubit.isUnauthenticated, isFalse);
      addTearDown(cubit.close);
    });

    test('is a SessionGate', () {
      final cubit = build();
      expect(cubit, isA<SessionGate>());
      addTearDown(cubit.close);
    });
  });

  group('refresh classification', () {
    test('no token → unauthenticated', () async {
      when(() => store.accessToken).thenAnswer((_) async => null);
      final cubit = build();
      await cubit.refresh();
      expect(cubit.state.status, SessionStatus.unauthenticated);
      expect(cubit.isUnauthenticated, isTrue);
      addTearDown(cubit.close);
    });

    test('blank token → unauthenticated', () async {
      when(() => store.accessToken).thenAnswer((_) async => '   ');
      final cubit = build();
      await cubit.refresh();
      expect(cubit.state.status, SessionStatus.unauthenticated);
      addTearDown(cubit.close);
    });

    test('valid (future-exp) JWT → authenticated', () async {
      final future = DateTime.utc(2030, 1, 1);
      when(() => store.accessToken).thenAnswer(
        (_) async => _jwtWithExp(future.millisecondsSinceEpoch ~/ 1000),
      );
      final cubit = build(clock: () => DateTime.utc(2026, 6, 14));
      await cubit.refresh();
      expect(cubit.state.status, SessionStatus.authenticated);
      expect(cubit.state.isAuthenticated, isTrue);
      expect(cubit.isUnauthenticated, isFalse);
      addTearDown(cubit.close);
    });

    test('expired JWT → unauthenticated', () async {
      final past = DateTime.utc(2020, 1, 1);
      when(() => store.accessToken).thenAnswer(
        (_) async => _jwtWithExp(past.millisecondsSinceEpoch ~/ 1000),
      );
      final cubit = build(clock: () => DateTime.utc(2026, 6, 14));
      await cubit.refresh();
      expect(cubit.state.status, SessionStatus.unauthenticated);
      expect(cubit.isUnauthenticated, isTrue);
      addTearDown(cubit.close);
    });

    test('exp exactly now → unauthenticated (treated as expired)', () async {
      final now = DateTime.utc(2026, 6, 14);
      when(() => store.accessToken).thenAnswer(
        (_) async => _jwtWithExp(now.millisecondsSinceEpoch ~/ 1000),
      );
      final cubit = build(clock: () => now);
      await cubit.refresh();
      expect(cubit.state.status, SessionStatus.unauthenticated);
      addTearDown(cubit.close);
    });

    test(
      'non-JWT token → unauthenticated (malformed tokens fail closed)',
      () async {
        when(
          () => store.accessToken,
        ).thenAnswer((_) async => 'mock-jwt-access-super-user');
        final cubit = build();
        await cubit.refresh();
        expect(cubit.state.status, SessionStatus.unauthenticated);
        addTearDown(cubit.close);
      },
    );

    test('JWT-shaped token with non-numeric exp → unauthenticated', () async {
      final header = base64Url.encode(utf8.encode('{}')).replaceAll('=', '');
      final payload = base64Url
          .encode(utf8.encode('{"exp":"soon"}'))
          .replaceAll('=', '');
      when(
        () => store.accessToken,
      ).thenAnswer((_) async => '$header.$payload.sig');
      final cubit = build();
      await cubit.refresh();
      expect(cubit.state.status, SessionStatus.unauthenticated);
      addTearDown(cubit.close);
    });

    test('keystore read throws → unauthenticated (FAIL CLOSED)', () async {
      when(
        () => store.accessToken,
      ).thenThrow(Exception('keystore unavailable'));
      final cubit = build();
      await cubit.refresh();
      expect(
        cubit.state.status,
        SessionStatus.unauthenticated,
        reason: 'An unreadable token must force login, never silently admit.',
      );
      addTearDown(cubit.close);
    });
  });

  group('login/logout transitions drive the gate', () {
    test('refresh after a token appears flips to authenticated', () async {
      // First refresh: no token. Then a token is saved and we re-refresh.
      var token = await Future<String?>.value(null);
      when(() => store.accessToken).thenAnswer((_) async => token);
      final cubit = build();

      await cubit.refresh();
      expect(cubit.isUnauthenticated, isTrue);

      token = _jwtWithExp(DateTime.utc(2030).millisecondsSinceEpoch ~/ 1000);
      await cubit.refresh();
      expect(cubit.isUnauthenticated, isFalse);
      expect(cubit.state.isAuthenticated, isTrue);
      addTearDown(cubit.close);
    });

    test('terminal auth-loss signal flips the session immediately', () async {
      when(() => store.accessToken).thenAnswer(
        (_) async =>
            _jwtWithExp(DateTime.utc(2030).millisecondsSinceEpoch ~/ 1000),
      );
      final cubit = build();
      addTearDown(cubit.close);
      await cubit.refresh();
      expect(cubit.state.isAuthenticated, isTrue);

      AuthLossSignals.instance.signal();

      expect(cubit.state.status, SessionStatus.unauthenticated);
    });

    test('stale refresh cannot reopen a terminally lost session', () async {
      final pendingToken = Completer<String?>();
      when(() => store.accessToken).thenAnswer((_) => pendingToken.future);
      final cubit = build();
      addTearDown(cubit.close);

      final refresh = cubit.refresh();
      await Future<void>.delayed(Duration.zero);
      AuthLossSignals.instance.signal();
      pendingToken.complete(
        _jwtWithExp(DateTime.utc(2030).millisecondsSinceEpoch ~/ 1000),
      );
      await refresh;

      expect(cubit.state.status, SessionStatus.unauthenticated);
    });
  });

  group('AlwaysAuthenticatedSessionGate', () {
    test('is permanently authenticated (never redirects)', () {
      const gate = AlwaysAuthenticatedSessionGate();
      expect(gate.isUnauthenticated, isFalse);
    });
  });
}
