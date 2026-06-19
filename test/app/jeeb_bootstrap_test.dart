import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/app/app.dart';
import 'package:jeeb_mobile/app/bootstrap.dart';
import 'package:jeeb_mobile/app/branded_splash.dart';
import 'package:jeeb_mobile/app/jeeb_bootstrap.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/observability/crash_reporter.dart';

/// JM-006 (D79/D85) — the branded splash has NO artificial display dwell.
///
/// An earlier change (FR-D1D2 / D1) pinned a fixed ~1.3 s floor so a first-time
/// user could register the logo. `20_GAP_MAP.md §splash` flags that exact
/// "cosmetic 1.3 s host" as the JM-006 gap, and the splash contract is now
/// "auto-route by session … no UI dwell" (`22_DESIGN_NOTES.md`). The production
/// host therefore swaps to [JeebApp] — and so to the session-aware
/// `_firstRunRedirect` — the instant [Bootstrap.minimal] resolves, with no floor
/// in front of the redirect. These tests pin that contract:
///   (a) the default (production) host carries NO hold and swaps as soon as
///       bootstrap is done (the splash never out-lives real init);
///   (b) an explicit debug/test opt-in hold still pins the splash deterministically
///       and swaps only once that hold elapses — so the test seam keeps working.
///
/// We drive [JeebBootstrap] with a PRE-RESOLVED [BootstrapResult] so bootstrap
/// is effectively instant, isolating the hold as the single variable. The
/// branded-splash host renders under its own [MaterialApp] whose `home` is
/// [BrandedSplash]; the app host is [JeebApp]. The `home` runtime type is the
/// deterministic discriminator (the splash's localized children are withheld
/// under the headless binding's async ARB delegate, so we assert on the host,
/// not the localized logo subtree — the logo render path itself is covered by
/// branded_splash_test.dart with a synchronous delegate).
void main() {
  late SharedPreferences prefs;
  late BootstrapResult result;

  /// True while the visible host is the branded-splash [MaterialApp].
  Finder splashHost() => find.byWidgetPredicate(
        (w) => w is MaterialApp && w.home is BrandedSplash,
      );

  setUp(() async {
    await GetIt.I.reset();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    const reporter = NoopCrashReporter();
    // The swap into JeebApp resolves cubits from GetIt, so register the same
    // runtime singletons bootstrap would (prefs + crash reporter).
    configureDependencies(sharedPreferences: prefs, crashReporter: reporter);
    result = BootstrapResult(preferences: prefs, crashReporter: reporter);
  });

  tearDown(() async {
    await GetIt.I.reset();
  });

  testWidgets(
      'production host (no hold) swaps to the app the instant bootstrap '
      'resolves — no artificial dwell in front of the redirect [JM-006/D79/D85]',
      (tester) async {
    // Production constructs `const JeebBootstrap()` (main.dart): no minSplashHold.
    await tester.pumpWidget(
      JeebBootstrap(
        bootstrapFuture: Future<BootstrapResult>.value(result),
      ),
    );

    // Frame 1 builds the FutureBuilder; frame 2 sees the resolved future and,
    // with no floor to wait out, swaps the splash out for the real app — which
    // mounts MaterialApp.router and lets _firstRunRedirect fire immediately.
    await tester.pump();
    await tester.pump();

    expect(
      splashHost(),
      findsNothing,
      reason: 'no production dwell — the splash must hand off the moment '
          'bootstrap is done, so the session-aware redirect is never delayed',
    );
    expect(find.byType(JeebApp), findsOneWidget);

    // Drain any short-lived timers the app schedules on mount.
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets(
      'an explicit debug/test opt-in hold pins the splash for its duration then '
      'swaps — the test seam still works (never a production default)',
      (tester) async {
    await tester.pumpWidget(
      JeebBootstrap(
        bootstrapFuture: Future<BootstrapResult>.value(result),
        minSplashHold: const Duration(milliseconds: 1300),
      ),
    );

    // Frame 1: bootstrap resolves on the first microtask, but the opt-in hold
    // is still pending — the branded-splash host must be the one on screen and
    // the app must NOT have mounted yet.
    await tester.pump();
    expect(splashHost(), findsOneWidget);
    expect(find.byType(JeebApp), findsNothing);

    // Well past bootstrap completion but BEFORE the hold: still the splash.
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      splashHost(),
      findsOneWidget,
      reason: 'an explicit opt-in hold must persist for its full duration, '
          'not just until bootstrap',
    );
    expect(find.byType(JeebApp), findsNothing);

    // Cross the hold: now (and only now) the splash gives way to the app.
    await tester.pump(const Duration(milliseconds: 700));
    expect(splashHost(), findsNothing);
    expect(find.byType(JeebApp), findsOneWidget);

    // Drain any short-lived timers the app schedules on mount.
    await tester.pump(const Duration(milliseconds: 300));
  });
}
