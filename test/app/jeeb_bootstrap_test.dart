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
/// An earlier change (FR-D1D2 / D1) pinned a fixed ~1.3 s floor so a first-time
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
