import 'package:flutter/material.dart';

/// MIDNIGHT palette — `docs/redesign-midnight/01-TOKEN-SHEET.md` §1–§3.
/// Internal to `lib/core/theme/`; everything else reads roles, not hexes.
class JeebMidnight {
  const JeebMidnight._();

  static const Color page = Color(0xFF070C33);
  static const Color surfaceLow = Color(0xFF0A1147);
  static const Color surface = Color(0xFF0B1351);
  static const Color surfaceHigh = Color(0xFF10175E);
  static const Color surfaceHighest = Color(0xFF151C69);

  static const Color ink = Color(0xFFEDEFFC);
  static const Color inkMuted = Color(0xFF8A93D8);
  static const Color inkSoft = Color(0xFFB9C0F0);

  /// Legacy periwinkle, retired as ink (§10) — §8 sanctions it for the field's
  /// decorative wash and nothing else.
  static const Color periwinkleWash = Color(0xFF777FC0);

  static const Color orange = Color(0xFFD73B00);
  static const Color orangeBright = Color(0xFFFF6A2B);
  static const Color orangeSoft = Color(0xFFFFB27A);
  static const Color orangeTint = Color(0xFFFFB499);
  static const Color orangePressed = Color(0xFFC23300);
  static const Color orangeContainer = Color(0xFF431505);

  static const Color success = Color(0xFF3BB273);
  static const Color successSoft = Color(0xFF7BD9A4);
  static const Color successContainer = Color(0xFF0E3B2C);

  static const Color amber = Color(0xFFFFC107);
  static const Color amberSoft = Color(0xFFFFDF9E);
  static const Color amberContainer = Color(0xFF4A3200);
  static const Color onAmber = Color(0xFF3B2600);

  static const Color danger = Color(0xFFFF5252);
  static const Color dangerSoft = Color(0xFFFF7B7B);
  static const Color dangerContainer = Color(0xFF4A1220);

  /// Glass is white-at-alpha, never a baked hex — it composites on any navy.
  static const Color glassFill = Color(0x12FFFFFF);
  static const Color glassFillEmphasis = Color(0x1AFFFFFF);
  static const Color glassFillPressed = Color(0x24FFFFFF);
  static const Color glassBorder = Color(0x1FFFFFFF);
  static const Color glassBorderStrong = Color(0x29FFFFFF);

  static const Color outline = Color(0x24FFFFFF);
  static const Color outlineVariant = Color(0x1FFFFFFF);

  static const Color readTick = Color(0xFF20F0FF);
  static const Color accentTint = Color.fromRGBO(215, 59, 0, 0.12);
  static const Color accentRing = Color.fromRGBO(215, 59, 0, 0.30);
  static const Color divider = Color.fromRGBO(138, 147, 216, 0.12);
}
