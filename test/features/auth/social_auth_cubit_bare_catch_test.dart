// AUTH-01 (P0): `signIn` was awaited with no guard, so a TypeError out of the
// service left BOTH provider buttons pinned on `inProgress` forever.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/auth/social/social_auth_cubit.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_error.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_service.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_state.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_token.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_token_store.dart';
import 'package:jeeb_mobile/features/auth/social/social_provider.dart';

class _ThrowingService implements SocialAuthService {
  const _ThrowingService(this.error);

  final Object error;

  @override
  Future<SocialAuthResult> signIn(SocialProvider provider) async =>
      throw error;

  @override
  Future<void> signOut() async {}
}

class _SucceedingService implements SocialAuthService {
  const _SucceedingService();

  @override
  Future<SocialAuthResult> signIn(SocialProvider provider) async =>
      const SocialAuthSuccess(
        SocialAuthSession(
          userId: 'u-1',
          authToken: 'a',
          refreshToken: 'r',
          recentlyCreated: false,
        ),
      );

  @override
  Future<void> signOut() async {}
}

class _InertStore implements SocialAuthTokenStore {
  const _InertStore();

  @override
  Future<void> save(SocialAuthSession session) async {}

  @override
  Future<SocialAuthSession?> read() async => null;

  @override
  Future<void> clear() async {}
}

class _ThrowingStore implements SocialAuthTokenStore {
  const _ThrowingStore();

  @override
  Future<void> save(SocialAuthSession session) async =>
      throw StateError('keystore unavailable');

  @override
  Future<SocialAuthSession?> read() async => null;

  @override
  Future<void> clear() async {}
}

void main() {
  test('a TypeError out of the service lands on failed, not inProgress',
      () async {
    final SocialAuthCubit cubit = SocialAuthCubit(
      service: _ThrowingService(TypeError()),
      tokenStore: const _InertStore(),
    );

    await cubit.signInWith(SocialProvider.google);

    expect(cubit.state.status, SocialAuthStatus.failed);
    expect(cubit.state.status, isNot(SocialAuthStatus.inProgress));
    expect(cubit.state.error, SocialAuthError.unknown);
    expect(cubit.state.isBusy, isFalse);
    await cubit.close();
  });

  test('both buttons re-enable after the throw', () async {
    final SocialAuthCubit cubit = SocialAuthCubit(
      service: const _ThrowingService(FormatException('bad json')),
      tokenStore: const _InertStore(),
    );

    await cubit.signInWith(SocialProvider.apple);

    expect(cubit.state.isBusyFor(SocialProvider.apple), isFalse);
    expect(cubit.state.isBusyFor(SocialProvider.google), isFalse);
    await cubit.close();
  });

  test('a second attempt is possible after the failure', () async {
    final SocialAuthCubit cubit = SocialAuthCubit(
      service: _ThrowingService(StateError('boom')),
      tokenStore: const _InertStore(),
    );

    await cubit.signInWith(SocialProvider.google);
    expect(cubit.state.status, SocialAuthStatus.failed);
    await cubit.signInWith(SocialProvider.google);
    expect(cubit.state.status, SocialAuthStatus.failed);
    await cubit.close();
  });

  test('a throwing token store also lands on failed, never authenticated',
      () async {
    final SocialAuthCubit cubit = SocialAuthCubit(
      service: const _SucceedingService(),
      tokenStore: const _ThrowingStore(),
    );

    await cubit.signInWith(SocialProvider.google);

    expect(cubit.state.status, SocialAuthStatus.failed);
    expect(cubit.state.status, isNot(SocialAuthStatus.authenticated));
    expect(cubit.state.session, isNull);
    await cubit.close();
  });
}
