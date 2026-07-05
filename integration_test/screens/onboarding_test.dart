// Isolated native UI test — OnboardingScreen (walkthrough, JM-010). The 3-slide
// intro carousel reads an OnboardingCubit + LocaleCubit, so we provide both over a
// mock SharedPreferences and inject `onComplete` so no GoRouter is needed. A
// PageView keeps only the centered slide visible, so we screenshot the first slide
// in English and Arabic (RTL) — enough given the page controls advance in-place.
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/onboarding/onboarding_cubit.dart';
import 'package:jeeb_mobile/features/onboarding/presentation/onboarding_screen.dart';

import '../support/screen_harness.dart';

Widget _onboarding({
  required OnboardingCubit onboarding,
  required LocaleCubit locale,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<OnboardingCubit>.value(value: onboarding),
      BlocProvider<LocaleCubit>.value(value: locale),
    ],
    child: OnboardingScreen(onComplete: () {}),
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('onboarding: first slide (en)', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await pumpAndShoot(
      tester,
      binding,
      _onboarding(
        onboarding: OnboardingCubit(prefs: prefs),
        locale: LocaleCubit(
          prefs: prefs,
          deviceLocaleProvider: () => const Locale('en'),
        ),
      ),
      'onboarding__idle',
    );
  });

  testWidgets('onboarding: first slide (ar)', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await pumpAndShoot(
      tester,
      binding,
      _onboarding(
        onboarding: OnboardingCubit(prefs: prefs),
        locale: LocaleCubit(
          prefs: prefs,
          deviceLocaleProvider: () => const Locale('ar'),
        ),
      ),
      'onboarding__ar',
      locale: const Locale('ar'),
    );
  });
}
