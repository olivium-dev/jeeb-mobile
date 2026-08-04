import 'package:flutter/material.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// First-strong-character bidi direction detection (UAX #9).
/// Text reads in its own script's natural direction, not the UI language.
/// Flutter [Text] inherits direction from [Directionality.of], so we detect
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [AutoDirectionText] — run with

/// The canvas box for one chat message's text: phone width, room for the line
/// to become three at 200% text.
const Size _autoDirectionTextMessageBox = Size(390, 140);

/// A short box for content that cannot wrap far — a phone number stays on one
/// line even at 200%.
const Size _autoDirectionTextShortBox = Size(390, 100);

/// A taller box for the clamped description: two lines of 200% text plus the
/// ellipsis row.
const Size _autoDirectionTextClampedBox = Size(390, 170);

Widget _autoDirectionTextHosted(String data, {int? maxLines, TextOverflow? overflow}) =>
    AutoDirectionText(data, maxLines: maxLines, overflow: overflow);

/// Pure Latin content — the baseline, and the LTR-in-RTL case.
/// The EN rendering is unremarkable; the AR RTL dark rendering is the one to
@JeebPreview(group: 'chat', name: 'English message', size: _autoDirectionTextMessageBox)
Widget autoDirectionTextEnglish() => _autoDirectionTextHosted('On my way, five minutes out');

/// Pure Arabic content — the majority case for the Jeeb client base, and the
/// RTL-in-LTR case.
@JeebPreview(group: 'chat', name: 'Arabic message', size: _autoDirectionTextMessageBox)
Widget autoDirectionTextArabic() => _autoDirectionTextHosted('انا في الطريق اليك خمس دقائق');

/// The first-strong rule, RTL branch: Arabic opening, Latin brand name inside.
/// Real chat traffic is bilingual — shop names, street names and order codes
@JeebPreview(group: 'chat', name: 'Mixed: Arabic first', size: _autoDirectionTextMessageBox)
Widget autoDirectionTextMixedArabicFirst() =>
    _autoDirectionTextHosted('مرحبا الطلب جاهز عند Spinneys');

/// The first-strong rule, LTR branch: the same sentence built the other way
/// round.
@JeebPreview(group: 'chat', name: 'Mixed: English first', size: _autoDirectionTextMessageBox)
Widget autoDirectionTextMixedEnglishFirst() =>
    _autoDirectionTextHosted('Pickup from مخبز الرحمة, Hamra');

/// No strong character at all — the fallback branch, and a real defect.
/// A message that is only digits and punctuation is ordinary chat traffic here:
@JeebPreview(group: 'chat', name: 'Digits only, no strong character', size: _autoDirectionTextShortBox)
Widget autoDirectionTextNeutralOnly() => _autoDirectionTextHosted('+961 3 000 077');

/// A strong-LTR script the detector does not know about.
/// `_isStrongLtr` covers Latin, Greek and Cyrillic only. Amharic (Ethiopic,
@JeebPreview(group: 'chat', name: 'Unlisted LTR script (Amharic)', size: _autoDirectionTextMessageBox)
Widget autoDirectionTextUnlistedScript() => _autoDirectionTextHosted('ሰላም በመንገድ ላይ ነኝ');

/// The longest plausible content, on the one call site that clamps it.
/// The pinned order-summary strip passes `maxLines: 2` + `TextOverflow.ellipsis`
@JeebPreview(group: 'chat', name: 'Long Arabic, clamped to 2 lines', size: _autoDirectionTextClampedBox)
Widget autoDirectionTextClampedLongArabic() => _autoDirectionTextHosted(
      'ارجو احضار كيسين من الخبز العربي وعلبة لبن كبيرة وزجاجة زيت زيتون من '
      'دكان ابو خليل في شارع الحمرا والدفع عند الاستلام نقدا',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
