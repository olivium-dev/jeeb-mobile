import 'dart:async';

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

/// The app initializes underneath one persistent splash. The only production
/// visual floor is the logo's one-shot entrance animation.
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
    'production mounts the app immediately, then removes one splash after '
    'the entrance and fade',
    (tester) async {
      await tester.pumpWidget(
        JeebBootstrap(bootstrapFuture: Future<BootstrapResult>.value(result)),
      );

      await tester.pump();
      await tester.pump();

      expect(find.byType(JeebApp), findsOneWidget);
      expect(
        splashHost(),
        findsOneWidget,
        reason: 'the app mounts immediately while the outgoing splash fades',
      );

      await tester.pump(const Duration(milliseconds: 449));
      expect(splashHost(), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 351));
      await tester.pump();
      expect(splashHost(), findsNothing);

      // Drain any short-lived timers the app schedules on mount.
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  testWidgets('bootstrap completion preserves the single splash element', (
    tester,
  ) async {
    final bootstrap = Completer<BootstrapResult>();
    await tester.pumpWidget(JeebBootstrap(bootstrapFuture: bootstrap.future));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final splashElementBefore = tester.element(
      find.byKey(const ValueKey<String>('splash')),
    );
    bootstrap.complete(result);
    await tester.pump();
    await tester.pump();

    expect(find.byType(JeebApp), findsOneWidget);
    expect(splashHost(), findsOneWidget);
    expect(
      tester.element(find.byKey(const ValueKey<String>('splash'))),
      same(splashElementBefore),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 351));
    await tester.pump();
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

      await tester.pump();
      expect(splashHost(), findsOneWidget);
      expect(find.byType(JeebApp), findsOneWidget);

      // Well past bootstrap completion but BEFORE the hold: still the splash.
      await tester.pump(const Duration(milliseconds: 800));
      expect(
        splashHost(),
        findsOneWidget,
        reason:
            'an explicit opt-in hold must persist for its full duration, '
            'not just until bootstrap',
      );
      expect(find.byType(JeebApp), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(JeebApp), findsOneWidget);
      expect(splashHost(), findsOneWidget);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 351));
      await tester.pump();
      expect(splashHost(), findsNothing);

      // Drain any short-lived timers the app schedules on mount.
      await tester.pump(const Duration(milliseconds: 300));
    },
  );
}
