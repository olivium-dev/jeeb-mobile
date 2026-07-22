// Regression guard for the dev-seam create-request top-plus defect (screens
// 13/14/15).
//
// THE DEFECT (capture-confirmed from pixels): on the client-home tabs the "+"
// create-request top plus rendered a light-gray DISABLED circle instead of the
// Figma filled-navy (colorScheme.primary) circle with a white "+". The button
// widget (client_home_greeting.dart `_AddRequestButton` → IconButton.filled
// with OmdsButtonStyles.iconButtonFilled) is correct: it derives its fill from
// colorScheme.primary and its icon from colorScheme.onPrimary. But the SHELL
// constructed ClientHomeScreen WITHOUT an `onCreateRequest` callback
// (home_tab.dart), so it defaulted to null. A null `onPressed` makes
// IconButton render in its DISABLED state, which paints the disabled-gray
// color regardless of the configured backgroundColor — hence the gray plus in
// every screen-13/14/15 capture.
//
// THE FIX: home_tab.dart now passes a non-null `onCreateRequest` (wired to the
// `request-type` route, matching production create-request intent). A non-null
// callback makes `onPressed != null`, so the top plus renders ENABLED → navy.
//
// WHY THIS TEST AND NOT client_home_screen_test.dart's "DEFECT 1": that test
// resolves the button STYLE with an empty WidgetState set ({}), so it asserts
// the navy fill is *configured* — it passes even when the live button is
// disabled (because disabled is a different WidgetState the {} resolution never
// applies). It cannot catch a null callback. THIS test drives the real
// `HomeTab` through the dev seam and asserts the top plus is actually ENABLED
// (onPressed != null), which is the precise condition that regressed to gray.
//
// kDebugMode is true under `flutter test`, so HomeTab._devSeamTab() reads the
// injected DevSeam config — the same runtime path the capture APK takes.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/data/dev_client_home_fixtures.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/shell/tabs/home_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Minimal router so `GoRouter.of(context)` (used by HomeTab's create-request
/// wiring) resolves. The top-plus tap is never exercised here — we only assert the
/// button is enabled — so a single placeholder route is sufficient.
GoRouter _router({required String homeTab}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: HomeTab(
            // Inject the deterministic dev fixtures directly so the test never
            // touches GetIt / Dio; mirrors the seam capture seeding.
            repository: InMemoryClientHomeRepository.fromSnapshot(
              DevClientHomeFixtures.snapshot(),
              latency: Duration.zero,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/request-type',
        builder: (context, state) => const Scaffold(body: Placeholder()),
      ),
    ],
  );
}

Widget _app(GoRouter router) {
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
  );
}

void main() {
  tearDown(DevSeam.debugReset);

  group('HomeTab create-request top plus (dev-seam screens 13/14/15)', () {
    // The seam drives the home tab to each of the three filter variants. In
    // ALL three the create-request top plus must render ENABLED so it paints the
    // navy primary fill (not the disabled-gray that a null callback produces).
    for (final homeTab in const ['pending', 'replies', 'in_progress']) {
      testWidgets(
        'is ENABLED (navy, onPressed != null) under jeeb.home_tab=$homeTab',
        (tester) async {
          DevSeam.debugOverride(DevSeamConfig(route: '/', homeTab: homeTab));

          final handle = tester.ensureSemantics();
          await tester.pumpWidget(_app(_router(homeTab: homeTab)));
          await tester.pumpAndSettle();

          final topPlus = tester.widget<IconButton>(
            find.byKey(const Key('client-home-greeting-add')),
          );

          // The precise condition that regressed to gray: a disabled
          // IconButton (onPressed == null) repaints in the disabled color
          // regardless of its configured navy backgroundColor.
          expect(
            topPlus.onPressed,
            isNotNull,
            reason:
                'create-request top plus must be enabled under the dev seam so it '
                'renders the Figma navy fill, not the disabled-gray circle',
          );
          expect(
            find.bySemanticsIdentifier('orders_create_request_button'),
            findsOneWidget,
          );
          expect(
            find.bySemanticsIdentifier('orders_home_new_order_fab'),
            findsNothing,
          );
          expect(
            find.bySemanticsIdentifier('client_home_voice_request'),
            findsNothing,
          );
          expect(find.bySemanticsIdentifier('orders_search_bar'), findsNothing);
          handle.dispose();
          expect(find.byType(FloatingActionButton), findsNothing);
          expect(find.byKey(const Key('client-home-voice-cta')), findsNothing);
          expect(find.byKey(const Key('client-home-search-bar')), findsNothing);
        },
      );
    }

    testWidgets(
      'resolved background is the navy primary color in the ENABLED state',
      (tester) async {
        DevSeam.debugOverride(
          const DevSeamConfig(route: '/', homeTab: 'pending'),
        );

        await tester.pumpWidget(_app(_router(homeTab: 'pending')));
        await tester.pumpAndSettle();

        final topPlusFinder = find.byKey(const Key('client-home-greeting-add'));
        final topPlus = tester.widget<IconButton>(topPlusFinder);
        expect(topPlus.onPressed, isNotNull);

        // Resolve the style in the *enabled* (non-disabled) state — i.e. the
        // state the button is actually in now — and confirm it is navy primary
        // with a white icon, matching Figma 56535:1783.
        final scheme = Theme.of(tester.element(topPlusFinder)).colorScheme;
        const enabledStates = <WidgetState>{};
        final bg = topPlus.style!.backgroundColor!.resolve(enabledStates);
        final fg = topPlus.style!.foregroundColor!.resolve(enabledStates);
        expect(bg, scheme.primary);
        expect(fg, scheme.onPrimary);
      },
    );
  });
}
