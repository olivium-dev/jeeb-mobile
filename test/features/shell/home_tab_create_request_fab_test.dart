// Regression guard for the dev-seam create-request defect (screens 13/14/15).
//
// THE DEFECT (capture-confirmed from pixels): the SHELL constructed
// ClientHomeScreen WITHOUT an `onCreateRequest` callback (home_tab.dart), so it
// defaulted to null and the create surface rendered inert — originally as a
// disabled-gray "+" circle instead of the Figma filled-navy one.
//
// THE FIX: home_tab.dart now passes a non-null `onCreateRequest` (matching
// production create-request intent).
//
// SINGLE DOOR (UX merge, supersedes 2026-08-22): that callback opens the
// merged `client-location` ("New request") screen unconditionally. The tier is
// chosen THERE (Standard default + a Change sheet), so the home tap still
// seeds nothing into the compose controller — the screen owns its default.
// The catalog-shaped cases below all land on the same door, which is the point.
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
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/data/dev_client_home_fixtures.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/shell/tabs/home_tab.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _NoopSubmission implements RequestSubmissionService {
  @override
  Future<String> submit(RequestDraft draft) async => 'req-1';
}

/// `FakeTierRepository.defaultCatalog` carries no `serverId`, so every tier in
/// it has a null `wireId` and none of them is a legal create-POST default.
class _WiredCatalog implements TierRepository {
  const _WiredCatalog();

  @override
  Future<List<Tier>> fetchTiers() async => const <Tier>[
    Tier(
      id: TierId.flash,
      serverId: 'tier-flash',
      priceLow: 120000,
      priceHigh: 160000,
      currency: 'LBP',
      vehicleClass: TierVehicleClass.scooterOrCar,
      slaMinutes: 60,
    ),
    Tier(
      id: TierId.standard,
      serverId: 'tier-standard',
      priceLow: 45000,
      priceHigh: 70000,
      currency: 'LBP',
      vehicleClass: TierVehicleClass.bikeOrScooter,
      slaMinutes: 240,
      recommended: true,
    ),
  ];
}

/// Counts reads so a create tap that re-fetches the catalog the home screen
/// already warmed is visible as a number, not as a stall.
class _CountingCatalog implements TierRepository {
  _CountingCatalog();

  int calls = 0;

  @override
  Future<List<Tier>> fetchTiers() async {
    calls += 1;
    return const _WiredCatalog().fetchTiers();
  }
}

/// A catalog that has not answered yet — the cold-cellular case the create
/// door used to sit on with no spinner and no disabled state.
class _SlowCatalog implements TierRepository {
  const _SlowCatalog();

  @override
  Future<List<Tier>> fetchTiers() => Future<List<Tier>>.delayed(
    const Duration(milliseconds: 800),
    () => const _WiredCatalog().fetchTiers(),
  );
}

/// Minimal router so `GoRouter.of(context)` (used by HomeTab's create-request
/// wiring) resolves. BOTH create routes stay registered: `client-location` is
/// where the tap lands (UX merge), `request-type` so a stray legacy push would
/// be VISIBLE as a wrong screen rather than a route-not-found crash.
GoRouter _router({VoidCallback? onCreateScreenBuild}) {
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
        name: 'request-type',
        builder: (context, state) =>
            const Scaffold(body: Text('request-type-screen')),
      ),
      GoRoute(
        // NAMED, because HomeTab._openCreateRequest uses `pushNamed`.
        path: '/client-location',
        name: 'client-location',
        builder: (context, state) {
          onCreateScreenBuild?.call();
          return const Scaffold(body: Text('client-location-screen'));
        },
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
  tearDown(() async {
    DevSeam.debugReset();
    await sl.reset();
  });

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
          await tester.pumpWidget(_app(_router()));
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

    // SINGLE DOOR — the typed door lands on the merged "New request" screen,
    // which owns the tier default; the legacy tier screen must never mount.
    testWidgets('the create tap opens client-location, never the tier screen', (
      tester,
    ) async {
      DevSeam.debugOverride(const DevSeamConfig(route: '/', homeTab: 'pending'));
      sl.registerSingleton<TierRepository>(const _WiredCatalog());
      final compose = ComposeRequestController(_NoopSubmission());
      sl.registerSingleton<ComposeRequestController>(compose);

      await tester.pumpWidget(_app(_router()));
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('orders_create_request_button'),
      );
      await tester.pumpAndSettle();

      expect(find.text('client-location-screen'), findsOneWidget);
      expect(find.text('request-type-screen'), findsNothing);
    });

    // The home tap must seed NOTHING: the merged screen owns its own Standard
    // default, so a tier can never be smuggled in behind the customer.
    testWidgets('the tap seeds no tier — the merged screen owns that choice', (
      tester,
    ) async {
      DevSeam.debugOverride(const DevSeamConfig(route: '/', homeTab: 'pending'));
      sl.registerSingleton<TierRepository>(const _WiredCatalog());
      final compose = ComposeRequestController(_NoopSubmission());
      sl.registerSingleton<ComposeRequestController>(compose);

      await tester.pumpWidget(_app(_router()));
      await tester.pumpAndSettle();
      expect(compose.tier, isNull);

      await tester.tap(
        find.bySemanticsIdentifier('orders_create_request_button'),
      );
      await tester.pumpAndSettle();

      expect(find.text('client-location-screen'), findsOneWidget);
      expect(compose.tier, isNull);
    });

    // The tap must be a pure navigation: blocking the primary CTA on a live GET
    // is both a dead window and a second push waiting to happen. (The merged
    // screen resolves its own tier default behind its own placeholder.)
    testWidgets('the create tap is pure navigation, never a catalog read', (
      tester,
    ) async {
      DevSeam.debugOverride(const DevSeamConfig(route: '/', homeTab: 'pending'));
      final catalog = _CountingCatalog();
      sl.registerSingleton<TierRepository>(catalog);
      sl.registerSingleton<ComposeRequestController>(
        ComposeRequestController(_NoopSubmission()),
      );

      var createScreenBuilds = 0;
      await tester.pumpWidget(
        _app(_router(onCreateScreenBuild: () => createScreenBuilds += 1)),
      );
      await tester.pumpAndSettle();
      expect(catalog.calls, 1, reason: 'the screen warms the catalog once');

      final cta = find.bySemanticsIdentifier('orders_create_request_button');
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(find.text('client-location-screen'), findsOneWidget);
      expect(catalog.calls, 1, reason: 'the tap itself must not fetch /tiers');
      expect(createScreenBuilds, 1);
      expect(
        cta,
        findsNothing,
        reason:
            'the pushed route covers the button from the first frame, so there '
            'is no window in which a second tap stacks a second create screen',
      );
    });

    // The other half of the same defect: catalog state must not reach the door
    // at all. These three pin that every warm outcome opens the same screen.
    testWidgets('a catalog still in flight opens the picker, never a stall', (
      tester,
    ) async {
      DevSeam.debugOverride(const DevSeamConfig(route: '/', homeTab: 'pending'));
      sl.registerSingleton<TierRepository>(const _SlowCatalog());
      sl.registerSingleton<ComposeRequestController>(
        ComposeRequestController(_NoopSubmission()),
      );

      await tester.pumpWidget(_app(_router()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      await tester.tap(
        find.bySemanticsIdentifier('orders_create_request_button'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('client-location-screen'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('an unreachable catalog still asks, and never invents a tier', (
      tester,
    ) async {
      DevSeam.debugOverride(const DevSeamConfig(route: '/', homeTab: 'pending'));
      sl.registerSingleton<TierRepository>(
        const FakeTierRepository(failWith: TierLoadFailure.network),
      );
      final compose = ComposeRequestController(_NoopSubmission());
      sl.registerSingleton<ComposeRequestController>(compose);

      await tester.pumpWidget(_app(_router()));
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('orders_create_request_button'),
      );
      await tester.pumpAndSettle();

      expect(find.text('client-location-screen'), findsOneWidget);
      expect(compose.tier, isNull);
    });

    testWidgets('a catalog with no wireId is not a usable default either', (
      tester,
    ) async {
      DevSeam.debugOverride(const DevSeamConfig(route: '/', homeTab: 'pending'));
      sl.registerSingleton<TierRepository>(const FakeTierRepository());
      final compose = ComposeRequestController(_NoopSubmission());
      sl.registerSingleton<ComposeRequestController>(compose);

      await tester.pumpWidget(_app(_router()));
      await tester.pumpAndSettle();

      await tester.tap(
        find.bySemanticsIdentifier('orders_create_request_button'),
      );
      await tester.pumpAndSettle();

      expect(find.text('client-location-screen'), findsOneWidget);
      expect(compose.tier, isNull);
    });

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
