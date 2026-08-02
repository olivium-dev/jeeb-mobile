import 'package:flutter/material.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/chat/auto_direction_text_preview_test.dart
// ===========================================================================

// Widget previews for [AutoDirectionText] — run with
// `flutter widget-preview start`.
//
// The widget takes exactly one meaningful input, a [String], and decides the
// paragraph direction from the FIRST strong-directional character in it
// (UAX #9). No cubit, no repository, no async — these previews are
// network-free by construction, not just by the guard in [jeebPreviewHost].
//
// That makes the interesting axis the *interaction between the content and the
// ambient UI direction*, which is exactly what the [JeebPreview] matrix varies:
// the EN light rendering is the content in an LTR UI, the AR RTL dark rendering
// is the same content in an RTL UI. A preview here is only worth having if the
// two renderings should differ, or if they should NOT differ and might.
//
// Style is deliberately left to the ambient `DefaultTextStyle` rather than
// passed in. Every call site supplies its own `theme.textTheme.*` and its own
// colour; pinning one here would make these previews a typography review of the
// caller instead of a direction/wrapping review of this widget.
//
// `test/chat_auto_direction_text_test.dart` already asserts the detection rule
// as data ("this string resolves RTL"). These previews exist for the half that
// assertion cannot see: what the resolved direction does to the *layout* —
// which edge the paragraph anchors to, where a run of digits ends up, and how a
// clamped description ellipsizes.
//
// Two things the previews surfaced, both in the widget rather than here: the
// null branch of `_detectDirection` hands neutral-only strings (phone numbers,
// prices, order codes) to the UI language, and `_isStrongLtr` recognises only
// Latin/Greek/Cyrillic, so every other LTR script falls into that same null
// branch. See the last two states.

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
///
/// The EN rendering is unremarkable; the AR RTL dark rendering is the one to
/// look at. The surrounding UI mirrors, but this paragraph must NOT: it stays
/// left-anchored and reads left-to-right, because the message is English no
/// matter what language the app is set to. If it ever right-anchors here, the
/// `Directionality` override has stopped being applied.
@JeebPreview(group: 'chat', name: 'English message', size: _autoDirectionTextMessageBox)
Widget autoDirectionTextEnglish() => _autoDirectionTextHosted('On my way, five minutes out');

/// Pure Arabic content — the majority case for the Jeeb client base, and the
/// RTL-in-LTR case.
///
/// The mirror image of the state above: this must right-anchor and read
/// right-to-left in BOTH renderings, including the English one. An Arabic
/// message that reads left-anchored inside an English UI is the original bug
/// this widget was written to fix.
@JeebPreview(group: 'chat', name: 'Arabic message', size: _autoDirectionTextMessageBox)
Widget autoDirectionTextArabic() => _autoDirectionTextHosted('انا في الطريق اليك خمس دقائق');

/// The first-strong rule, RTL branch: Arabic opening, Latin brand name inside.
///
/// Real chat traffic is bilingual — shop names, street names and order codes
/// stay Latin inside an Arabic sentence. The paragraph must take its direction
/// from the FIRST strong character (Arabic → RTL) and leave the embedded Latin
/// run reading left-to-right in place. Getting this wrong does not throw; it
/// just puts the shop name at the wrong end of the sentence.
@JeebPreview(group: 'chat', name: 'Mixed: Arabic first', size: _autoDirectionTextMessageBox)
Widget autoDirectionTextMixedArabicFirst() =>
    _autoDirectionTextHosted('مرحبا الطلب جاهز عند Spinneys');

/// The first-strong rule, LTR branch: the same sentence built the other way
/// round.
///
/// Paired with the state above on purpose. Together they are the check that the
/// direction really is read off the content — a widget that hardcoded either
/// direction, or that fell through to the ambient one, would still make one of
/// these two look correct.
@JeebPreview(group: 'chat', name: 'Mixed: English first', size: _autoDirectionTextMessageBox)
Widget autoDirectionTextMixedEnglishFirst() =>
    _autoDirectionTextHosted('Pickup from مخبز الرحمة, Hamra');

/// No strong character at all — the fallback branch, and a real defect.
///
/// A message that is only digits and punctuation is ordinary chat traffic here:
/// a phone number, a price, an order code. `_detectDirection` returns null for
/// it and the widget adopts the ambient direction, so the SAME string lays out
/// differently in the two renderings.
///
/// That is not cosmetic. In the AR RTL rendering the paragraph direction is
/// RTL, and per UAX #9 the space-separated digit groups are each an LTR run
/// inside an RTL paragraph — so the runs are ordered right-to-left and the
/// number is displayed with its groups reversed. An Arabic-UI client reading
/// back a callback number gets the country code on the wrong end.
///
/// `test/chat_auto_direction_text_test.dart` already documents this branch with
/// `'123 !@#'`; this preview is what it looks like with content someone
/// actually sends.
@JeebPreview(group: 'chat', name: 'Digits only, no strong character', size: _autoDirectionTextShortBox)
Widget autoDirectionTextNeutralOnly() => _autoDirectionTextHosted('+961 3 000 077');

/// A strong-LTR script the detector does not know about.
///
/// `_isStrongLtr` covers Latin, Greek and Cyrillic only. Amharic (Ethiopic,
/// U+1200–U+137F) is strong LTR in Unicode but matches neither range, so it
/// falls into the same null branch as the digits above and inherits the UI
/// direction — it renders left-anchored in English and right-anchored in
/// Arabic. Lebanon's domestic-worker population makes Amharic, Bengali and
/// Sinhala messages plausible traffic, and all three are outside the ranges.
///
/// The class doc says neutrality is intentional "so digits and punctuation
/// don't pin the paragraph direction"; unlisted alphabets landing in the same
/// bucket looks like a side effect of the range list rather than that intent.
@JeebPreview(group: 'chat', name: 'Unlisted LTR script (Amharic)', size: _autoDirectionTextMessageBox)
Widget autoDirectionTextUnlistedScript() => _autoDirectionTextHosted('ሰላም በመንገድ ላይ ነኝ');

/// The longest plausible content, on the one call site that clamps it.
///
/// The pinned order-summary strip passes `maxLines: 2` + `TextOverflow.ellipsis`
/// so a long request description "can never push the message list off screen".
/// This is where that clamp meets the two hostile renderings: in Arabic the
/// ellipsis has to land on the correct (left) end of the line, and at 200% text
/// two lines hold roughly a third of what they hold at 1x — worth seeing before
/// deciding two lines is enough of a preview of the request.
@JeebPreview(group: 'chat', name: 'Long Arabic, clamped to 2 lines', size: _autoDirectionTextClampedBox)
Widget autoDirectionTextClampedLongArabic() => _autoDirectionTextHosted(
      'ارجو احضار كيسين من الخبز العربي وعلبة لبن كبيرة وزجاجة زيت زيتون من '
      'دكان ابو خليل في شارع الحمرا والدفع عند الاستلام نقدا',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
