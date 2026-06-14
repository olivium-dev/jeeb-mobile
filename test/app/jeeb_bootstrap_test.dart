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

/// FR-D1D2 / D1 — the branded splash must stay on screen long enough for a
/// first-time user to actually SEE the Jeeb logo.
///
/// Codex QA's 5 s post-launch screenshot caught the walkthrough, not the splash:
/// [Bootstrap.minimal] resolves in < 250 ms, so without a display floor the
/// branded logo flashed for a single frame and vanished. These tests pin the
/// minimum-visible-hold contract: the branded-splash host (a) survives past
/// bootstrap completion until the floor elapses, then swaps to [JeebApp], and
/// (b) swaps immediately when the floor is collapsed to zero — proving the floor
/// is the only thing holding the splash, never bootstrap latency.
///
/// We drive [JeebBootstrap] with a PRE-RESOLVED [BootstrapResult] so bootstrap
/// is effectively instant, isolating the floor as the single variable. The
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
      'branded splash host stays on screen for the full min-hold then swaps to '
      'the app — even though bootstrap already resolved', (tester) async {
    await tester.pumpWidget(
      JeebBootstrap(
        bootstrapFuture: Future<BootstrapResult>.value(result),
        minSplashHold: const Duration(milliseconds: 1300),
      ),
    );

    // Frame 1: bootstrap resolves on the first microtask, but the floor is
    // still pending — the branded-splash host must be the one on screen and the
    // app must NOT have mounted yet.
    await tester.pump();
    expect(splashHost(), findsOneWidget);
    expect(find.byType(JeebApp), findsNothing);

    // Well past bootstrap completion but BEFORE the floor: still the splash.
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      splashHost(),
      findsOneWidget,
      reason: 'splash must persist for the full min-hold, not just bootstrap',
    );
    expect(find.byType(JeebApp), findsNothing);

    // Cross the floor: now (and only now) the splash gives way to the app.
    await tester.pump(const Duration(milliseconds: 700));
    expect(splashHost(), findsNothing);
    expect(find.byType(JeebApp), findsOneWidget);

    // Drain any short-lived timers the app schedules on mount.
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets(
      'a zero min-hold lets the splash swap to the app immediately '
      '(proves the floor — not bootstrap — was what held it)', (tester) async {
    await tester.pumpWidget(
      JeebBootstrap(
        bootstrapFuture: Future<BootstrapResult>.value(result),
        minSplashHold: Duration.zero,
      ),
    );

    // Frame 1 builds the FutureBuilder; frame 2 sees the resolved future + the
    // elapsed (zero) floor and swaps the splash out for the real app.
    await tester.pump();
    await tester.pump();

    expect(
      splashHost(),
      findsNothing,
      reason: 'with no display floor the splash must not linger past bootstrap',
    );
    expect(find.byType(JeebApp), findsOneWidget);

    // Drain any short-lived timers the app schedules on mount.
    await tester.pump(const Duration(milliseconds: 300));
  });
}
