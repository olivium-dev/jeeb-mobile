// Capture harness — NOT a gate. Renders every Dev Tool catalog state to a PNG so
// the implementation can be compared against the design board frame by frame.
//
// This exists because "the tests pass" and "it looks like the design" are
// different claims, and only the second one is what the redesign was for.
//
// Write the images:
//   flutter test test/tools/catalog_capture_test.dart --update-goldens
//
// Output: docs/redesign-2026-08/actual/<feature>__<screen>__<state>.png at the
// board's own 440x956 canvas, so a capture and a design frame are directly
// comparable without rescaling.
//
// Every state gets its own testWidgets so one screen that throws cannot take the
// rest of the sweep down with it.
@Tags(<String>['capture'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_omds_tokens.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:omds/omds.dart';

import '../support/load_test_fonts.dart';
import '../support/midnight_test_harness.dart';
import '../support/sync_app_localizations.dart';

/// The design board's canvas. Matching it means a capture and a frame line up
/// without rescaling, which is the whole point of the comparison.
const Size _kCanvas = Size(440, 956);

/// Mounted as a child route so `context.canPop()` is TRUE, the way every
/// catalog screen is really reached — pushed on top of something.
const String _kCapturePath = '/capture';

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

/// Screens reached by a push read `Router.of` (`RootAwareBackScope`) and
/// `GoRouter.of` (`RequestTicket`) at BUILD time and throw without an ancestor.
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

void main() {
  // Without this the captures render every glyph as a solid block: the theme
  // NAMES Inter but the faces are never loaded, so copy cannot be compared.
  setUpAll(loadCatalogCaptureFonts);

  // States seeding a network image (avatars, the receipt proof photo) reach
  // flutter_cache_manager, which wants path_provider AND a sqflite factory.
  setUpAll(stubNetworkImageCacheIo);

  for (final CatalogEntry entry in kScreenCatalog) {
    for (int i = 0; i < entry.states.length; i++) {
      final CatalogState state = entry.states[i];
      final String name =
          '${_slug(entry.feature)}__${_slug(entry.screen)}__$i-${_slug(state.label)}';

      if (state.capturePolicy == CatalogCapturePolicy.navigationOnly) {
        test(
          'capture $name',
          () {},
          skip:
              'Redirect behavior is covered by test/features/kyc_rejected/'
              'kyc_rejected_midnight_test.dart: a failed authority read leaves '
              'the terminal route.',
        );
        continue;
      }

      testWidgets('capture $name', (WidgetTester tester) async {
        tester.view.physicalSize = _kCanvas;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // M0-4 ruling: every capture is taken at the deterministic
        // reduce-motion rest frame.
        useReduceMotion(tester);

        final GoRouter router = _captureRouter(state.builder);
        addTearDown(router.dispose);

        await tester.pumpWidget(
          OmdsColorTokensProvider(
            tokens: jeebMidnightOmdsTokens,
            child: MaterialApp.router(
              // The DEBUG ribbon is chrome the board never draws; it sat over
              // the top-end corner of every capture.
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
          matchesGoldenFile('../../docs/redesign-2026-08/actual/$name.png'),
        );
      });
    }
  }
}
