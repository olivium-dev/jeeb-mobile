// Cancellation route-resolution gate (FIX-CANCEL-P0, cycle-6).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/router/app_router.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';
import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/cancellation/domain/cancellation_repository.dart';
import 'package:jeeb_mobile/features/cancellation/domain/cancellation_result.dart';
import 'package:jeeb_mobile/features/cancellation/presentation/cancellation_screen.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Inert repo so the screen mounts without hitting a gateway.
class _FakeCancellationRepository implements CancellationRepository {
  @override
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) async {
    return const CancellationResult(
      deliveryId: 'ord_1',
      weeklyCount: 0,
    );
  }
}

typedef _Built = ({
  GoRouter router,
  OnboardingCubit onboarding,
  BiometricLockCubit lock,
  RoleCubit role,
  RoleEligibilityCubit roleEligibility,
  LocaleCubit locale,
});

Future<_Built> _buildRouter() async {
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

  final router = AppRouter.create(
    onboarding: onboarding,
    biometricLock: lock,
    session: const AlwaysAuthenticatedSessionGate(),
  );
  return (
    router: router,
    onboarding: onboarding,
    lock: lock,
    role: role,
    roleEligibility: roleEligibility,
    locale: locale,
  );
}

Widget _harness(_Built built) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<BiometricLockCubit>.value(value: built.lock),
      BlocProvider<RoleCubit>.value(value: built.role),
      BlocProvider<RoleEligibilityCubit>.value(value: built.roleEligibility),
      BlocProvider<LocaleCubit>.value(value: built.locale),
    ],
    child: MaterialApp.router(
      routerConfig: built.router,
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
  late _Built built;

  setUp(() {
    // Production registers DioCancellationRepository in GetIt; register an inert
    if (!sl.isRegistered<CancellationRepository>()) {
      sl.registerLazySingleton<CancellationRepository>(
        _FakeCancellationRepository.new,
      );
    }
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  Future<void> pump(WidgetTester tester) async {
    built = await _buildRouter();
    addTearDown(() {
      built.lock.close();
      built.role.close();
      built.roleEligibility.close();
      built.locale.close();
      built.onboarding.close();
      built.router.dispose();
    });
    await tester.pumpWidget(_harness(built));
    await tester.pumpAndSettle();
  }

  String location() =>
      built.router.routerDelegate.currentConfiguration.uri.toString();

  group('cancellation route resolves (regression: P0-CANCEL-CRASH)', () {
    testWidgets('/orders/:id/cancel → CancellationScreen without throwing',
        (tester) async {
      await pump(tester);
      built.router.goNamed(
        'delivery-cancel',
        pathParameters: const <String, String>{'id': 'ord_1'},
      );
      await tester.pumpAndSettle();
      expect(location(), '/orders/ord_1/cancel');
      expect(find.byType(CancellationScreen), findsOneWidget);
      // The pre-fix crash surfaced here as a ProviderNotFoundException.
      expect(tester.takeException(), isNull);
    });

    testWidgets('jeeber cancel variant also opens', (tester) async {
      await pump(tester);
      built.router.goNamed(
        'delivery-cancel',
        pathParameters: const <String, String>{'id': 'ord_2'},
        queryParameters: const <String, String>{'role': 'jeeber'},
      );
      await tester.pumpAndSettle();
      expect(find.byType(CancellationScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
