import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/auth/social/social_auth_cubit.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_error.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_service.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_state.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_token.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_token_store.dart';
import 'package:jeeb_mobile/features/auth/social/social_provider.dart';

class _MockService extends Mock implements SocialAuthService {}

class _FakeTokenStore implements SocialAuthTokenStore {
  SocialAuthSession? saved;
  int saveCalls = 0;
  int clearCalls = 0;

  @override
  Future<void> save(SocialAuthSession session) async {
    saveCalls++;
    saved = session;
  }

  @override
  Future<SocialAuthSession?> read() async => saved;

  @override
  Future<void> clear() async {
    clearCalls++;
    saved = null;
  }
}

SocialAuthSession _session({String userId = 'user-1', bool recently = false}) =>
    SocialAuthSession(
      userId: userId,
      authToken: 'auth.$userId',
      refreshToken: 'refresh.$userId',
      recentlyCreated: recently,
    );

void main() {
  late _MockService service;
  late _FakeTokenStore store;

  setUp(() {
    service = _MockService();
    store = _FakeTokenStore();
  });

  SocialAuthCubit build() =>
      SocialAuthCubit(service: service, tokenStore: store);

  group('signInWith', () {
    blocTest<SocialAuthCubit, SocialAuthState>(
      'Google success persists session and emits authenticated',
      build: build,
      setUp: () {
        when(() => service.signIn(SocialProvider.google)).thenAnswer(
          (_) async => SocialAuthSuccess(_session(recently: true)),
        );
      },
      act: (c) => c.signInWith(SocialProvider.google),
      expect: () => [
        predicate<SocialAuthState>(
          (s) =>
              s.status == SocialAuthStatus.inProgress &&
              s.activeProvider == SocialProvider.google,
        ),
        predicate<SocialAuthState>(
          (s) =>
              s.status == SocialAuthStatus.authenticated &&
              s.activeProvider == SocialProvider.google &&
              s.session?.userId == 'user-1' &&
              s.session?.recentlyCreated == true,
        ),
      ],
      verify: (_) {
        expect(store.saveCalls, 1);
        expect(store.saved?.userId, 'user-1');
      },
    );

    blocTest<SocialAuthCubit, SocialAuthState>(
      'Apple success persists session',
      build: build,
      setUp: () {
        when(() => service.signIn(SocialProvider.apple)).thenAnswer(
          (_) async => SocialAuthSuccess(_session(userId: 'apple-1')),
        );
      },
      act: (c) => c.signInWith(SocialProvider.apple),
      skip: 1,
      expect: () => [
        predicate<SocialAuthState>(
          (s) =>
              s.status == SocialAuthStatus.authenticated &&
              s.activeProvider == SocialProvider.apple &&
              s.session?.userId == 'apple-1',
        ),
      ],
      verify: (_) {
        expect(store.saved?.userId, 'apple-1');
      },
    );

    blocTest<SocialAuthCubit, SocialAuthState>(
      'cancellation drops back to idle without an error',
      build: build,
      setUp: () {
        when(() => service.signIn(SocialProvider.google)).thenAnswer(
          (_) async => const SocialAuthFailure(SocialAuthError.cancelled),
        );
      },
      act: (c) => c.signInWith(SocialProvider.google),
      skip: 1,
      expect: () => [
        predicate<SocialAuthState>(
          (s) =>
              s.status == SocialAuthStatus.idle &&
              s.error == null &&
              s.session == null,
        ),
      ],
      verify: (_) {
        expect(store.saveCalls, 0);
      },
    );

    blocTest<SocialAuthCubit, SocialAuthState>(
      'network failure surfaces a failed state',
      build: build,
      setUp: () {
        when(() => service.signIn(SocialProvider.google)).thenAnswer(
          (_) async => const SocialAuthFailure(SocialAuthError.network),
        );
      },
      act: (c) => c.signInWith(SocialProvider.google),
      skip: 1,
      expect: () => [
        predicate<SocialAuthState>(
          (s) =>
              s.status == SocialAuthStatus.failed &&
              s.error == SocialAuthError.network &&
              s.activeProvider == SocialProvider.google,
        ),
      ],
      verify: (_) {
        expect(store.saveCalls, 0);
      },
    );

    blocTest<SocialAuthCubit, SocialAuthState>(
      'invalidToken failure surfaces the matching error code',
      build: build,
      setUp: () {
        when(() => service.signIn(SocialProvider.apple)).thenAnswer(
          (_) async => const SocialAuthFailure(SocialAuthError.invalidToken),
        );
      },
      act: (c) => c.signInWith(SocialProvider.apple),
      skip: 1,
      expect: () => [
        predicate<SocialAuthState>(
          (s) =>
              s.status == SocialAuthStatus.failed &&
              s.error == SocialAuthError.invalidToken &&
              s.activeProvider == SocialProvider.apple,
        ),
      ],
    );

    blocTest<SocialAuthCubit, SocialAuthState>(
      'D22: a 409 collision emits the collision state and does NOT persist',
      build: build,
      setUp: () {
        when(() => service.signIn(SocialProvider.google)).thenAnswer(
          (_) async => const SocialAuthFailure(SocialAuthError.collision),
        );
      },
      act: (c) => c.signInWith(SocialProvider.google),
      skip: 1,
      expect: () => [
        predicate<SocialAuthState>(
          (s) =>
              s.status == SocialAuthStatus.collision &&
              s.isCollision &&
              s.error == SocialAuthError.collision &&
              s.activeProvider == SocialProvider.google,
        ),
      ],
      verify: (_) {
        // Identity linking is user-management's (GR-2); the client never
        expect(store.saveCalls, 0);
      },
    );

    test('ignores a second tap while a sign-in is in flight', () async {
      final completer = Completer<SocialAuthResult>();
      when(() => service.signIn(SocialProvider.google))
          .thenAnswer((_) => completer.future);

      final cubit = build();
      // Fire-and-forget first call; it stays in flight until we complete.
      final first = cubit.signInWith(SocialProvider.google);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, SocialAuthStatus.inProgress);

      await cubit.signInWith(SocialProvider.apple);
      // No state change beyond the initial inProgress for Google.
      expect(cubit.state.activeProvider, SocialProvider.google);
      verifyNever(() => service.signIn(SocialProvider.apple));

      completer.complete(SocialAuthSuccess(_session()));
      await first;
      expect(cubit.state.status, SocialAuthStatus.authenticated);

      await cubit.close();
    });
  });

  group('clearError', () {
    blocTest<SocialAuthCubit, SocialAuthState>(
      'wipes a failed state back to idle',
      build: build,
      seed: () => const SocialAuthState(
        status: SocialAuthStatus.failed,
        activeProvider: SocialProvider.google,
        error: SocialAuthError.network,
      ),
      act: (c) => c.clearError(),
      expect: () => [
        predicate<SocialAuthState>(
          (s) => s.status == SocialAuthStatus.idle && s.error == null,
        ),
      ],
    );

    blocTest<SocialAuthCubit, SocialAuthState>(
      'is a no-op when the state is not failed',
      build: build,
      seed: () => const SocialAuthState(status: SocialAuthStatus.idle),
      act: (c) => c.clearError(),
      expect: () => const <SocialAuthState>[],
    );
  });

  group('acknowledgeCollision', () {
    blocTest<SocialAuthCubit, SocialAuthState>(
      'resets a collision state back to idle so the buttons re-arm',
      build: build,
      seed: () => const SocialAuthState(
        status: SocialAuthStatus.collision,
        activeProvider: SocialProvider.google,
        error: SocialAuthError.collision,
      ),
      act: (c) => c.acknowledgeCollision(),
      expect: () => [
        predicate<SocialAuthState>(
          (s) =>
              s.status == SocialAuthStatus.idle &&
              s.error == null &&
              !s.isCollision,
        ),
      ],
    );

    blocTest<SocialAuthCubit, SocialAuthState>(
      'is a no-op when the state is not a collision',
      build: build,
      seed: () => const SocialAuthState(status: SocialAuthStatus.idle),
      act: (c) => c.acknowledgeCollision(),
      expect: () => const <SocialAuthState>[],
    );
  });
}
