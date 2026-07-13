import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_cubit.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_error.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_service.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_state.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_token.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_token_store.dart';
import 'package:jeeb_mobile/features/auth/social/social_provider.dart';
import 'package:jeeb_mobile/features/auth/social/social_sign_in_section.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

/// Service that always reports the gateway's 409 `email_collision` (D22) for
/// Google so we can drive the block-second-method sheet deterministically.
class _CollisionService implements SocialAuthService {
  @override
  Future<SocialAuthResult> signIn(SocialProvider provider) async =>
      const SocialAuthFailure(SocialAuthError.collision);

  @override
  Future<void> signOut() async {}
}

class _NoopTokenStore implements SocialAuthTokenStore {
  @override
  Future<void> save(SocialAuthSession session) async {}

  @override
  Future<SocialAuthSession?> read() async => null;

  @override
  Future<void> clear() async {}
}

Widget _host(SocialAuthCubit cubit, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: BlocProvider<SocialAuthCubit>.value(
        value: cubit,
        child: const SocialSignInSection(),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'D22: tapping Google on a 409 collision shows the block sheet, then '
    'dismissing it resets the cubit to idle',
    (tester) async {
      final cubit = SocialAuthCubit(
        service: _CollisionService(),
        tokenStore: _NoopTokenStore(),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('registration.googleSignIn')));
      await tester.pumpAndSettle();

      // The sheet is presented and the cubit is in the collision state.
      expect(find.text('You already have an account'), findsOneWidget);
      expect(
        find.byKey(const Key('registration.socialCollisionDismiss')),
        findsOneWidget,
      );
      expect(cubit.state.status, SocialAuthStatus.collision);

      // Dismissing acknowledges the collision so the buttons re-arm.
      await tester
          .tap(find.byKey(const Key('registration.socialCollisionDismiss')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('registration.socialCollisionDismiss')),
        findsNothing,
      );
      expect(cubit.state.status, SocialAuthStatus.idle);
      expect(cubit.state.isCollision, isFalse);
    },
  );

  testWidgets('D22 collision sheet renders the Arabic copy under an ar locale',
      (tester) async {
    final cubit = SocialAuthCubit(
      service: _CollisionService(),
      tokenStore: _NoopTokenStore(),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(_host(cubit, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('registration.googleSignIn')));
    await tester.pumpAndSettle();

    expect(find.text('لديك حساب بالفعل'), findsOneWidget);
  });
}
