import 'package:flutter/material.dart';

/// First-strong-character bidi direction detection (UAX #9).
/// Text reads in its own script's natural direction, not the UI language.
/// Flutter [Text] inherits direction from [Directionality.of], so we detect
/// from the first strong-directional character per message.
class AutoDirectionText extends StatelessWidget {
  const AutoDirectionText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String data;
  final TextStyle? style;

  /// Optional line clamp; null = unclamped (default for all call sites).
  final int? maxLines;

  /// Optional overflow; paired with [maxLines].
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final direction = _detectDirection(data) ?? Directionality.of(context);
    return Directionality(
      textDirection: direction,
      child: Text(
        data,
        style: style,
        textDirection: direction,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }

  /// Direction of first strong char, or null if only neutral (digits, emoji, punctuation).
  static TextDirection? _detectDirection(String text) {
    for (final rune in text.runes) {
      if (_isStrongRtl(rune)) return TextDirection.rtl;
      if (_isStrongLtr(rune)) return TextDirection.ltr;
    }
    return null;
  }

  /// Hebrew, Arabic, Syriac, Thaana, NKo, Mandaic, etc (Jeeb primarily uses Arabic).
  static bool _isStrongRtl(int r) {
    return (r >= 0x0590 && r <= 0x05FF) ||
        (r >= 0x0600 && r <= 0x06FF) ||
        (r >= 0x0700 && r <= 0x074F) ||
        (r >= 0x0750 && r <= 0x077F) ||
        (r >= 0x0780 && r <= 0x07BF) ||
        (r >= 0x07C0 && r <= 0x07FF) ||
        (r >= 0x0800 && r <= 0x083F) ||
        (r >= 0x0840 && r <= 0x085F) ||
        (r >= 0x08A0 && r <= 0x08FF) ||
        (r >= 0xFB1D && r <= 0xFB4F) ||
        (r >= 0xFB50 && r <= 0xFDFF) ||
        (r >= 0xFE70 && r <= 0xFEFF);
  }

  /// Basic Latin, Latin-1, Latin Extended, Cyrillic, Greek.
  /// Anything else not covered here or in _isStrongRtl is neutral.
  static bool _isStrongLtr(int r) {
    return (r >= 0x0041 && r <= 0x005A) ||
        (r >= 0x0061 && r <= 0x007A) ||
        (r >= 0x00C0 && r <= 0x024F) ||
        (r >= 0x0370 && r <= 0x03FF) ||
        (r >= 0x0400 && r <= 0x04FF);
  }
}
