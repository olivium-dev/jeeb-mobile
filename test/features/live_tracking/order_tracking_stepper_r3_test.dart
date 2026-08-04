// M2-08 R3 — the order-tracking stepper is the KIT bar form with R3's orange
// fill-through, not a feature-side repaint of it.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_stepper.dart';
import 'package:jeeb_mobile/features/live_tracking/presentation/widgets/order_tracking_stepper.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const List<String> _stepIds = <String>[
  'tracking_step_ordered',
  'tracking_step_picked',
  'tracking_step_in_transit',
  'tracking_step_delivered',
];

Color get _accent =>
    (AppTheme.midnight().extension<JeebColorRoles>() ??
            JeebColorRoles.midnight())
        .accent;

JeebSemanticColors get _semantics =>
    AppTheme.midnight().extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();

Widget _wrap(Widget child, {TextDirection direction = TextDirection.ltr}) =>
    MaterialApp(
      theme: AppTheme.midnight(),
      locale: Locale(direction == TextDirection.rtl ? 'ar' : 'en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Center(child: SizedBox(width: 360, child: child)),
      ),
    );

Finder get _bars => find.descendant(
      of: find.byType(JeebStepper),
      matching: find.byType(DecoratedBox),
    );

BoxDecoration _barAt(WidgetTester tester, int index) =>
    tester.widgetList<DecoratedBox>(_bars).elementAt(index).decoration
        as BoxDecoration;

List<Text> _labels(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).toList();

void main() {
  group('R3 bar row is driven by the kit, not repainted', () {
    testWidgets('mounts JeebStepper.bars with doneInk.accent and 4 segments',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const OrderTrackingStepper(currentStep: 2)),
      );

      final JeebStepper stepper = tester.widget<JeebStepper>(
        find.byType(JeebStepper),
      );
      expect(stepper.doneInk, JeebStepperDoneInk.accent);
      expect(stepper.stepCount, 4);
      expect(stepper.currentIndex, 2);
      expect(_bars, findsNWidgets(4));
    });

    testWidgets('passed AND active segments are orange, pending is glass',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const OrderTrackingStepper(currentStep: 2)),
      );

      expect(_barAt(tester, 0).color, _accent);
      expect(_barAt(tester, 1).color, _accent);
      expect(_barAt(tester, 2).color, _accent);
      expect(_barAt(tester, 3).color, _semantics.glassFillPressed);
      expect(_barAt(tester, 3).color, isNot(_accent));
    });

    testWidgets('the glow sits on the ACTIVE index only',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const OrderTrackingStepper(currentStep: 1)),
      );

      expect(_barAt(tester, 0).boxShadow, isNull);
      expect(_barAt(tester, 1).boxShadow, JeebStepper.barGlow);
      expect(_barAt(tester, 2).boxShadow, isNull);
      expect(_barAt(tester, 3).boxShadow, isNull);
    });

    testWidgets('the last step fills every segment orange',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const OrderTrackingStepper(currentStep: 3)),
      );

      for (int i = 0; i < 4; i++) {
        expect(_barAt(tester, i).color, _accent, reason: 'segment $i');
      }
      expect(_barAt(tester, 3).boxShadow, JeebStepper.barGlow);
    });

    testWidgets('R3 is STATIC — no ticker, no frame-to-frame drift',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const OrderTrackingStepper(currentStep: 2)),
      );

      final BoxDecoration first = _barAt(tester, 2);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.binding.transientCallbackCount, 0);
      expect(_barAt(tester, 2).boxShadow, first.boxShadow);
      expect(_barAt(tester, 2).color, first.color);
      expect(
        find.descendant(
          of: find.byType(JeebStepper),
          matching: find.byType(AnimatedBuilder),
        ),
        findsNothing,
      );
    });

    testWidgets('RTL mirrors the run: step 0 sits at the visual end',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const OrderTrackingStepper(currentStep: 1),
          direction: TextDirection.rtl,
        ),
      );

      expect(
        tester.getCenter(_bars.at(0)).dx,
        greaterThan(tester.getCenter(_bars.at(3)).dx),
      );
      expect(_barAt(tester, 0).color, _accent);
      expect(_barAt(tester, 3).color, _semantics.glassFillPressed);
    });
  });

  group('label row survives the adoption', () {
    testWidgets('spaceBetween, active accent/w800, the rest mutedText/w700',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const OrderTrackingStepper(currentStep: 2)),
      );

      final Row labelRow = tester.widget<Row>(
        find.ancestor(
          of: find.byType(Text).first,
          matching: find.byType(Row),
        ),
      );
      expect(labelRow.mainAxisAlignment, MainAxisAlignment.spaceBetween);

      final List<Text> texts = _labels(tester);
      expect(texts, hasLength(4));
      for (int i = 0; i < 4; i++) {
        final TextStyle style = texts[i].style!;
        expect(style.color, i == 2 ? _accent : _semantics.mutedText);
        expect(
          style.fontWeight,
          i == 2 ? FontWeight.w800 : FontWeight.w700,
          reason: 'label $i',
        );
      }
    });

    testWidgets('the four frozen identifiers keep value + selected',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const OrderTrackingStepper(currentStep: 2)),
      );

      expect(find.bySemanticsIdentifier('tracking_stepper'), findsOneWidget);
      for (int i = 0; i < 4; i++) {
        final SemanticsNode node = tester.getSemantics(
          find.bySemanticsIdentifier(_stepIds[i]),
        );
        expect(node.identifier, _stepIds[i]);
        expect(node.value, isNotEmpty);
        expect(
          node.flagsCollection.isSelected,
          i == 2 ? Tristate.isTrue : Tristate.isFalse,
          reason: 'selected must report in both polarities on ${_stepIds[i]}',
        );
      }
      handle.dispose();
    });

    testWidgets('atDoor relabels step 3 without touching its identifier',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const OrderTrackingStepper(currentStep: 2, atDoor: true)),
      );

      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsIdentifier('tracking_step_in_transit'),
      );
      expect(node.value, 'At Door');
      expect(find.bySemanticsIdentifier('tracking_step_at_door'), findsNothing);
      handle.dispose();
    });
  });
}
