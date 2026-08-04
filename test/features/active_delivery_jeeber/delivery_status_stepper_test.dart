import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_stepper.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/widgets/delivery_status_stepper.dart';

import '../../support/sync_app_localizations.dart';

const _labels = <JeeberDeliveryStatus, String>{
  JeeberDeliveryStatus.ordered: 'Ordered',
  JeeberDeliveryStatus.picked: 'Picked',
  JeeberDeliveryStatus.inTransit: 'In transit',
  JeeberDeliveryStatus.atDoor: 'At door',
  JeeberDeliveryStatus.done: 'Done',
};

void main() {
  for (final current in jeeberDeliveryProgressStages) {
    testWidgets(
      '${current.name} renders all stages, semantics, connectors, and CTA',
      (tester) async {
        var advances = 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: const [SyncAppLocalizationsDelegate()],
            home: Scaffold(
              body: SizedBox(
                width: 390,
                child: DeliveryStatusStepper(
                  currentStatus: current,
                  isTransitioning: false,
                  onAdvance: () => advances += 1,
                ),
              ),
            ),
          ),
        );

        expect(find.byType(JeebStepper), findsOneWidget);
        for (final stage in jeeberDeliveryProgressStages) {
          final index = stage.index;
          final state = index < current.index
              ? 'completed'
              : index == current.index
              ? 'current'
              : 'upcoming';
          final stateLabel = index < current.index
              ? 'Completed'
              : index == current.index
              ? 'Current'
              : 'Upcoming';
          final identifier =
              'active_delivery_stage_${stage.name.toLowerCase()}';

          expect(find.text(_labels[stage]!), findsOneWidget);
          expect(find.bySemanticsIdentifier(identifier), findsOneWidget);
          expect(
            find.bySemanticsLabel('${_labels[stage]}, $stateLabel'),
            findsOneWidget,
          );
          expect(
            find.byKey(ValueKey<String>('${identifier}_$state')),
            findsOneWidget,
          );
        }

        final advanceCta = find.bySemanticsIdentifier(
          'mark_delivered_advance_cta',
        );
        final shouldShowAdvance =
            current == JeeberDeliveryStatus.ordered ||
            current == JeeberDeliveryStatus.picked;
        expect(advanceCta, shouldShowAdvance ? findsOneWidget : findsNothing);
        if (shouldShowAdvance) {
          final expectedLabel = current == JeeberDeliveryStatus.ordered
              ? 'Mark as Picked'
              : 'Mark as In Transit';
          expect(find.text(expectedLabel), findsOneWidget);
          await tester.tap(advanceCta);
          expect(advances, 1);
        }
      },
    );
  }

  group('M2-14 · passed bars carry the washed ink (Q-023)', () {
    late ThemeData theme;

    Future<void> pumpAt(WidgetTester tester, JeeberDeliveryStatus current) {
      theme = AppTheme.light();
      return tester.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [SyncAppLocalizationsDelegate()],
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: DeliveryStatusStepper(
                currentStatus: current,
                isTransitioning: false,
                onAdvance: () {},
              ),
            ),
          ),
        ),
      );
    }

    BoxDecoration segmentAt(WidgetTester tester, String identifier) {
      final box = tester.widget<DecoratedBox>(
        find.byKey(ValueKey<String>('active_delivery_stage_$identifier')),
      );
      return box.decoration as BoxDecoration;
    }

    testWidgets('every passed segment is the washed white, not periwinkle', (
      tester,
    ) async {
      await pumpAt(tester, JeeberDeliveryStatus.inTransit);

      for (final passed in <String>['ordered_completed', 'picked_completed']) {
        final decoration = segmentAt(tester, passed);
        expect(decoration.color, JeebStepper.washedInk, reason: passed);
        // The value this replaced. Pinned by identity so a silent revert to
        // `doneInk: periwinkle` fails here rather than only in the golden.
        expect(decoration.color, isNot(theme.colorScheme.secondary));
      }
    });

    testWidgets('the wash is bars-only: the active segment keeps accent+glow', (
      tester,
    ) async {
      await pumpAt(tester, JeeberDeliveryStatus.inTransit);

      final active = segmentAt(tester, 'intransit_current');
      expect(active.color, isNot(JeebStepper.washedInk));
      expect(active.boxShadow, JeebStepper.barGlow);
      expect(segmentAt(tester, 'ordered_completed').boxShadow, isNull);
    });

    testWidgets('upcoming segments stay pending glass, never washed', (
      tester,
    ) async {
      await pumpAt(tester, JeeberDeliveryStatus.ordered);

      expect(
        segmentAt(tester, 'picked_upcoming').color,
        isNot(JeebStepper.washedInk),
      );
      // Nothing is passed at the first stage, so no segment carries the wash.
      expect(
        find.byKey(
          const ValueKey<String>('active_delivery_stage_ordered_completed'),
        ),
        findsNothing,
      );
    });
  });

  for (final terminal in <JeeberDeliveryStatus>[
    JeeberDeliveryStatus.cancelled,
    JeeberDeliveryStatus.expired,
  ]) {
    testWidgets('${terminal.name} never renders a completed stepper', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [SyncAppLocalizationsDelegate()],
          home: Scaffold(
            body: DeliveryStatusStepper(
              currentStatus: terminal,
              isTransitioning: false,
              onAdvance: () {},
            ),
          ),
        ),
      );

      expect(find.byType(JeebStepper), findsNothing);
      expect(
        find.bySemanticsIdentifier('active_delivery_stage_done'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('mark_delivered_advance_cta'),
        findsNothing,
      );
    });
  }
}
