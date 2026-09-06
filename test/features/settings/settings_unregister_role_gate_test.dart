// F3 — Become-a-Jeeber vs Unregister-as-Jeeber role gate (mutually exclusive).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/role/role_availability_cubit.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/settings/application/settings_cubit.dart';
import 'package:jeeb_mobile/features/settings/presentation/screens/settings_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/settings_fakes.dart';
import '../../support/sync_app_localizations.dart';

const _kBecomeJeeberKey = Key('settings-row-become-jeeber');
const _kUnregisterRowKey = Key('settings-row-unregister-jeeber');

// The board's own canvas (matches settings_screen_midnight_test.dart) — the
// default 800x600 test window is too short and puts MORE-card rows offscreen.
const Size _kCanvas = Size(440, 956);

Widget _harness(
  SharedPreferences prefs,
  SettingsCubit cubit, {
  RoleAvailabilityCubit? roleAvailability,
}) {
  final view = MaterialApp(
    theme: withCaptureTestFonts(AppTheme.midnight()),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: SettingsScreen(cubit: cubit, appVersion: '1.2.3'),
  );
  final locale = BlocProvider(
    create: (_) => LocaleCubit(
      prefs: prefs,
      deviceLocaleProvider: () => const Locale('en'),
    ),
    child: view,
  );
  if (roleAvailability == null) return locale;
  return BlocProvider<RoleAvailabilityCubit>.value(
    value: roleAvailability,
    child: locale,
  );
}

Future<SettingsCubit> _loadedCubit({FakeJeeberUnregisterService? service}) async {
  final cubit = SettingsCubit(
    profileRepository: InMemoryProfileRepository(),
    accountService: const FakeAccountService(),
    jeeberUnregisterService: service,
    fallbackPhoneE164: '+96170100200',
  );
  await cubit.load();
  return cubit;
}

Future<void> _setCanvas(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(_kCanvas);
  addTearDown(() async => tester.binding.setSurfaceSize(null));
}

void main() {
  setUpAll(loadCatalogCaptureFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'no RoleAvailabilityCubit provided (bare host): shows Become-a-Jeeber, '
      'never the unregister row', (tester) async {
    await _setCanvas(tester);
    final prefs = await SharedPreferences.getInstance();
    final cubit = await _loadedCubit();
    addTearDown(cubit.close);

    await tester.pumpWidget(_harness(prefs, cubit));
    await tester.pumpAndSettle();

    expect(find.byKey(_kBecomeJeeberKey), findsOneWidget);
    expect(find.byKey(_kUnregisterRowKey), findsNothing);
  });

  testWidgets('roles without jeeber: shows Become-a-Jeeber only',
      (tester) async {
    await _setCanvas(tester);
    final prefs = await SharedPreferences.getInstance();
    final cubit = await _loadedCubit();
    addTearDown(cubit.close);
    final roleAvailability =
        RoleAvailabilityCubit(const RoleAvailability(roles: ['client']));
    addTearDown(roleAvailability.close);

    await tester.pumpWidget(
      _harness(prefs, cubit, roleAvailability: roleAvailability),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_kBecomeJeeberKey), findsOneWidget);
    expect(find.byKey(_kUnregisterRowKey), findsNothing);
  });

  testWidgets(
      'roles holding jeeber: shows the unregister row only, never '
      'Become-a-Jeeber (mutually exclusive)', (tester) async {
    await _setCanvas(tester);
    final prefs = await SharedPreferences.getInstance();
    final cubit = await _loadedCubit();
    addTearDown(cubit.close);
    final roleAvailability = RoleAvailabilityCubit(
      const RoleAvailability(roles: ['client', 'jeeber']),
    );
    addTearDown(roleAvailability.close);

    await tester.pumpWidget(
      _harness(prefs, cubit, roleAvailability: roleAvailability),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_kUnregisterRowKey), findsOneWidget);
    expect(find.byKey(_kBecomeJeeberKey), findsNothing);
  });

  testWidgets(
      'tapping the row opens the confirm sheet, and confirming drives the '
      'cubit through to the done banner', (tester) async {
    await _setCanvas(tester);
    final prefs = await SharedPreferences.getInstance();
    final service = FakeJeeberUnregisterService();
    final cubit = await _loadedCubit(service: service);
    addTearDown(cubit.close);
    final roleAvailability = RoleAvailabilityCubit(
      const RoleAvailability(roles: ['client', 'jeeber']),
    );
    addTearDown(roleAvailability.close);

    await tester.pumpWidget(
      _harness(prefs, cubit, roleAvailability: roleAvailability),
    );
    await tester.pumpAndSettle();

    // F11 grew the notifications band, so the MORE row can start below the
    // fold on the compact canvas.
    await tester.ensureVisible(find.byKey(_kUnregisterRowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_kUnregisterRowKey));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsIdentifier('unregister_jeeber_confirm_sheet'),
      findsOneWidget,
    );

    await tester.tap(find.bySemanticsIdentifier('unregister_jeeber_confirm_cta'));
    await tester.pump(); // in-flight
    await tester.pump(); // resolves
    await tester.pumpAndSettle(); // sheet pop + snackbar

    expect(service.calls, 1);
    expect(cubit.state.jeeberUnregistered, isTrue);
    expect(find.text('You\'re no longer registered as a Jeeber.'),
        findsOneWidget);
  });
}
