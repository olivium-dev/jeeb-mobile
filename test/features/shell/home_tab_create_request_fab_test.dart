// Regression guard for the dev-seam create-request defect (screens 13/14/15).
//
// THE DEFECT (capture-confirmed from pixels): the SHELL constructed
// ClientHomeScreen WITHOUT an `onCreateRequest` callback (home_tab.dart), so it
// defaulted to null and the create surface rendered inert — originally as a
// disabled-gray "+" circle instead of the Figma filled-navy one.
//
// THE FIX: home_tab.dart now passes a non-null `onCreateRequest` (wired to the
// `request-type` route, matching production create-request intent).
//
// REDESIGN-2026-08 (screen 04, wiring request): the top "+" IconButton
// (`Key('client-home-greeting-add')`) was replaced by the board's mic hero, so
// the assertions below moved off that Key and onto the FROZEN semantics
// identifier `orders_create_request_button` that survived the rebuild. The
// GUARDED DEFECT is unchanged and is what these tests still prove: the create
// surface must never render with a null callback from the shell. The negative
// pins (`client_home_voice_request` and `Key('client-home-voice-cta')` absent)
// are kept verbatim — those surfaces stay retired.
//
// WHY THIS TEST AND NOT client_home_screen_test.dart's "DEFECT 1": that test
// asserts the create affordance is *configured* correctly; it cannot catch a
// null callback handed down by the shell. THIS test drives the real `HomeTab`
// through the dev seam and asserts the create node actually carries a tap
// action, which is the precise condition that regressed.
//
// kDebugMode is true under `flutter test`, so HomeTab._devSeamTab() reads the
// injected DevSeam config — the same runtime path the capture APK takes.

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
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
/// wiring) resolves. The create tap is never exercised here — we only assert the
/// node carries a tap action — so a single placeholder route is sufficient.
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
        // NAMED, because HomeTab._openRequestType uses `pushNamed`.
        path: '/request-type',
        name: 'request-type',
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
    // Midnight primitives loop ∞ (02-STUDY-NOTES M0-4): `pumpAndSettle` only
    // terminates under reduce motion.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
  );
}

void main() {
  tearDown(DevSeam.debugReset);

  group('HomeTab create-request surface (dev-seam screens 13/14/15)', () {
    // The seam drives the home tab to each of the three filter variants. In
    // ALL three the create-request surface must render with a live callback —
    // a null one from the shell is the defect this file guards.
    for (final homeTab in const ['pending', 'replies', 'in_progress']) {
      testWidgets(
        'is ENABLED (tap action present) under jeeb.home_tab=$homeTab',
        (tester) async {
          DevSeam.debugOverride(DevSeamConfig(route: '/', homeTab: homeTab));

          final handle = tester.ensureSemantics();
          await tester.pumpWidget(_app(_router(homeTab: homeTab)));
          await tester.pumpAndSettle();

          final createFinder = find.bySemanticsIdentifier(
            'orders_create_request_button',
          );
          expect(createFinder, findsOneWidget);

          // The precise condition that regressed: the shell handing down a
          // null `onCreateRequest`, which strips the tap action off the node
          // while the surface still paints.
          expect(
            tester
                .getSemantics(createFinder)
                .getSemanticsData()
                .hasAction(SemanticsAction.tap),
            isTrue,
            reason:
                'create-request surface must carry a live tap handler under the '
                'dev seam — a null shell callback renders it inert',
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

    // RETIRED (redesign-2026-08, screen 04): this file's second case used to
    // resolve `IconButton.style.backgroundColor` on
    // `Key('client-home-greeting-add')` and assert the navy primary fill. That
    // IconButton no longer exists — the board's mic hero replaced it — and the
    // hero's navy card fill / accent mic is now asserted by
    // `client_home_screen_test.dart` ("create-request hero uses primary card
    // fill + accent mic"), which owns that surface. The defect THIS file
    // guards (a null `onCreateRequest` handed down by the shell) is fully
    // covered by the three dev-seam cases above, which assert the frozen
    // `orders_create_request_button` node carries a live tap action.
  });
}
