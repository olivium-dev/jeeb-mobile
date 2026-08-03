import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_navy_surface_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_surface_tone.dart';

import 'jeeb_card_test_harness.dart';

/// Gates for the scope that makes the on-navy re-tone structural.
///
/// FAIL-WITHOUT: without the fallback a chip outside a card null-crashes;
/// without the nearest-ancestor wins rule a navy strip nested in a white card
/// would paint white-on-white chips.
void main() {
  final ColorScheme scheme = AppTheme.light().colorScheme;

  testWidgets('falls back to the light tone with no card above',
      (tester) async {
    late JeebSurfaceToneData tone;
    await tester.pumpWidget(
      wrapCard(ToneProbe(onTone: (JeebSurfaceToneData t) => tone = t)),
    );

    expect(tone.kind, JeebSurfaceKind.light);
    expect(tone.chipFill, scheme.surfaceContainerHigh);
  });

  testWidgets('survives a bare ThemeData.light() harness', (tester) async {
    // `wrapForTest` themes with ThemeData.light(), which registers neither
    // JeebSemanticColors nor JeebColorRoles. A `!` read here would crash every
    // screen test in the app.
    late JeebSurfaceToneData tone;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: ToneProbe(onTone: (JeebSurfaceToneData t) => tone = t),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tone.kind, JeebSurfaceKind.light);
  });

  testWidgets('the nearest enclosing card wins', (tester) async {
    late JeebSurfaceToneData outer;
    late JeebSurfaceToneData inner;
    await tester.pumpWidget(
      wrapCard(
        JeebOutlinedCard(
          child: Column(
            children: <Widget>[
              ToneProbe(onTone: (JeebSurfaceToneData t) => outer = t),
              JeebNavySurfaceCard(
                child: ToneProbe(onTone: (JeebSurfaceToneData t) => inner = t),
              ),
            ],
          ),
        ),
      ),
    );

    expect(outer.onNavy, isFalse);
    expect(inner.onNavy, isTrue);
  });

  test('tone data compares by value so updateShouldNotify is honest', () {
    const JeebSurfaceToneData a = JeebSurfaceToneData(
      kind: JeebSurfaceKind.light,
      titleInk: Color(0xFF000000),
      mutedInk: Color(0xFF000001),
      chipFill: Color(0xFF000002),
      chipInk: Color(0xFF000003),
      meterFill: Color(0xFF000004),
      meterEmpty: Color(0xFF000005),
      dividerInk: Color(0xFF000006),
    );
    const JeebSurfaceToneData b = JeebSurfaceToneData(
      kind: JeebSurfaceKind.navy,
      titleInk: Color(0xFF000000),
      mutedInk: Color(0xFF000001),
      chipFill: Color(0xFF000002),
      chipInk: Color(0xFF000003),
      meterFill: Color(0xFF000004),
      meterEmpty: Color(0xFF000005),
      dividerInk: Color(0xFF000006),
    );

    expect(a, equals(a));
    expect(a, isNot(equals(b)));
    expect(a.hashCode, isNot(b.hashCode));
  });
}
