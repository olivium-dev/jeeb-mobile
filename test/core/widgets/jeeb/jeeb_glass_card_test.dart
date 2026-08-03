// Expected values come from docs/redesign-midnight/01-TOKEN-SHEET.md §4/§5/§7:
// rest glass is white 7% + 12% border at r18 with NO blur; the hero capsule is
// white 10% + 16% border, pill radius, one real BackdropFilter at sigma 10.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_glass_card.dart';

const Color _glassFill = Color(0x12FFFFFF); // white 7%
const Color _glassFillEmphasis = Color(0x1AFFFFFF); // white 10%
const Color _glassFillPressed = Color(0x24FFFFFF); // white 14%
const Color _glassBorder = Color(0x1FFFFFFF); // white 12%
const Color _glassBorderStrong = Color(0x29FFFFFF); // white 16%

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget widget, {
    TextDirection direction = TextDirection.ltr,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.midnight(),
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Center(child: SizedBox(width: 320, child: widget)),
          ),
        ),
      ),
    );
  }

  Iterable<BoxDecoration> decorationsOf(WidgetTester tester, Finder root) {
    return tester
        .widgetList<DecoratedBox>(
          find.descendant(of: root, matching: find.byType(DecoratedBox)),
        )
        .map((DecoratedBox box) => box.decoration as BoxDecoration);
  }

  BoxDecoration glassOf(WidgetTester tester, Finder root) {
    return decorationsOf(tester, root)
        .firstWhere((BoxDecoration d) => d.color != null);
  }

  List<BoxShadow> shadowsOf(WidgetTester tester, Finder root) {
    return decorationsOf(tester, root)
        .expand((BoxDecoration d) => d.boxShadow ?? const <BoxShadow>[])
        .toList();
  }

  List<Color> paintedColorsOf(WidgetTester tester, Finder root) {
    final List<Color> colors = <Color>[];
    for (final BoxDecoration d in decorationsOf(tester, root)) {
      if (d.color != null) colors.add(d.color!);
      final BoxBorder? border = d.border;
      if (border is Border) colors.add(border.top.color);
      colors.addAll((d.boxShadow ?? const <BoxShadow>[]).map((s) => s.color));
    }
    for (final InkWell ink in tester.widgetList<InkWell>(
      find.descendant(of: root, matching: find.byType(InkWell)),
    )) {
      if (ink.splashColor != null) colors.add(ink.splashColor!);
      if (ink.highlightColor != null) colors.add(ink.highlightColor!);
    }
    return colors;
  }

  group('JeebGlassCard — rest glass (§4)', () {
    testWidgets('fills glassFill behind a 1px glassBorder at radius lg',
        (WidgetTester tester) async {
      await pump(tester, const JeebGlassCard(child: SizedBox(height: 40)));

      final BoxDecoration glass = glassOf(tester, find.byType(JeebGlassCard));
      expect(glass.color, _glassFill);
      expect((glass.border! as Border).top.color, _glassBorder);
      expect((glass.border! as Border).top.width, 1);
      expect(glass.borderRadius, BorderRadius.circular(JeebRadii.lg));
      expect(JeebRadii.lg, 18);
    });

    testWidgets('spends no blur — translucency is pre-baked',
        (WidgetTester tester) async {
      await pump(tester, const JeebGlassCard(child: SizedBox(height: 40)));

      expect(
        find.descendant(
          of: find.byType(JeebGlassCard),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
    });

    testWidgets('carries no shadow at rest', (WidgetTester tester) async {
      await pump(tester, const JeebGlassCard(child: SizedBox(height: 40)));

      expect(shadowsOf(tester, find.byType(JeebGlassCard)), isEmpty);
      expect(JeebGlassCard.noShadow, isEmpty);
    });

    testWidgets('clips its content to the same radius',
        (WidgetTester tester) async {
      await pump(tester, const JeebGlassCard(child: SizedBox(height: 40)));

      final ClipRRect clip = tester.widget<ClipRRect>(
        find
            .descendant(
              of: find.byType(JeebGlassCard),
              matching: find.byType(ClipRRect),
            )
            .first,
      );
      expect(clip.borderRadius, BorderRadius.circular(JeebRadii.lg));
    });

    testWidgets('pads 16 all round by default and imposes no min height',
        (WidgetTester tester) async {
      await pump(tester, const JeebGlassCard(child: SizedBox(height: 4)));

      final Padding padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(JeebGlassCard),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, const EdgeInsets.all(16));
      expect(
        tester.getSize(find.byType(JeebGlassCard)).height,
        4 + 32,
      );
    });

    testWidgets('takes any rung of the §5 ladder',
        (WidgetTester tester) async {
      await pump(
        tester,
        const JeebGlassCard(
          radius: JeebRadii.sheet,
          child: SizedBox(height: 40),
        ),
      );

      expect(
        glassOf(tester, find.byType(JeebGlassCard)).borderRadius,
        BorderRadius.circular(26),
      );
    });
  });

  group('JeebGlassCapsule — hero glass (§4)', () {
    testWidgets('fills glassFillEmphasis behind a 1px glassBorderStrong at pill',
        (WidgetTester tester) async {
      await pump(tester, const JeebGlassCapsule(child: SizedBox(height: 54)));

      final BoxDecoration glass = glassOf(tester, find.byType(JeebGlassCapsule));
      expect(glass.color, _glassFillEmphasis);
      expect((glass.border! as Border).top.color, _glassBorderStrong);
      expect((glass.border! as Border).top.width, 1);
      expect(glass.borderRadius, BorderRadius.circular(JeebRadii.pill));
      expect(JeebRadii.pill, 999);
    });

    testWidgets('spends exactly one real BackdropFilter at sigma 10',
        (WidgetTester tester) async {
      await pump(tester, const JeebGlassCapsule(child: SizedBox(height: 54)));

      final Finder filters = find.descendant(
        of: find.byType(JeebGlassCapsule),
        matching: find.byType(BackdropFilter),
      );
      expect(filters, findsOneWidget);
      expect(
        tester.widget<BackdropFilter>(filters).filter.toString(),
        contains('10.0, 10.0'),
      );
      expect(JeebGlassCapsule.standardBlur, 10);
      expect(JeebGlassCapsule.softBlur, 8);
      expect(JeebGlassCapsule.heroBlur, 12);
    });

    testWidgets('honours the capsule rung and the hero blur step',
        (WidgetTester tester) async {
      await pump(
        tester,
        const JeebGlassCapsule(
          radius: JeebRadii.capsule,
          blurSigma: JeebGlassCapsule.heroBlur,
          child: SizedBox(height: 54),
        ),
      );

      expect(
        glassOf(tester, find.byType(JeebGlassCapsule)).borderRadius,
        BorderRadius.circular(40),
      );
      expect(
        tester
            .widget<BackdropFilter>(
              find.descendant(
                of: find.byType(JeebGlassCapsule),
                matching: find.byType(BackdropFilter),
              ),
            )
            .filter
            .toString(),
        contains('12.0, 12.0'),
      );
    });

    testWidgets('lifts on floatNav, outside the clip',
        (WidgetTester tester) async {
      await pump(tester, const JeebGlassCapsule(child: SizedBox(height: 54)));

      final List<BoxShadow> shadows =
          shadowsOf(tester, find.byType(JeebGlassCapsule));
      expect(shadows, hasLength(1));
      expect(shadows.single.color, const Color.fromRGBO(0, 0, 0, 0.40));
      expect(shadows.single.offset, const Offset(0, 20));
      expect(shadows.single.blurRadius, 46);
    });

    testWidgets('can drop the lift', (WidgetTester tester) async {
      await pump(
        tester,
        const JeebGlassCapsule(
          shadow: JeebGlassCapsule.noShadow,
          child: SizedBox(height: 54),
        ),
      );

      expect(shadowsOf(tester, find.byType(JeebGlassCapsule)), isEmpty);
    });

    testWidgets('pads the board capsule inset, mirrored under RTL',
        (WidgetTester tester) async {
      await pump(
        tester,
        const JeebGlassCapsule(child: SizedBox(height: 54)),
        direction: TextDirection.rtl,
      );

      final Padding padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(JeebGlassCapsule),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(
        padding.padding,
        const EdgeInsetsDirectional.fromSTEB(10, 10, 18, 10),
      );
      expect(
        padding.padding.resolve(TextDirection.rtl),
        const EdgeInsets.fromLTRB(18, 10, 10, 10),
      );
    });
  });

  group('tap + semantics', () {
    testWidgets('card taps with a white-alpha glass splash',
        (WidgetTester tester) async {
      int taps = 0;
      await pump(
        tester,
        JeebGlassCard(
          onTap: () => taps++,
          child: const SizedBox(height: 40),
        ),
      );

      final InkWell ink = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(JeebGlassCard),
          matching: find.byType(InkWell),
        ),
      );
      expect(ink.splashColor, _glassFillPressed);
      expect(ink.highlightColor, _glassFill);

      await tester.tap(find.byType(JeebGlassCard));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('capsule taps with the same splash',
        (WidgetTester tester) async {
      int taps = 0;
      await pump(
        tester,
        JeebGlassCapsule(
          onTap: () => taps++,
          child: const SizedBox(height: 54),
        ),
      );

      final InkWell ink = tester.widget<InkWell>(
        find.descendant(
          of: find.byType(JeebGlassCapsule),
          matching: find.byType(InkWell),
        ),
      );
      expect(ink.splashColor, _glassFillPressed);
      expect(ink.highlightColor, _glassFill);

      await tester.tap(find.byType(JeebGlassCapsule));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('is inert and un-wrapped without onTap',
        (WidgetTester tester) async {
      await pump(tester, const JeebGlassCard(child: SizedBox(height: 40)));

      expect(
        find.descendant(
          of: find.byType(JeebGlassCard),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(JeebGlassCard),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
    });

    testWidgets('publishes identifier, label and hint',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(
        tester,
        const JeebGlassCapsule(
          identifier: 'glassCapsule',
          semanticLabel: 'Hold to talk',
          semanticHint: 'or tap to type',
          child: SizedBox(height: 54),
        ),
      );

      expect(find.bySemanticsIdentifier('glassCapsule'), findsOneWidget);
      expect(find.bySemanticsLabel('Hold to talk'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('nested child ids survive the card node',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pump(
        tester,
        JeebGlassCard(
          identifier: 'glassCard',
          onTap: () {},
          child: Semantics(
            identifier: 'glassCardChild',
            child: const SizedBox(height: 40),
          ),
        ),
      );

      expect(find.bySemanticsIdentifier('glassCard'), findsOneWidget);
      expect(find.bySemanticsIdentifier('glassCardChild'), findsOneWidget);
      handle.dispose();
    });
  });

  group('orange budget (§2.2 of the master plan)', () {
    testWidgets('both primitives paint achromatic ink only',
        (WidgetTester tester) async {
      await pump(
        tester,
        Column(
          children: <Widget>[
            JeebGlassCard(onTap: () {}, child: const SizedBox(height: 40)),
            JeebGlassCapsule(onTap: () {}, child: const SizedBox(height: 54)),
          ],
        ),
      );

      for (final Finder root in <Finder>[
        find.byType(JeebGlassCard),
        find.byType(JeebGlassCapsule),
      ]) {
        final List<Color> colors = paintedColorsOf(tester, root);
        expect(colors, isNotEmpty);
        for (final Color color in colors) {
          expect(
            <double>[color.r, color.g, color.b],
            <double>[color.r, color.r, color.r],
            reason: '$color is tinted — glass spends no orange',
          );
        }
      }
    });
  });
}
