// R9's orange radial. Board `Jeeb Rich UI.dc.html:520` declares ONE radial,
// `500px 420px at 10% -8%`; un-compositing the export fits (0.098, -0.085).
//
// Goldens tolerate 5% pixel diff, so they cannot see an anchor that has moved
// to the far end of the screen — this reads the placement off the widget.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_type_screen.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';

import '../../support/sync_app_localizations.dart';

void main() {
  Future<JeebMidnightField> pumpField(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      wrapForTest(
        const RequestTypeScreen(repository: FakeTierRepository()),
        locale: locale,
      ),
    );
    await tester.pumpAndSettle();
    final Finder finder = find.byType(JeebMidnightField);
    expect(finder, findsOneWidget, reason: 'R9 draws exactly one field');
    return tester.widget<JeebMidnightField>(finder);
  }

  group('R9 request type — field glow anchor', () {
    testWidgets('declares the measured top-start anchor, not `bottom`', (
      tester,
    ) async {
      final JeebMidnightField field = await pumpField(tester);

      expect(
        field.glowPlacement,
        JeebFieldGlowPlacement.topStart,
        reason: 'board 09-r9-request-type measures (0.098, -0.085); `bottom` '
            '(0.50, 0.94) put it at the OPPOSITE end of the screen',
      );
      expect(field.variant, JeebFieldVariant.content);
    });

    testWidgets('resolves start-side and ABOVE the top edge', (tester) async {
      final JeebMidnightField field = await pumpField(tester);
      final AlignmentDirectional anchor = field.glowPlacement!.alignment;

      expect(
        anchor.y,
        lessThan(-1),
        reason: 'fy < 0 — the anchor sits off-canvas above the top edge',
      );
      expect(anchor.resolve(TextDirection.ltr).x, lessThan(0));
    });

    testWidgets('mirrors to the end side under RTL', (tester) async {
      final JeebMidnightField field = await pumpField(
        tester,
        locale: const Locale('ar'),
      );
      final AlignmentDirectional anchor = field.glowPlacement!.alignment;

      expect(anchor.resolve(TextDirection.rtl).x, greaterThan(0));
      expect(
        anchor.resolve(TextDirection.rtl).x,
        closeTo(-anchor.resolve(TextDirection.ltr).x, 1e-9),
      );
    });
  });
}
