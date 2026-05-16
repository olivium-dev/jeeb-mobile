import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/locale/locale_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/role_eligibility_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/shell/shell_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncAppLocalizationsDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return debugLoadAppLocalizationsSync(
      locale,
      _arbByTag[locale.languageCode]!,
    );
  }

  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

late _SyncAppLocalizationsDelegate _syncDelegate;

void _loadArbFromDisk() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncAppLocalizationsDelegate({'en': en, 'ar': ar});
}

Widget _harness({
  required SharedPreferences prefs,
  Locale locale = const Locale('en'),
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => LocaleCubit(
          prefs: prefs,
          deviceLocaleProvider: () => locale,
        ),
      ),
      BlocProvider(create: (_) => RoleCubit(prefs: prefs)),
      BlocProvider(create: (_) => RoleEligibilityCubit()),
    ],
    child: BlocBuilder<LocaleCubit, Locale>(
      builder: (context, l) => MaterialApp(
        theme: AppTheme.light(),
        locale: l,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          _syncDelegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ShellScreen(),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadArbFromDisk);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Client role shows Home/Orders/Chat/Profile tabs',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs: prefs));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Orders'), findsWidgets);
    expect(find.text('Chat'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
    // Jeeber-only tabs must NOT be present.
    expect(find.text('Dashboard'), findsNothing);
    expect(find.text('Earnings'), findsNothing);
  });

  testWidgets('Switching to jeeber swaps to Dashboard/Earnings/Chat/Profile',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs: prefs));
    await tester.pumpAndSettle();

    final BuildContext ctx = tester.element(find.byType(ShellScreen));
    await ctx.read<RoleCubit>().setRole(UserRole.jeeber);
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Earnings'), findsWidgets);
    expect(find.text('Chat'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
    expect(find.text('Home'), findsNothing);
    expect(find.text('Orders'), findsNothing);
  });

  testWidgets('Arabic locale renders RTL bottom-nav labels in Arabic',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs: prefs, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('الرئيسية'), findsWidgets);
    expect(find.text('طلباتي'), findsWidgets);
    expect(find.text('المحادثات'), findsWidgets);
    expect(find.text('حسابي'), findsWidgets);

    final BuildContext ctx = tester.element(find.byType(NavigationBar));
    expect(Directionality.of(ctx), TextDirection.rtl);
  });

  testWidgets('Role switch resets selected tab to 0 so we never land on a removed tab',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(_harness(prefs: prefs));
    await tester.pumpAndSettle();

    // Tap the Orders destination (client-only, index 1).
    await tester.tap(find.text('Orders').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orders-tab-empty')), findsOneWidget);

    final BuildContext ctx = tester.element(find.byType(ShellScreen));
    await ctx.read<RoleCubit>().setRole(UserRole.jeeber);
    await tester.pumpAndSettle();

    // After switching to jeeber, tab 0 (Dashboard) should be active.
    expect(find.byKey(const Key('dashboard-tab-root')), findsOneWidget);
    expect(find.byKey(const Key('earnings-tab-empty')), findsNothing);
  });
}
