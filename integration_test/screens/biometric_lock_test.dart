// Isolated native UI test — BiometricLockScreen (biometric-unlock, JM-005, D23).
// The screen consumes an app-level BiometricLockCubit, so we provide a real one
// over the inert UnavailableBiometricGateway + a mock SharedPreferences. Building
// the screen never triggers a native biometric prompt (authenticate() only fires
// on the CTA tap), so the locked idle prompt is isolatable; pre-driving one failed
// attempt (the gateway resolves false, no OS dialog) yields the retry/fallback
// variant. Covers the idle prompt (en), the failed state (en), and Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/features/biometric_auth/application/biometric_lock_cubit.dart';
import 'package:jeeb_mobile/features/biometric_auth/data/shared_prefs_pin_repository.dart';
import 'package:jeeb_mobile/features/biometric_auth/domain/biometric_gateway.dart';
import 'package:jeeb_mobile/features/biometric_auth/presentation/biometric_lock_screen.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/biometric_preference_repository_impl.dart';

import '../support/screen_harness.dart';

/// A real BiometricLockCubit over inert seams — no keystore, no OS dialog. The
/// gateway reports unavailable so `authenticate()` resolves false (a failed
/// attempt) rather than opening a native prompt that can't be isolated.
Future<BiometricLockCubit> _cubit() async {
  final prefs = await SharedPreferences.getInstance();
  return BiometricLockCubit(
    preference: BiometricPreferenceRepositoryImpl(prefs: prefs),
    gateway: const UnavailableBiometricGateway(),
    pinRepository: SharedPrefsPinRepository(prefs: prefs),
  );
}

Widget _lock(BiometricLockCubit cubit) =>
    BlocProvider<BiometricLockCubit>.value(
      value: cubit,
      child: const BiometricLockScreen(),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('biometric-lock: locked idle prompt (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _lock(await _cubit()),
      'biometric-lock__idle',
    );
  });

  testWidgets('biometric-lock: failed attempt → retry + fallback (en)',
      (tester) async {
    final cubit = await _cubit();
    // UnavailableBiometricGateway.authenticate() resolves false → prompt=failed,
    // surfacing the retry label + failure hint without any native dialog.
    await cubit.authenticate();
    await pumpAndShoot(tester, binding, _lock(cubit), 'biometric-lock__failed');
  });

  testWidgets('biometric-lock: locked idle prompt (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _lock(await _cubit()),
      'biometric-lock__ar',
      locale: const Locale('ar'),
    );
  });
}
