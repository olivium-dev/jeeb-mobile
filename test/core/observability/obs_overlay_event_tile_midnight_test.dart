// M6 class-3b — the overlay event tile was an OMDS settings row being handed
// `colorScheme.primary`, i.e. orange under Midnight, on a read-only diagnostic
// glyph. Restyled onto the kit row; these read the paint off the widgets.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/observability/session_trace/model/obs_event.dart';
import 'package:jeeb_mobile/core/observability/session_trace/presentation/widgets/obs_overlay_event_tile.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_list_row.dart';

/// `colorScheme.primary` under Midnight.
const Color _orange = Color(0xFFD73B00);

final ObsEvent _event = ObsScreenEvent(
  id: 'e-1',
  sessionId: 's-1',
  timestampUtc: DateTime.utc(2026, 5, 17, 12),
  seq: 7,
  action: 'push',
  route: '/offers',
  name: 'client_offers',
);

Future<void> _pump(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.midnight(),
        home: Scaffold(body: ObsOverlayEventTile(event: _event)),
      ),
    );

void main() {
  group('ObsOverlayEventTile (M6 class-3b)', () {
    testWidgets('the summary line is a kit row with a periwinkle glyph',
        (WidgetTester tester) async {
      await _pump(tester);
      final ColorScheme scheme =
          Theme.of(tester.element(find.byType(ObsOverlayEventTile))).colorScheme;

      final JeebListRow row = tester.widget<JeebListRow>(
        find.byType(JeebListRow),
      );
      expect(row.iconColor, scheme.secondary);
      expect(row.iconColor, isNot(_orange));
      expect(row.iconColor, isNot(scheme.primary));
      expect(row.showChevron, isFalse, reason: 'it expands, it does not push');
    });

    testWidgets('the raw payload block is glass on the Midnight ladder',
        (WidgetTester tester) async {
      await _pump(tester);
      await tester.tap(find.byType(JeebListRow));
      await tester.pump();

      final JeebSemanticColors semantics = JeebSemanticColors.midnight();
      final BoxDecoration decoration = tester
          .widget<Container>(find.byKey(const Key('obs-overlay-event-raw')))
          .decoration! as BoxDecoration;

      expect(decoration.color, semantics.glassFill);
      expect(decoration.border!.top.color, semantics.glassBorder);
      expect(decoration.borderRadius, BorderRadius.circular(JeebRadii.sm));
      expect(
        tester
            .widget<SelectableText>(find.byType(SelectableText))
            .style!
            .color,
        semantics.inkSoft,
      );
    });
  });
}
