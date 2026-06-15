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
///
/// The in-app role toggle lands on [DashboardTab], which in the production
/// (non-dev-seam) path mounts `JeeberHomeScreen(isRegistered: true)`. That
/// screen reads `AvailabilityCubit` in `didChangeDependencies` and in its
/// `_RegisteredBody` `BlocConsumer`. The app root deliberately does NOT
/// provide a global `AvailabilityCubit` (it is screen-scoped with an idle
/// ticker), so [DashboardTab] itself must provide it. Before the fix it did
/// not — only the dev-seam feed path provided one — so the registered screen
/// threw `ProviderNotFound<AvailabilityCubit>` on entry and the Jeeber surface
/// crashed.
///
/// This test pumps the REAL [DashboardTab] under a router with DI registered
/// and WITHOUT any ancestor `AvailabilityCubit` provider, exactly matching the
/// production path. It fails (throws ProviderNotFound) on the pre-fix source
/// and passes once [DashboardTab] wraps the screen in a
/// `BlocProvider<AvailabilityCubit>`.
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
  // feed/onboarding tap-throughs, so a GoRouter must be in scope. We only
  // need the home route to render the tab; the named targets are declared so
  // a stray push does not error the test setup.
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

Widget _app(LocalizationsDelegate<AppLocalizations> delegate) {
  return MaterialApp.router(
    theme: AppTheme.light(),
    locale: const Locale('en'),
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
    // gateway keeps the cubit's cold-start fetch deterministic and offline.
    sl.registerLazySingleton<AvailabilityGateway>(
      _ScriptedAvailabilityGateway.new,
    );
    // JEEBER-LOOP F3: the host now also builds a RequestFeedCubit from a
    // DI-registered RequestFeedRepository, so this regression harness must
    // register one too. An empty seeded feed keeps this test focused on the
    // availability-provider contract (the feed-render contract is covered by
    // dashboard_tab_request_feed_provider_test.dart).
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
    //    FlutterError carrying `ProviderNotFound<AvailabilityCubit>`).
    expect(
      tester.takeException(),
      isNull,
      reason: 'JeeberHomeScreen must mount with an AvailabilityCubit in scope; '
          'a ProviderNotFound here is the E2E "Switch to Jeeber" crash.',
    );

    // 2. The registered Jeeber home actually rendered.
    expect(find.byType(JeeberHomeScreen), findsOneWidget);
    expect(find.byKey(JeeberHomeScreen.scaffoldKey), findsOneWidget);

    // 3. The cubit is STRUCTURALLY resolvable from inside JeeberHomeScreen's
    //    subtree (not merely "no error") — proving a live cubit is wired, not
    //    that the read was swallowed. read<T>() throws if the provider is
    //    absent, so a non-null instance is the structural guarantee.
    final BuildContext screenCtx =
        tester.element(find.byType(JeeberHomeScreen));
    final cubit = screenCtx.read<AvailabilityCubit>();
    expect(cubit, isA<AvailabilityCubit>());
  });
}
