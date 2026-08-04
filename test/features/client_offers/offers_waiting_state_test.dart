// E2 · the waiting block is the kit's radar, not the E1 stand-in it shipped as.
//
// FAIL-WITHOUT: the E1 waveform "ears" and twinkles do not belong on E2, the
// rings are three orange `jArcPulse` on the 1 / .5 / 0 ladder, and the three
// jeeber discs carry K / N / R (motion notes §E2).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/motion/jeeb_motion.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offers_waiting_state.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1200, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  Widget harness(
    Widget child, {
    Locale locale = const Locale('en'),
    bool disableAnimations = false,
  }) => MaterialApp(
    theme: AppTheme.midnight(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: Scaffold(
          body: Center(
            // Wide: the test font is a fixed-width block face, so the board's
            // 380dp block would overflow the countdown chip on copy alone.
            child: SizedBox(
              width: 900,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      ),
    ),
  );

  Finder inBlock(Type type) => find.descendant(
    of: find.byType(JeebEmptyState),
    matching: find.byType(type),
  );

  const Widget waiting = OffersWaitingState(
    blockKey: Key('offer-empty-state'),
    windowRemaining: Duration(minutes: 4, seconds: 12),
  );

  group('E2 · the waiting radar', () {
    testWidgets('composes the radar variant, never E1', (tester) async {
      await tester.pumpWidget(harness(waiting));
      await tester.pump();

      expect(
        tester.widget<JeebEmptyState>(find.byType(JeebEmptyState)).variant,
        JeebEmptyStateVariant.radar,
      );
    });

    testWidgets('the three jeeber discs are K / N / R', (tester) async {
      await tester.pumpWidget(harness(waiting));
      await tester.pump();

      for (final String initial in const <String>['K', 'N', 'R']) {
        expect(
          find.descendant(
            of: find.byType(JeebEmptyState),
            matching: find.text(initial),
          ),
          findsOneWidget,
          reason: 'disc "$initial" is missing',
        );
      }
      // The stand-in's uniform person glyphs are gone with them.
      expect(inBlock(Icon), findsNothing);
    });

    testWidgets('no E1 waveform ears and no twinkles on E2', (tester) async {
      await tester.pumpWidget(harness(waiting));
      await tester.pump();

      expect(inBlock(JWaveBar), findsNothing);
      expect(inBlock(JTwinkle), findsNothing);
      expect(inBlock(JDashedPath), findsNothing);
      expect(inBlock(JFloat), findsNothing);
    });

    testWidgets('three arc-pulse rings on the 3s · 1s / .5s / 0 ladder', (
      tester,
    ) async {
      await tester.pumpWidget(harness(waiting));
      await tester.pump();

      final List<JArcPulse> rings = tester
          .widgetList<JArcPulse>(inBlock(JArcPulse))
          .toList();
      expect(rings, hasLength(3));
      expect(
        rings.map((JArcPulse r) => r.duration),
        everyElement(const Duration(seconds: 3)),
      );
      expect(rings.map((JArcPulse r) => r.delay).toList(), <Duration>[
        const Duration(seconds: 1),
        const Duration(milliseconds: 500),
        Duration.zero,
      ]);
    });

    testWidgets('the four breathing elements: centre glow + three discs', (
      tester,
    ) async {
      await tester.pumpWidget(harness(waiting));
      await tester.pump();

      final List<Duration> delays = tester
          .widgetList<JBreathe>(inBlock(JBreathe))
          .map((JBreathe b) => b.delay)
          .toList();
      expect(delays, <Duration>[
        Duration.zero,
        Duration.zero,
        const Duration(milliseconds: 800),
        const Duration(milliseconds: 1600),
      ]);
    });

    testWidgets('the waiting core is the kit\'s, not a local disc', (
      tester,
    ) async {
      await tester.pumpWidget(harness(waiting));
      await tester.pump();

      expect(
        tester.widget<JeebEmptyState>(find.byType(JeebEmptyState)).center,
        isNull,
      );
      expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
      expect(find.text('Broadcasting to nearby Jeebers…'), findsOneWidget);
      expect(find.text('Window closes in 4:12'), findsOneWidget);
    });

    testWidgets('survives reduce motion and RTL', (tester) async {
      await tester.pumpWidget(harness(waiting, disableAnimations: true));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        harness(waiting, locale: const Locale('ar'), disableAnimations: true),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('K'), findsOneWidget);
    });
  });

  group('E2 · the shared loading and error forms', () {
    testWidgets('loading withholds the countdown chip', (tester) async {
      await tester.pumpWidget(
        harness(
          const OffersWaitingState(
            blockKey: Key('offer-loading-state'),
            status: JeebEmptyStateStatus.loading,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(JeebEmptyState), findsOneWidget);
      expect(find.textContaining('Window closes'), findsNothing);
      expect(find.text('Broadcasting to nearby Jeebers…'), findsOneWidget);
    });

    testWidgets('the failure form swaps the core for the no-signal disc', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const OffersWaitingState(
            blockKey: Key('offer-load-error'),
            status: JeebEmptyStateStatus.error,
            headline: "Couldn't load offers",
            action: Text('Retry'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.text("Couldn't load offers"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // The radar around it stays — only the centre changed.
      expect(inBlock(JArcPulse), findsNWidgets(3));
      expect(find.text('K'), findsOneWidget);
    });
  });
}
