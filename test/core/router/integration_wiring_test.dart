// Integration wiring tests (INTEGRATION-3).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/deep_link_targets/rating_prompt_screen.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/features/rating/presentation/mutual_rating_screen.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/features/transcription/domain/voice_clip.dart';
import 'package:jeeb_mobile/features/transcription/presentation/transcription_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _FakeRatingRepo implements RatingRepository {
  const _FakeRatingRepo();

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {}

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async {
    return RatingStatus(
      deliveryId: deliveryId,
      revealState: RatingRevealState.pendingTheirs,
    );
  }
}

Future<({
  GoRouter router,
  RoleCubit role,
  RoleEligibilityCubit roleEligibility,
  LocaleCubit locale,
})> _buildRouter() async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'app.onboarding.completed': true,
  });
  final prefs = await SharedPreferences.getInstance();

  final onboarding = OnboardingCubit(prefs: prefs);
  final lock = BiometricLockCubit(
    preference: BiometricPreferenceRepositoryImpl(prefs: prefs),
    gateway: const UnavailableBiometricGateway(),
    pinRepository: SharedPrefsPinRepository(prefs: prefs),
  );
  final role = RoleCubit(prefs: prefs);
  final roleEligibility = RoleEligibilityCubit();
  final locale = LocaleCubit(prefs: prefs);

  final router = AppRouter.create(onboarding: onboarding, biometricLock: lock);
  return (
    router: router,
    role: role,
    roleEligibility: roleEligibility,
    locale: locale,
  );
}

Widget _harness(
  GoRouter router,
  RoleCubit role,
  RoleEligibilityCubit roleEligibility,
  LocaleCubit locale,
) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<RoleCubit>.value(value: role),
      BlocProvider<RoleEligibilityCubit>.value(value: roleEligibility),
      BlocProvider<LocaleCubit>.value(value: locale),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  group('B-3 — /orders/:id/rate redirects to the real MutualRatingScreen', () {
    setUp(() async {
      await sl.reset();
      sl.registerLazySingleton<RatingRepository>(_FakeRatingRepo.new);
    });

    tearDown(() async {
      await sl.reset();
    });

    testWidgets(
      'navigating to /orders/D123/rate lands on MutualRatingScreen, '
      'not the RatingPromptScreen "coming soon" placeholder',
      (tester) async {
        final built = await _buildRouter();
        built.router.go('/orders/D123/rate');
        await tester.pumpWidget(
          _harness(built.router, built.role, built.roleEligibility, built.locale),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(MutualRatingScreen),
          findsOneWidget,
          reason: 'The rating-prompt route must redirect to the real blind '
              'mutual-rating screen (T-MOB-020).',
        );
        expect(
          find.byType(RatingPromptScreen),
          findsNothing,
          reason: 'The frozen "coming soon" placeholder must no longer render '
              'on the /orders/:id/rate path.',
        );
        expect(
          find.text('Rating Prompt coming soon'),
          findsNothing,
          reason: 'The placeholder copy must not be reachable via /rate.',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('A — transcription route honours the widened onSent transcript', () {
    testWidgets(
      'a VoiceClip carrying a transcript lands the transcription screen on '
      'the happy path and shows that transcript',
      (tester) async {
        const transcript = 'كيلو بندورة من السوق';
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: <LocalizationsDelegate<dynamic>>[
              SyncAppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('ar'),
            home: TranscriptionScreen(
              clip: VoiceClip(
                audioPath: 'audio-1',
                durationMs: 0,
                transcript: transcript,
              ),
            ),
          ),
        );
        await tester.pump();

        // The screen reads clip.transcript and seeds it into the editable
        expect(
          find.text(transcript),
          findsOneWidget,
          reason: 'The transcription screen must display the forwarded '
              'transcript on the happy path.',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
