// The floating mic's idle "hold me" ring.
//
// The visible caption that taught press-and-hold was deleted, so this ring is
// the surviving sighted affordance: it must be ON at rest, OFF while capturing
// (a travelling ring is the RECORDING cue, `mic_cluster.dart`), and it must pin
// to a still — scheduling no frames at all — under reduce motion.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_mic_hero.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_state.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/presentation/client_home_screen.dart';
import 'package:jeeb_mobile/features/shell/tab_visibility.dart';

import '../../support/sync_app_localizations.dart';

final Finder _ring = find.byKey(const Key('client-home-mic-idle-ring'));

Widget _harness({required bool reduceMotion, bool visible = true}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    // The shell's own shape: every tab stays mounted, built and laid out.
    home: Scaffold(
      body: IndexedStack(
        index: visible ? 0 : 1,
        children: <Widget>[
          TabVisibility(
            isVisible: visible,
            child: BlocProvider(
              create: (_) => ClientHomeCubit(
                repository: InMemoryClientHomeRepository(latency: Duration.zero),
                greetingNameProvider: () => 'Lina',
              ),
              child: ClientHomeScreen(
                initialTab: ClientHomeTab.pendingRequests,
                onCreateRequest: (_) {},
              ),
            ),
          ),
          const SizedBox.shrink(),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('the idle mic wears the hold ring; a held mic does not', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(reduceMotion: true));
    await tester.pumpAndSettle();

    expect(_ring, findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(JeebMicHero)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }

    expect(
      _ring,
      findsNothing,
      reason: 'an idle cue left on while capturing would say "listening" twice',
    );

    await gesture.up();
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  });

  testWidgets('reduce motion pins the idle motion and schedules no frames', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(reduceMotion: true));
    await tester.pumpAndSettle();

    expect(_ring, findsOneWidget);
    expect(
      tester.binding.transientCallbackCount,
      0,
      reason: 'a ticker still running under reduce motion is the blocker',
    );
  });

  testWidgets('without reduce motion the idle motion actually runs', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(reduceMotion: false));
    // Never pumpAndSettle here: the loops are infinite by contract.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(_ring, findsOneWidget);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('the pantomime presses the disc IN and DWELLS there', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(reduceMotion: false));
    await tester.pump();

    final double rest = tester.getRect(find.byType(JeebMicHero)).width;
    await tester.pump(const Duration(milliseconds: 2500));
    final double held = tester.getRect(find.byType(JeebMicHero)).width;
    expect(
      held,
      lessThan(rest - 1),
      reason: 'a drift below the perceptual floor teaches nobody to hold',
    );

    // The dwell is the whole cue: it is what a hold has and a tap does not.
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.getRect(find.byType(JeebMicHero)).width, closeTo(held, 0.01));
  });

  testWidgets('an off-screen tab schedules no frames at all', (tester) async {
    await tester.pumpWidget(_harness(reduceMotion: false, visible: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.byType(JeebMicHero, skipOffstage: false),
      findsOneWidget,
      reason: 'the tab is still mounted — only its frames are meant to stop',
    );
    expect(
      tester.binding.transientCallbackCount,
      0,
      reason: 'an IndexedStack keeps this tab mounted behind Wallet and Chat',
    );
  });
}
