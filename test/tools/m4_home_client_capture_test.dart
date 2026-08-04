// MIDNIGHT · M4 home_client state capture. The In-Progress empty arm is
// catalog-invisible before this wave's new entry; the banner has no screen host.
@Tags(<String>['capture'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_omds_tokens.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/client_home_screen_fixtures.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/in_progress_tab.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/pending_requests_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../support/load_test_fonts.dart';
import '../support/midnight_test_harness.dart';
import '../support/sync_app_localizations.dart';

const Size _kCanvas = Size(440, 956);
const String _kCapturePath = '/capture';
const String _kOut = '../../docs/redesign-midnight/captures/M4/home_client/';

GoRouter _captureRouter(WidgetBuilder builder) => GoRouter(
  initialLocation: _kCapturePath,
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(),
      routes: <RouteBase>[
        GoRoute(
          path: _kCapturePath.substring(1),
          builder: (BuildContext context, _) => builder(context),
        ),
      ],
    ),
  ],
);

Widget _clientHome(ClientHomeRepository repository, ClientHomeTab tab) =>
    Scaffold(
      body: BlocProvider<ClientHomeCubit>(
        create: (_) => ClientHomeScreenPreviewFixtures.cubit(repository),
        child: ClientHomeScreen(
          initialTab: tab,
          onCreateRequest: () {},
          onTrack: (_) {},
        ),
      ),
    );

Future<void> _capture(
  WidgetTester tester,
  String name,
  WidgetBuilder builder,
) async {
  tester.view.physicalSize = _kCanvas;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  useReduceMotion(tester);

  final GoRouter router = _captureRouter(builder);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    OmdsColorTokensProvider(
      tokens: jeebMidnightOmdsTokens,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: withCaptureTestFonts(AppTheme.midnight()),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object?>>[
          SyncAppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: router,
      ),
    ),
  );
  await pumpPastFakeLatency(tester);

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('$_kOut$name.png'),
  );
}

void main() {
  setUpAll(loadCatalogCaptureFonts);

  testWidgets('capture in-progress-empty-parcel', (WidgetTester tester) async {
    await _capture(
      tester,
      'in-progress-empty-parcel',
      (_) => _clientHome(
        ClientHomeScreenPreviewFixtures.empty(),
        ClientHomeTab.inProgress,
      ),
    );
  });

  // ClientHomeScreen short-circuits `failed` to its OWN E1 layout, so the tab's
  // error arm is only visible with the tab mounted standalone.
  testWidgets('capture in-progress-error-parcel', (WidgetTester tester) async {
    await _capture(
      tester,
      'in-progress-error-parcel',
      (_) => Scaffold(
        body: BlocProvider<ClientHomeCubit>(
          create: (_) => ClientHomeScreenPreviewFixtures.cubit(
            ClientHomeScreenPreviewFixtures.failing(),
          )..load(),
          child: const InProgressTab(),
        ),
      ),
    );
  });

  testWidgets('capture client-home-screen-failed-e1',
      (WidgetTester tester) async {
    await _capture(
      tester,
      'client-home-screen-failed-e1',
      (_) => _clientHome(
        ClientHomeScreenPreviewFixtures.failing(),
        ClientHomeTab.inProgress,
      ),
    );
  });

  testWidgets('capture pending-reconnect-banner', (WidgetTester tester) async {
    await _capture(
      tester,
      'pending-reconnect-banner',
      (_) => const Scaffold(
        body: Center(child: PendingReconnectBanner(visible: true)),
      ),
    );
  });
}
