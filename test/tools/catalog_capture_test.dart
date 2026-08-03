// Capture harness — NOT a gate. Renders every Dev Tool catalog state to a PNG so
// the implementation can be compared against the design board frame by frame.
//
// This exists because "the tests pass" and "it looks like the design" are
// different claims, and only the second one is what the redesign was for.
//
// Write the images:
//   flutter test test/tools/catalog_capture_test.dart --update-goldens
//
// Output: docs/redesign-2026-08/actual/<feature>__<screen>__<state>.png at the
// board's own 440x956 canvas, so a capture and a design frame are directly
// comparable without rescaling.
//
// Every state gets its own testWidgets so one screen that throws cannot take the
// rest of the sweep down with it.
@Tags(<String>['capture'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/screen_catalog.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../support/load_test_fonts.dart';
import '../support/sync_app_localizations.dart';

/// The design board's canvas. Matching it means a capture and a frame line up
/// without rescaling, which is the whole point of the comparison.
const Size _kCanvas = Size(440, 956);

String _slug(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

void main() {
  // Without this the captures render every glyph as a solid block: the theme
  // NAMES Inter but the faces are never loaded, so copy cannot be compared.
  setUpAll(loadInterTestFont);

  for (final CatalogEntry entry in kScreenCatalog) {
    for (int i = 0; i < entry.states.length; i++) {
      final CatalogState state = entry.states[i];
      final String name =
          '${_slug(entry.feature)}__${_slug(entry.screen)}__$i-${_slug(state.label)}';

      testWidgets('capture $name', (WidgetTester tester) async {
        tester.view.physicalSize = _kCanvas;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: withGoldenTestFonts(AppTheme.light()),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<Object?>>[
              SyncAppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Builder(builder: state.builder),
          ),
        );

        // Screens with an indefinite animation (mic pulse, Lottie loops, live
        // waveform) never settle, so a bare pumpAndSettle would time out. Give
        // it a chance, then fall back to fixed pumps and capture mid-flight.
        try {
          await tester.pumpAndSettle(const Duration(milliseconds: 120));
        } on Object {
          for (int f = 0; f < 4; f++) {
            await tester.pump(const Duration(milliseconds: 120));
          }
        }

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('../../docs/redesign-2026-08/actual/$name.png'),
        );
      });
    }
  }
}
