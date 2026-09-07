import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/config/dev_base_url.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/dev_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final dark in <bool>[false, true]) {
    for (final direction in TextDirection.values) {
      for (final scale in <double>[1, 2]) {
        for (final width in <double>[320, 360, 412]) {
          testWidgets(
            'preset reflow dark=$dark $direction ${scale}x width=$width',
            (tester) async {
              final semantics = tester.ensureSemantics();
              try {
                await tester.binding.setSurfaceSize(Size(width, 640));
                addTearDown(() => tester.binding.setSurfaceSize(null));
                await sl.reset();
                addTearDown(sl.reset);
                SharedPreferences.setMockInitialValues({});
                final prefs = await SharedPreferences.getInstance();
                sl.registerSingleton<SharedPreferences>(prefs);

                await tester.pumpWidget(
                  MaterialApp(
                    theme: dark ? AppTheme.midnight() : AppTheme.light(),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.linear(scale)),
                      child: Directionality(
                        textDirection: direction,
                        child: child!,
                      ),
                    ),
                    home: const ServerUrlPage(),
                  ),
                );
                await tester.pumpAndSettle();
                final scrollable = find
                    .descendant(
                      of: find.byType(ListView),
                      matching: find.byType(Scrollable),
                    )
                    .first;
                for (final preset in kDevServerUrlPresets) {
                  final chip = find.widgetWithText(OutlinedButton, preset);
                  await tester.scrollUntilVisible(
                    chip,
                    100,
                    scrollable: scrollable,
                  );
                  await tester.pumpAndSettle();
                  final label = find.descendant(
                    of: chip,
                    matching: find.text(preset),
                  );
                  final paragraph = tester.renderObject<RenderParagraph>(label);
                  final boxes = paragraph.getBoxesForSelection(
                    TextSelection(baseOffset: 0, extentOffset: preset.length),
                  );
                  expect(paragraph.text.toPlainText(), preset);
                  expect(boxes, isNotEmpty);
                  for (final box in boxes) {
                    expect(box.left, greaterThanOrEqualTo(0));
                    expect(box.right, lessThanOrEqualTo(paragraph.size.width));
                    expect(box.top, greaterThanOrEqualTo(0));
                    expect(
                      box.bottom,
                      lessThanOrEqualTo(paragraph.size.height),
                    );
                  }
                  expect(paragraph.didExceedMaxLines, isFalse);
                  expect(
                    tester.getRect(chip).intersect(tester.getRect(label)),
                    tester.getRect(label),
                  );
                  expect(tester.getRect(chip).left, greaterThanOrEqualTo(16));
                  expect(
                    tester.getRect(chip).right,
                    lessThanOrEqualTo(width - 16),
                  );
                  final data = tester.getSemantics(chip).getSemanticsData();
                  expect(data.label, contains(preset));
                  expect(data.flagsCollection.isButton, isTrue);
                  expect(data.hasAction(SemanticsAction.tap), isTrue);
                  expect(chip.hitTestable(), findsOneWidget);
                  await tester.tap(chip);
                  await tester.pump();
                  await tester.scrollUntilVisible(
                    find.byType(TextField),
                    -100,
                    scrollable: scrollable,
                  );
                  await tester.pumpAndSettle();
                  expect(
                    tester
                        .widget<TextField>(find.byType(TextField))
                        .controller!
                        .text,
                    preset,
                  );
                  expect(DevBaseUrl.read(prefs), isNull);
                }
                await tester.scrollUntilVisible(
                  find.widgetWithText(FilledButton, 'Save'),
                  150,
                  scrollable: scrollable,
                );
                await tester.tap(find.widgetWithText(FilledButton, 'Save'));
                await tester.pumpAndSettle();
                expect(DevBaseUrl.read(prefs), kDevServerUrlPresets.last);
                expect(
                  find.text('Saved. Restart the app to apply.'),
                  findsOneWidget,
                );
                expect(find.byType(ServerUrlPage), findsOneWidget);
                expect(tester.takeException(), isNull);
                await tester.pumpWidget(const SizedBox.shrink());
              } finally {
                semantics.dispose();
              }
            },
          );
        }
      }
    }
  }
}
