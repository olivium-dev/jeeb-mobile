// Isolated native UI test — LanguageSettingsScreen (Settings → Language). The
// screen owns its own Scaffold but reads a LocaleCubit for the active-row check
// mark, so we provide one whose state is driven by the device-locale provider.
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/features/language/presentation/screens/language_settings_screen.dart';

import '../support/screen_harness.dart';

Widget _languageSettings(LocaleCubit cubit) {
  return BlocProvider<LocaleCubit>.value(
    value: cubit,
    child: const LanguageSettingsScreen(),
  );
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('language-settings: English selected (en)', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('en'),
    );
    await pumpAndShoot(
      tester,
      binding,
      _languageSettings(cubit),
      'language-settings__en',
    );
  });

  testWidgets('language-settings: Arabic selected (ar)', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final cubit = LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('ar'),
    );
    await pumpAndShoot(
      tester,
      binding,
      _languageSettings(cubit),
      'language-settings__ar',
      locale: const Locale('ar'),
    );
  });
}
