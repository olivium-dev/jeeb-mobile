import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every solid fill/stroke colour a Lottie composition paints, read off the
/// authored JSON — a rest-frame capture cannot reach a mark's own palette.
Set<Color> lottieSolidColors(String assetPath) {
  final Object? doc = jsonDecode(File(assetPath).readAsStringSync());
  final Set<Color> found = <Color>{};

  void walk(Object? node) {
    if (node is Map) {
      for (final MapEntry<Object?, Object?> e in node.entries) {
        if (e.key == 'c' && e.value is Map) {
          final Object? k = (e.value! as Map)['k'];
          if (k is List && k.length >= 3 && k.every((Object? v) => v is num)) {
            found.add(
              Color.from(
                alpha: k.length > 3 ? (k[3] as num).toDouble() : 1,
                red: (k[0] as num).toDouble(),
                green: (k[1] as num).toDouble(),
                blue: (k[2] as num).toDouble(),
              ),
            );
          }
        }
        walk(e.value);
      }
    } else if (node is List) {
      for (final Object? v in node) {
        walk(v);
      }
    }
  }

  walk(doc);
  return found;
}

/// WCAG 2.2 relative-luminance contrast ratio, in [1, 21].
double inkContrast(Color fg, Color bg) {
  final double l1 = fg.computeLuminance();
  final double l2 = bg.computeLuminance();
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

/// Colour equality that survives the float round-trip through a Lottie `[r,g,b]`
/// triplet (authored at 3 decimals, so a channel can land ±1/255 off).
Matcher closeToColor(Color expected) => predicate<Color>(
  (Color actual) =>
      ((actual.r - expected.r).abs() * 255) < 1.5 &&
      ((actual.g - expected.g).abs() * 255) < 1.5 &&
      ((actual.b - expected.b).abs() * 255) < 1.5,
  'within 1/255 per channel of $expected',
);
