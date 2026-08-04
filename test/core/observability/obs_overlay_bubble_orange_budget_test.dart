// M6 — found by widening the leak pattern past the audit's `\.(primary|
// tertiary)\b`, which cannot match `primaryContainer`. The dev overlay FAB was
// filled with `#431505`, the derived deep-burnt orange step no board tile draws.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/observability/session_trace/presentation/obs_overlay_controller.dart';
import 'package:jeeb_mobile/core/observability/session_trace/presentation/widgets/obs_overlay_bubble.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';

/// Every orange-family slot the Midnight scheme publishes. A fill landing on
/// any of them is the budget violation, whichever token spelled it.
List<Color> _orangeFamily(ColorScheme scheme) => <Color>[
      scheme.primary,
      scheme.tertiary,
      scheme.primaryContainer,
      scheme.onPrimaryContainer,
      scheme.inversePrimary,
    ];

void main() {
  testWidgets('the dev overlay FAB is periwinkle, not an orange step',
      (WidgetTester tester) async {
    final ObsOverlayController controller = ObsOverlayController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.midnight(),
        home: Scaffold(
          body: Stack(children: <Widget>[ObsOverlayBubble(controller: controller)]),
        ),
      ),
    );

    final ColorScheme scheme =
        Theme.of(tester.element(find.byType(ObsOverlayBubble))).colorScheme;
    final Material disc =
        tester.widget<Material>(find.byKey(const Key('obs-overlay-bubble')));
    final Color glyph =
        tester.widget<Icon>(find.byIcon(Icons.data_object)).color!;

    // M0-2 ruling 3: a bare Material FAB is periwinkle. "When in doubt: not
    // orange" — and this disc is a dev affordance, never a board act.
    expect(disc.color, scheme.secondary);
    expect(glyph, scheme.onSecondary);
    for (final Color orange in _orangeFamily(scheme)) {
      expect(disc.color, isNot(orange));
      expect(glyph, isNot(orange));
    }
  });
}
