import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/jeeber_home/application/availability_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/services/availability_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/jeeber_home_screen.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_repository.dart';
import 'package:jeeb_mobile/features/shell/tabs/dashboard_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// Regression for the E2E "Switch to Jeeber" crash.
/// The in-app role toggle lands on [DashboardTab], which in the production
/// (non-dev-seam) path mounts `JeeberHomeScreen(isRegistered: true)`. That
class _ScriptedAvailabilityGateway extends InMemoryAvailabilityGateway {}

LocalizationsDelegate<AppLocalizations> _loadSyncDelegate() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  return _SyncAppLocalizationsDelegate({'en': en, 'ar': ar});
}

class _SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncAppLocalizationsDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

GoRouter _router() {
  // Minimal router: the dashboard tab uses context.pushNamed for its
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: DashboardTab()),
      ),
      GoRoute(
        path: '/jeeber/onboarding',
        name: 'jeeber-onboarding',
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
      ),
      GoRoute(
        path: '/jeeber/requests/:id',
        name: 'jeeber-request-detail',
        builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
      ),
    ],
  );
}

Widget _app(
  LocalizationsDelegate<AppLocalizations> delegate, {
  Locale locale = const Locale('en'),
}) {
  return MaterialApp.router(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    routerConfig: _router(),
  );
}

void main() {
  late LocalizationsDelegate<AppLocalizations> delegate;

  setUpAll(() {
    delegate = _loadSyncDelegate();
  });

  setUp(() {
    // The DI registrations the production DashboardTab resolves. An in-memory
    sl.registerLazySingleton<AvailabilityGateway>(
      _ScriptedAvailabilityGateway.new,
    );
    // JEEBER-LOOP F3: the host now also builds a RequestFeedCubit from a
    sl.registerLazySingleton<RequestFeedRepository>(
      () => SeededRequestFeedRepository(const []),
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  testWidgets(
    'DashboardTab provides AvailabilityCubit above JeeberHomeScreen so the '
    'role-switch into the Jeeber surface does not throw ProviderNotFound',
    (tester) async {
      await tester.pumpWidget(_app(delegate));
      await tester.pumpAndSettle();

      // 1. Bringing the Jeeber surface up threw nothing (pre-fix: a
      expect(
        tester.takeException(),
        isNull,
        reason:
            'JeeberHomeScreen must mount with an AvailabilityCubit in scope; '
            'a ProviderNotFound here is the E2E "Switch to Jeeber" crash.',
      );

      // 2. The registered Jeeber home actually rendered.
      expect(find.byType(JeeberHomeScreen), findsOneWidget);
      expect(find.byKey(JeeberHomeScreen.scaffoldKey), findsOneWidget);

      // 3. The cubit is STRUCTURALLY resolvable from inside JeeberHomeScreen's
      final BuildContext screenCtx = tester.element(
        find.byType(JeeberHomeScreen),
      );
      final cubit = screenCtx.read<AvailabilityCubit>();
      expect(cubit, isA<AvailabilityCubit>());

      // 4. Dashboard simplify: the personalized greeting is the ONE page title;
      final dashboard = find.byType(JeeberHomeScreen);
      expect(
        find.descendant(
          of: dashboard,
          matching: find.text('Welcome back', skipOffstage: false),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: dashboard,
          matching: find.text('Jeeber Home', skipOffstage: false),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: dashboard,
          matching: find.text('Everything, One Place', skipOffstage: false),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('the one dashboard title is localized and RTL in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(_app(delegate, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('مرحبًا بعودتك'), findsOneWidget);
    expect(find.text('شاشة الجِيبر الرئيسية'), findsNothing);
    expect(
      Directionality.of(tester.element(find.byType(JeeberHomeScreen))),
      TextDirection.rtl,
    );
  });
}
