// TEST-03: every catalog state, untagged, so a state that throws on build is
// no longer invisible behind `@Tags(['capture'])`. One assertion: it builds.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_omds_tokens.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:omds/omds.dart';

import '../support/midnight_test_harness.dart';
import '../support/sync_app_localizations.dart';

/// The board's own canvas: a narrower one would import pre-existing overflow
/// into a gate that exists to catch build failures.
const Size _kCanvas = Size(440, 956);

/// Overflowing at the board's canvas when this gate landed — named, not
/// skipped. Never add a row; delete rows as WP-3 / WP-8 fix them.
const Set<String> _kKnownOverflow = <String>{
  'client_offers · client_offers_screen · 0 Loaded — 3 offers',
  'client_offers · client_offers_screen · 2 Offer window expired',
  'client_offers · client_offers_screen · 3 Request closed',
  'home_client · Client Home (Requests tab) · 0 In Progress (populated)',
  'jeeber_onboarding · Delivery-Man Onboarding Wizard · 3 Step 3 — Checking coverage',
  'jeeber_onboarding · Delivery-Man Onboarding Wizard · 4 Step 3 — Coverage check failed',
};

/// Catalog screens are reached by a push, so `context.canPop()` must be true
/// and `GoRouter.of` must resolve at build time.
const String _kSmokePath = '/smoke';

GoRouter _smokeRouter(WidgetBuilder builder) => GoRouter(
  initialLocation: _kSmokePath,
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(),
      routes: <RouteBase>[
        GoRoute(
          path: _kSmokePath.substring(1),
          builder: (BuildContext context, _) => builder(context),
        ),
      ],
    ),
  ],
);

void main() {
  setUpAll(stubNetworkImageCacheIo);

  for (final CatalogEntry entry in kScreenCatalog) {
    for (int i = 0; i < entry.states.length; i++) {
      final CatalogState state = entry.states[i];
      final String name =
          '${entry.feature} · ${entry.screen} · $i ${state.label}';

      // navigationOnly states redirect away by design; there is nothing to
      // build and their behaviour is covered by their own feature tests.
      if (state.capturePolicy == CatalogCapturePolicy.navigationOnly) {
        continue;
      }

      testWidgets('builds · $name', (WidgetTester tester) async {
        tester.view.physicalSize = _kCanvas;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        useReduceMotion(tester);

        // takeException() collapses repeats into one summary, so the known
        // rows are checked against every error the build actually reported.
        final List<String> reported = <String>[];
        final void Function(FlutterErrorDetails)? previousOnError =
            FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          reported.add(details.exceptionAsString());
          previousOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = previousOnError);

        final GoRouter router = _smokeRouter(state.builder);
        addTearDown(router.dispose);

        await tester.pumpWidget(
          OmdsColorTokensProvider(
            tokens: jeebMidnightOmdsTokens,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.midnight(),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates:
                  const <LocalizationsDelegate<Object?>>[
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

        final Object? thrown = tester.takeException();
        if (_kKnownOverflow.contains(name)) {
          expect(
            reported,
            isNotEmpty,
            reason: 'this state no longer fails — delete its row from '
                '_kKnownOverflow so the fix is locked in',
          );
          expect(
            reported,
            everyElement(contains('overflowed')),
            reason: 'this known-overflow state now fails for a NEW reason',
          );
          return;
        }
        expect(
          thrown,
          isNull,
          reason: 'a designed state that cannot build is a state nobody can '
              'review and nobody can ship',
        );
      });
    }
  }
}
