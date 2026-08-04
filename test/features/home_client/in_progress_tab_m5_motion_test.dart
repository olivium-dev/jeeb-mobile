// M5 — R1 (Client home) animates nothing the board did not draw. The In
// Progress tab's wait is the kit skeleton's jBreathe, never a Lottie loop.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/motion/jeeb_motion.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/presentation/tabs/in_progress_tab.dart';

import '../../support/sync_app_localizations.dart';

/// Never resolves — pins the tab in [ClientHomeStatus.loading] with no pending
/// timer, so an animations-ENABLED test can hold the frame open.
class _HangingRepo implements ClientHomeRepository {
  @override
  Future<ClientHomeSnapshot> loadSnapshot() =>
      Completer<ClientHomeSnapshot>().future;
}

Widget _harness({required bool reduceMotion}) => MaterialApp(
      theme: AppTheme.midnight(),
      locale: const Locale('en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [SyncAppLocalizationsDelegate()],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(
        body: BlocProvider(
          create: (_) => ClientHomeCubit(
            repository: _HangingRepo(),
            greetingNameProvider: () => 'Sami',
          )..load(),
          child: const InProgressTab(),
        ),
      ),
    );

const Key _loadingKey = Key('in-progress-loading');

/// Every widget type name currently mounted — the only way to assert the
/// ABSENCE of a package type without importing the package.
Set<String> _mountedTypeNames(WidgetTester tester) => tester
    .allWidgets
    .map((Widget w) => w.runtimeType.toString())
    .toSet();

double _breatheOpacity(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byType(JBreathe),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

void main() {
  group('InProgressTab · M5 loading arm', () {
    testWidgets('the wait is the kit tile — no Lottie composition survives',
        (tester) async {
      await tester.pumpWidget(_harness(reduceMotion: true));
      await tester.pump();

      expect(find.byKey(_loadingKey), findsOneWidget);
      final block = tester.widget<JeebEmptyState>(find.byKey(_loadingKey));
      expect(block.status, JeebEmptyStateStatus.loading);
      // Same subject as the empty and error arms: the tab never changes tile.
      expect(block.variant, JeebEmptyStateVariant.parcel);
      expect(block.identifier, 'in_progress_loading_state');

      expect(
        _mountedTypeNames(tester).where((String n) => n.contains('Lottie')),
        isEmpty,
      );
    });

    testWidgets('its only motion is one jBreathe on the kit harness',
        (tester) async {
      await tester.pumpWidget(_harness(reduceMotion: true));
      await tester.pump();

      expect(find.byType(JBreathe), findsOneWidget);
      // Nothing else in the arm loops — one primitive, one harness.
      expect(find.byType(JMotionLoop), findsOneWidget);

      final JBreathe breathe = tester.widget<JBreathe>(find.byType(JBreathe));
      expect(breathe.duration, JeebMotion.breatheDuration);
      expect(breathe.duration, const Duration(milliseconds: 2600));
      // A lone skeleton has nothing to stagger against.
      expect(breathe.delay, Duration.zero);

      final JMotionLoop loop =
          tester.widget<JMotionLoop>(find.byType(JMotionLoop));
      expect(loop.restPhase, 0);
    });

    testWidgets('reduce motion parks it on the .45 rest frame and settles',
        (tester) async {
      await tester.pumpWidget(_harness(reduceMotion: true));
      // Terminates only because JMotionLoop stopped the ticker — the contract
      // the hand-rolled Lottie loop did not carry.
      await tester.pumpAndSettle();

      expect(_breatheOpacity(tester), closeTo(0.45, 0.001));
    });

    testWidgets('with motion on it breathes .45 → 1 → .45 across 2.6s',
        (tester) async {
      await tester.pumpWidget(_harness(reduceMotion: false));
      await tester.pump();

      expect(_breatheOpacity(tester), closeTo(0.45, 0.001));
      // Half the period is the peak of a symmetric two-leg breath.
      await tester.pump(const Duration(milliseconds: 1300));
      expect(_breatheOpacity(tester), closeTo(1.0, 0.001));
      // A full period is back at rest — this is what pins the 2.6s.
      await tester.pump(const Duration(milliseconds: 1300));
      expect(_breatheOpacity(tester), closeTo(0.45, 0.001));
    });
  });
}
