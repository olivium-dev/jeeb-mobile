import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

/// TL-4 regression guard. Inter is bundled as four discrete STATIC instances
/// (Regular/Medium/SemiBold/Bold) mapped to Material 3's 400/500/600/700.
///
/// A single variable TTF registered under discrete `weight:` keys renders all
/// four weights identically (the original defect this test was written to
/// catch). This test loads the four static files exactly as `pubspec.yaml`
/// declares them and asserts the rendered widths are distinct across weights —
/// if any two collapse, the wrong font files are bundled.
// Not `const`: FontWeight overrides `==`/`hashCode`, so it can't key a const
// map (analyzer error const_map_key_not_primitive_equality). The map is
// effectively immutable here regardless.
final _weightFiles = <FontWeight, String>{
  FontWeight.w400: 'assets/fonts/Inter-Regular.ttf',
  FontWeight.w500: 'assets/fonts/Inter-Medium.ttf',
  FontWeight.w600: 'assets/fonts/Inter-SemiBold.ttf',
  FontWeight.w700: 'assets/fonts/Inter-Bold.ttf',
};

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final entry in _weightFiles.entries) {
      final bytes = File(entry.value).readAsBytesSync();
      await (FontLoader('Inter')..addFont(Future.value(bytes.buffer.asByteData())))
          .load();
    }
  });

  double widthAt(FontWeight weight) {
    final painter = TextPainter(
      text: TextSpan(
        text: 'Availability dashboard 0123456789',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 32,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width;
  }

  test('Inter static instances render w400/w500/w600/w700 at distinct widths',
      () {
    final widths = {
      for (final w in _weightFiles.keys) w: widthAt(w),
    };

    // Each heavier weight has a wider glyph advance; no two collapse.
    final values = widths.values.toList();
    for (var i = 0; i < values.length; i++) {
      for (var j = i + 1; j < values.length; j++) {
        expect(
          values[i],
          isNot(closeTo(values[j], 0.5)),
          reason:
              'Two Inter weights rendered identically ($widths) — the wrong '
              'font files are bundled. Ship distinct static instances.',
        );
      }
    }

    // Sanity: heavier reads wider than lighter.
    expect(widths[FontWeight.w700]!, greaterThan(widths[FontWeight.w400]!));
  });
}
