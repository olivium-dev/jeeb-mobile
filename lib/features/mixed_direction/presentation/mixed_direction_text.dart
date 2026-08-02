import 'package:flutter/material.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

class MixedDirectionText extends StatelessWidget {

  const MixedDirectionText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  static TextDirection detectDirection(String text) {
    if (text.isEmpty) return TextDirection.ltr;
    final firstChar = text.trim().codeUnits.first;
    if (firstChar >= 0x0600 && firstChar <= 0x06FF) return TextDirection.rtl;
    if (firstChar >= 0xFE70 && firstChar <= 0xFEFF) return TextDirection.rtl;
    if (firstChar >= 0x0590 && firstChar <= 0x05FF) return TextDirection.rtl;
    return TextDirection.ltr;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: detectDirection(text),
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/mixed_direction/mixed_direction_text_preview_test.dart
// ===========================================================================
//
// Widget previews for [MixedDirectionText] — run with
// `flutter widget-preview start`.
//
// The widget is a pure function of one String: [MixedDirectionText.detectDirection]
// reads the FIRST character of the trimmed text and wraps a plain [Text] in a
// [Directionality]. There is no cubit and no repository to seed, so these
// previews are network-free by construction rather than merely by the guard in
// `jeebPreviewHost`.
//
// The fixtures are the three the Screen Catalog already uses for this widget
// (`lib/devtool/catalog/entries/batch_06_entries.dart`) plus the two shapes its
// real call sites produce: the rating screen's `feedbackRateName(name)` frame
// (`lib/features/rating/presentation/rating_screen.dart`) and the tracking
// panel's server-formatted status line
// (`lib/features/live_tracking/presentation/widgets/delivery_tracking_panel.dart`).
// There is no widget test for this class anywhere under `test/`, so these
// previews plus their render test are its first coverage.
//
// Every state below is hosted at a fixed 342pt — the content width the widget
// gets on a 390pt phone once the screen gutter is removed. Direction is only
// VISIBLE when the paragraph is narrower than its frame: at the 800pt default
// test surface a short RTL line and a short LTR line land in the same place.
//
// Three things these previews surface, all in the widget rather than in the
// previews:
//
//  * **the first character decides the whole paragraph.** A mostly-Arabic note
//    that opens with a digit, a Latin brand token or an ASCII quote is laid out
//    LTR — see [mixedDirectionTextLeadingDigit], which is the catalog's own
//    fixture and reads with its punctuation on the wrong side.
//  * **detection ignores the ambient locale.** The widget never consults
//    `Directionality.of(context)`, so it renders identically in the EN and AR
//    canvases. That is deliberate for user-authored content, but it also means
//    a null/blank server field cannot inherit the app's direction as a fallback.
//  * **a whitespace-only string throws.** `detectDirection` guards
//    `text.isEmpty` and then reads `text.trim().codeUnits.first`, so `'   '`
//    raises `Bad state: No element` from `build`. No preview below can carry
//    that state — it would not render at all, and a broken preview marks the
//    whole library — so [mixedDirectionTextLeadingWhitespace] holds the nearest
//    renderable neighbour instead.

/// The canvas box for the single-line states: phone width, one line of body
/// copy plus the gutter.
const Size _mixedDirectionTextLineBox = Size(390, 120);

/// A taller box for the states that wrap — the long note, and the two matrix
/// states whose 200%-text rendering needs three lines.
const Size _mixedDirectionTextBlockBox = Size(390, 220);

/// 390 - 2 * [_mixedDirectionTextGutter]: the width the widget gets on a phone.
const double _mixedDirectionTextContentWidth = 342;

/// The standard screen gutter both call sites sit inside.
const double _mixedDirectionTextGutter = 24;

Widget _mixedDirectionTextHosted(
  String text, {
  TextAlign? textAlign,
  int? maxLines,
  TextOverflow? overflow,
}) =>
    Padding(
      padding: const EdgeInsets.all(_mixedDirectionTextGutter),
      child: SizedBox(
        width: _mixedDirectionTextContentWidth,
        child: Builder(
          builder: (BuildContext context) => MixedDirectionText(
            text,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow,
          ),
        ),
      ),
    );

/// The LTR baseline: an English pickup line, the shape most orders carry.
///
/// Read the four states below against this one — it is the only one where the
/// detected direction and the reviewer's reading direction cannot disagree.
@JeebPreview(
  group: 'mixed_direction',
  name: 'English (LTR)',
  size: _mixedDirectionTextLineBox,
)
Widget mixedDirectionTextEnglish() =>
    _mixedDirectionTextHosted('Pickup from Spinneys, Hamra');

/// The RTL baseline: an Arabic note, which is what the widget exists for.
///
/// The line must start at the RIGHT edge of the 342pt box and its comma must
/// sit on the left. This is the state the matrix is really for: the EN light
/// card and the AR RTL dark card render the SAME glyphs in the same place —
/// proving the direction comes from the text, not from the app locale — while
/// the 200% card is where a one-line note becomes a three-line block.
@JeebPreview(
  group: 'mixed_direction',
  name: 'Arabic (RTL)',
  size: _mixedDirectionTextBlockBox,
  matrix: true,
)
Widget mixedDirectionTextArabic() =>
    _mixedDirectionTextHosted('توصيل من محل الحلويات في الأشرفية');

/// The rating screen's real output: an English frame around an Arabic name.
///
/// `feedbackRateName` renders "Rate {name}", and a Lebanese customer's name is
/// usually Arabic — so the string is LTR by its first character while its
/// second half runs right-to-left. This is exactly the case a bare [Text] gets
/// right and a hardcoded `Directionality.rtl` would get wrong, and it is why
/// the rating screen reaches for this widget at all. Centred, as the screen
/// centres it.
@JeebPreview(
  group: 'mixed_direction',
  name: 'Arabic name in an English frame',
  size: _mixedDirectionTextLineBox,
)
Widget mixedDirectionTextArabicNameInEnglish() => _mixedDirectionTextHosted(
      'Rate محمد الحلبي',
      textAlign: TextAlign.center,
    );

/// The heuristic misfiring — the catalog's own "Leading digits" fixture.
///
/// The copy is Arabic apart from its first two tokens, but `detectDirection`
/// only ever sees the `2`, so the whole paragraph is laid out LTR: it starts at
/// the LEFT edge and the Arabic run trails off to the right. A courier reading
/// "2 boxes - توصيل سريع" sees the quantity and the note in the opposite order
/// from every other note in the list.
///
/// Matrixed because the AR RTL card is the one that makes it obvious: every
/// other element on that screen has mirrored and this line has not.
@JeebPreview(
  group: 'mixed_direction',
  name: 'Leading digit · LTR misfire',
  size: _mixedDirectionTextBlockBox,
  matrix: true,
)
Widget mixedDirectionTextLeadingDigit() =>
    _mixedDirectionTextHosted('2 boxes - توصيل سريع');

/// Longest plausible content: a full delivery note, clamped to two lines.
///
/// The compose field accepts 1000 characters (`maxLength: 1000` in
/// `rating_screen.dart`), so the callers that pass `maxLines` + `ellipsis` are
/// the ones under real pressure. What to look at is WHERE the ellipsis lands:
/// under RTL it belongs at the LEFT end of the second line, and a truncation
/// that reads correctly at 1x can cut mid-word at 200%.
@JeebPreview(
  group: 'mixed_direction',
  name: 'Long Arabic note · clamped to 2 lines',
  size: _mixedDirectionTextBlockBox,
)
Widget mixedDirectionTextLongArabicNote() => _mixedDirectionTextHosted(
      'الرجاء التوصيل إلى مبنى الأمين، الطابق الرابع، شارع الحمرا، بيروت، '
      'والاتصال بي قبل الوصول بعشر دقائق',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

/// Leading whitespace: detection trims, rendering does not.
///
/// A pasted note usually arrives with a space or two in front of it.
/// `detectDirection` trims before it looks, so the direction is still RTL — but
/// the [Text] keeps the spaces, which under RTL indent the line from the RIGHT
/// edge and look like a layout bug rather than like the user's own input.
///
/// This state is also the boundary of a real crash: strip the one word and the
/// same code path throws `Bad state: No element`, because the `text.isEmpty`
/// guard runs on the UNtrimmed string while `codeUnits.first` runs on the
/// trimmed one. That state cannot be previewed — it does not render.
@JeebPreview(
  group: 'mixed_direction',
  name: 'Leading whitespace (crash boundary)',
  size: _mixedDirectionTextLineBox,
)
Widget mixedDirectionTextLeadingWhitespace() =>
    _mixedDirectionTextHosted('  توصيل من الأشرفية');
