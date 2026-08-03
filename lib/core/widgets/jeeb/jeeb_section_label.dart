import 'package:flutter/material.dart';

import '../../theme/jeeb_text_styles.dart';

/// The uppercase section header above a control or card group
/// (redesign-2026-08 §5 #10).
///
/// `w700 / letter-spacing 1.2 / UPPERCASE / mutedText`, realized on 05, 15, 17,
/// 19, 20 and 23.
///
/// Three things are deliberately *not* the caller's job:
///
///  * **The casing.** Pass the natural-cased l10n string; the widget uppercases
///    it. Call sites must never ship `.toUpperCase()` themselves — that is how
///    an Arabic build ends up calling a locale-sensitive transform on a
///    caseless script. See [resolveCase].
///  * **The size.** The shipped `jeebText.sectionLabel` is 11px, but that is
///    the minority reading: 8 of the 9 labels on the board are 12.5–13px
///    (§4.2). [defaultFontSize] is 12.5; [small] selects the 11px form, which
///    only 05 draws. 13px (15, 17) is the same token — do **not** add a third
///    size.
///  * **The inline hint.** 17 renders `PICKUP ETA · Flash allows ≤ 60 min`:
///    one line, where the continuation is *not* uppercased, has no tracking and
///    drops to w600. That is the [hint] slot, rendered as a span of the same
///    `Text` — never a second `Text` beside it, which would wrap and align
///    independently.
///
/// **It ignores [JeebSurfaceTone] on purpose.** 19 (`tpl 1112`) and 23
/// (`tpl 1361`) both draw this label *on the navy hero card* and it stays
/// periwinkle there — unlike the price-meter caption two cards away, which does
/// invert to `rgba(255,255,255,.7)`. The ink is part of the token, not of the
/// surface.
class JeebSectionLabel extends StatelessWidget {
  const JeebSectionLabel(
    this.label, {
    super.key,
    this.hint,
    this.small = false,
    this.textAlign,
    this.identifier,
  });

  /// 12.5px — the majority reading (19 `tpl 1112`, 20 `tpl 1187`/`1192`,
  /// 23 `tpl 1361`). 15 and 17 draw 13px; §5 #10 rules that the same token.
  static const double defaultFontSize = 12.5;

  /// 11px — the size `jeebText.sectionLabel` actually ships, realized on 05
  /// only. Selected by [small].
  static const double smallFontSize = 11;

  /// Weight of the [hint] continuation (17 `tpl 1003`).
  static const FontWeight hintWeight = FontWeight.w600;

  /// Language codes whose labels render verbatim, with no case transform.
  ///
  /// `ar` is the shipped case: Arabic is caseless, so Dart's
  /// locale-independent `toUpperCase()` is already a no-op on it. Listing it
  /// makes "AR passes through unchanged" a tested contract instead of a
  /// coincidence, and gives a future locale where the default Unicode mapping
  /// is *wrong* (`tr`: `i` → `İ`) somewhere to be added.
  static const Set<String> uppercaseExemptLanguages = <String>{
    'ar',
    'fa',
    'he',
    'ur',
  };

  /// The section title, in its natural l10n casing.
  final String label;

  /// Optional inline continuation: not uppercased, no tracking, w600, same
  /// size and ink, separated from [label] by a single space (17 `tpl 1002`).
  ///
  /// The l10n string carries its own leading separator (`· ≤ {minutes} min`) —
  /// the widget adds a space, never a bullet.
  final String? hint;

  /// Use the 11px form ([smallFontSize]) instead of the 12.5px default.
  final bool small;

  /// Defaults to the ambient alignment (start). Only pass this when the label
  /// sits in a centred block.
  final TextAlign? textAlign;

  /// Maestro/`find.bySemanticsIdentifier` id, applied via an explicit
  /// `Semantics` wrapper (never OMDS's own `identifier:`).
  final String? identifier;

  /// Uppercases [label] unless [locale]'s language is in
  /// [uppercaseExemptLanguages]. A null [locale] (no `Localizations` above,
  /// as in a bare widget-test harness) is treated as the cased default.
  ///
  /// Exposed so a screen test can derive the string it should `find.text()`
  /// without re-implementing the rule.
  static String resolveCase(String label, Locale? locale) =>
      uppercaseExemptLanguages.contains(locale?.languageCode)
          ? label
          : label.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final TextStyle base = context.jeebText.sectionLabel.copyWith(
      fontSize: small ? smallFontSize : defaultFontSize,
    );
    final String cased =
        resolveCase(label, Localizations.maybeLocaleOf(context));

    final Widget text = hint == null
        ? Text(cased, style: base, textAlign: textAlign)
        : Text.rich(
            TextSpan(
              text: cased,
              children: <InlineSpan>[
                TextSpan(
                  // The space lives on the hint span so the label's 1.2
                  // tracking does not stretch the gap (17 `tpl 1002`).
                  text: ' $hint',
                  style: const TextStyle(
                    fontWeight: hintWeight,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
            style: base,
            textAlign: textAlign,
          );

    if (identifier == null) {
      return text;
    }
    // No `container`/`explicitChildNodes`: this annotation is meant to merge
    // with the single Text below it, so the node carries both the id and the
    // label rather than hiding one behind the other.
    return Semantics(identifier: identifier, child: text);
  }
}
