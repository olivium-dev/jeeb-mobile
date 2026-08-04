// MIDNIGHT · M4 capture for the kyc / location / deep_link_targets lane.
//
// 9 of the 12 surfaces this lane restyled were catalog-invisible: the whole
// KYC funnel (5 of 5), both create-flow cold reads, the saved-locations
// mutation overlay and the search bar. Each one gets a frame here.
@Tags(<String>['capture'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_omds_tokens.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/client_location_screen_fixtures.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/kyc_wizard_screen_fixtures.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/saved_locations_screen_fixtures.dart';
import 'package:jeeb_mobile/features/deep_link_targets/kyc_status_screen.dart';
import 'package:jeeb_mobile/features/location/data/location_repository.dart'
    show LocationPoint;
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/location_search_bar.dart';
import 'package:jeeb_mobile/features/location/presentation/saved_locations_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/gps_denied_state.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_wizard_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../support/load_test_fonts.dart';
import '../support/midnight_test_harness.dart';
import '../support/sync_app_localizations.dart';

const Size _kCanvas = Size(440, 956);
const String _kCapturePath = '/capture';
const String _kRoot = '../../docs/redesign-midnight/captures/M4/';

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

Future<void> _capture(
  WidgetTester tester,
  String path,
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
    matchesGoldenFile('$_kRoot$path.png'),
  );
}

/// The frame the capture-location screen gives its message surfaces.
Widget _onField(Widget child) => JeebMidnightField(
  variant: JeebFieldVariant.content,
  child: Scaffold(backgroundColor: Colors.transparent, body: child),
);

void main() {
  setUpAll(loadCatalogCaptureFonts);

  group('kyc', () {
    testWidgets('schema-loading-radar', (WidgetTester tester) async {
      await _capture(
        tester,
        'kyc/kyc__wizard__schema-loading-radar',
        (_) => KycWizardScreen(
          cubit: KycWizardScreenPreviewFixtures.schemaLoadingCubit(),
        ),
      );
    });

    testWidgets('schema-error-radar', (WidgetTester tester) async {
      await _capture(
        tester,
        'kyc/kyc__wizard__schema-error-radar',
        (_) => KycWizardScreen(
          cubit: KycWizardScreenPreviewFixtures.seededCubit(
            KycWizardScreenPreviewFixtures.schemaLoadFailedState,
          ),
        ),
      );
    });

    testWidgets('submitting-loading-radar', (WidgetTester tester) async {
      await _capture(
        tester,
        'kyc/kyc__wizard__submitting-loading-radar',
        (_) => KycWizardScreen(
          cubit: KycWizardScreenPreviewFixtures.seededCubit(
            KycWizardScreenPreviewFixtures.submittingState,
          ),
        ),
      );
    });

    testWidgets('status-loading-radar', (WidgetTester tester) async {
      await _capture(
        tester,
        'kyc/kyc__wizard__status-loading-radar',
        (_) => KycWizardScreen(
          cubit: KycWizardScreenPreviewFixtures.seededCubit(
            KycWizardScreenPreviewFixtures.statusLoadingState,
          ),
        ),
      );
    });

    testWidgets('capture-tile-inline-wait', (WidgetTester tester) async {
      await _capture(
        tester,
        'kyc/kyc__wizard__capture-tile-inline-wait',
        (_) => KycWizardScreen(
          cubit: KycWizardScreenPreviewFixtures.seededCubit(
            KycWizardScreenPreviewFixtures.captureProcessingState(),
          ),
        ),
      );
    });
  });

  group('location', () {
    testWidgets('create-flow-cold-load-e1', (WidgetTester tester) async {
      await _capture(
        tester,
        'location/location__location-select__cold-load-e1',
        (_) => const ClientLocationScreen(
          userId: ClientLocationScreenFixtures.userId,
          repository: ClientLocationScreenFixtures.savedAddressesPending,
          currentLocationResolver: ClientLocationScreenFixtures.gpsResolved,
        ),
      );
    });

    testWidgets('saved-locations-mutating', (WidgetTester tester) async {
      await _capture(
        tester,
        'location/location__saved-addresses__mutating-inline-wait',
        (_) => SavedLocationsScreen(cubit: SavedLocationsScreenMutatingCubit()),
      );
    });

    testWidgets('gps-denied-error-radar', (WidgetTester tester) async {
      await _capture(
        tester,
        'location/location__capture-location__gps-denied-error-radar',
        (_) => _onField(GpsDeniedState(onOpenSettings: () {})),
      );
    });

    testWidgets('search-bar-in-flight', (WidgetTester tester) async {
      await _capture(
        tester,
        'location/location__search-bar__in-flight',
        (_) => _onField(
          Padding(
            padding: const EdgeInsetsDirectional.all(Spacing.medium),
            child: LocationSearchBar(
              hintText: 'Search for a place or address',
              query: 'beirut',
              results: const <LocationPoint>[],
              isSearching: true,
              onChanged: (_) {},
              onResultSelected: (_) {},
            ),
          ),
        ),
      );
    });

    testWidgets('search-bar-results-glass', (WidgetTester tester) async {
      await _capture(
        tester,
        'location/location__search-bar__results-glass',
        (_) => _onField(
          Padding(
            padding: const EdgeInsetsDirectional.all(Spacing.medium),
            child: LocationSearchBar(
              hintText: 'Search for a place or address',
              query: 'beirut',
              results: const <LocationPoint>[
                LocationPoint(
                  latitude: 33.8959,
                  longitude: 35.4797,
                  address: 'Hamra Street, Beirut',
                ),
                LocationPoint(
                  latitude: 33.8886,
                  longitude: 35.4955,
                  address: 'Sassine Square, Ashrafieh',
                ),
              ],
              isSearching: false,
              onChanged: (_) {},
              onResultSelected: (_) {},
            ),
          ),
        ),
      );
    });
  });

  group('deep_link_targets', () {
    testWidgets('kyc-status-stub-radar', (WidgetTester tester) async {
      await _capture(
        tester,
        'deep_link_targets/deep-link-targets__kycstatusscreen__stub-radar',
        (_) => const KycStatusScreen(),
      );
    });
  });
}
