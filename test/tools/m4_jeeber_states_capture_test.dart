// MIDNIGHT · M4 capture for the jeeber-side state surfaces this lane restyled.
//
// Written as a one-off rather than through the shared catalog sweep so this
// lane's captures land in its own folder and cannot collide with a concurrent
// lane re-writing `docs/redesign-2026-08/actual/`.
//
//   flutter test test/tools/m4_jeeber_states_capture_test.dart --update-goldens
@Tags(<String>['capture'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_omds_tokens.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/request_feed_screen_fixtures.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/feed_request.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_feed_empty_view.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/jeeber_unregistered_view.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_loader.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/cubit/request_feed_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/request_feed_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../support/load_test_fonts.dart';
import '../support/midnight_test_harness.dart';
import '../support/sync_app_localizations.dart';

const Size _kCanvas = Size(440, 956);
const String _kCapturePath = '/capture';

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

void _capture(String path, WidgetBuilder builder) {
  testWidgets('capture $path', (WidgetTester tester) async {
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

    await tester.pump(const Duration(milliseconds: 400));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/redesign-midnight/captures/M4/$path.png'),
    );

    // The feed view runs a 1Hz countdown ticker cancelled only on dispose.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Widget _feed(RequestFeedCubit cubit) {
  addTearDown(cubit.close);
  return RequestFeedScreen(cubit: cubit);
}

void main() {
  setUpAll(loadCatalogCaptureFonts);

  _capture(
    'jeeber_request_feed/request-feed__0-loading-cold-read',
    (_) => _feed(RequestFeedScreenPreviewFixtures.coldRead()),
  );
  _capture(
    'jeeber_request_feed/request-feed__1-error-load-failed',
    (_) => _feed(RequestFeedScreenPreviewFixtures.loadFailed()),
  );
  _capture(
    'jeeber_request_feed/request-feed__2-empty-no-requests-right-now',
    (_) => _feed(RequestFeedScreenPreviewFixtures.emptyBoard()),
  );

  _capture(
    'jeeber_request_detail/request-detail-loader__0-loading-recovering-by-id',
    (_) => JeeberRequestDetailLoader(
      requestId: 'req-303',
      initial: null,
      fetch: () => Completer<FeedRequest?>().future,
      reportService: const ProhibitedItemReportService(),
      onDeclined: (_) {},
      onBack: () {},
    ),
  );

  _capture(
    'jeeber_home/jeeber-feed-empty-view__0-empty-no-requests-yet',
    (_) => const Scaffold(body: JeeberFeedEmptyView(profileName: 'Kamal')),
  );
  _capture(
    'jeeber_home/jeeber-unregistered-view__0-upsell-register-as-a-jeeber',
    (_) => Scaffold(
      body: JeeberUnregisteredView(onRegister: () {}, profileName: 'Kamal'),
    ),
  );
}
