import 'package:flutter/material.dart';

/// First-strong-character bidi direction detection.
///
/// WhatsApp lays a single conversation out so the bubble alignment is
/// stable (sender right, receiver left) regardless of the user's UI
/// language, but the **text inside each bubble** reads in its own script's
/// natural direction. Flutter's [Text] widget inherits direction from
/// [Directionality.of] — it does not look at the content — so we need this
/// helper to pick a per-message direction from the first strong-directional
/// character. Mirrors the Unicode Bidi Algorithm (UAX #9) "first strong"
/// rule.
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

  /// P3: optional line clamp for the pinned-strip description row. Null (the
  /// default, and every pre-existing call site) = unclamped, unchanged.
  final int? maxLines;

  /// P3: optional overflow behaviour, paired with [maxLines]. Null = unchanged.
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

  /// Returns the direction of the first strong-directional character in
  /// [text], or null if the text contains no strong characters (digits,
  /// punctuation, emoji only). Caller falls back to the ambient direction
  /// in the null case.
  static TextDirection? _detectDirection(String text) {
    for (final rune in text.runes) {
      if (_isStrongRtl(rune)) return TextDirection.rtl;
      if (_isStrongLtr(rune)) return TextDirection.ltr;
    }
    return null;
  }

  static bool _isStrongRtl(int r) {
    // Hebrew, Arabic, Arabic Supplement, Syriac, Thaana, NKo, Samaritan,
    // Mandaic, Arabic Extended-A, Hebrew presentation forms, Arabic
    // presentation forms A and B. Covers all the scripts the Jeeb client
    // base actually uses (primarily Arabic) plus the major neighbours.
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

  static bool _isStrongLtr(int r) {
    // Basic Latin letters, Latin-1 letters, Latin Extended A/B, plus
    // common Cyrillic/Greek ranges. We intentionally treat anything not
    // covered here (or by [_isStrongRtl]) as direction-neutral so digits
    // and punctuation don't pin the paragraph direction.
    return (r >= 0x0041 && r <= 0x005A) ||
        (r >= 0x0061 && r <= 0x007A) ||
        (r >= 0x00C0 && r <= 0x024F) ||
        (r >= 0x0370 && r <= 0x03FF) ||
        (r >= 0x0400 && r <= 0x04FF);
  }
}
