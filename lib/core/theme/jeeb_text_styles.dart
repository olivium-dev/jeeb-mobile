import 'package:flutter/material.dart';

/// The Jeeb redesign type ramp (redesign-2026-08 §4.2).
///
/// The 24-screen redesign board realizes weights 500→800 at ~16 discrete
/// size/weight pairs; stock `Typography.material2021` has neither the weights
/// nor the sizes, so every branded headline today is an ad-hoc
/// `copyWith(fontWeight:)` at the call site. This extension is the single
/// place those pairs live.
///
/// **The M3 [TextTheme] is deliberately NOT reshaped.** Reshaping it would
/// silently restyle all ~770 existing files; instead this rides alongside as a
/// `ThemeExtension`, so only screens that opt in change. Read it via
/// `context.jeebText.<field>` ([JeebTextStylesX]) — feature code may not write
/// `fontSize:` literals (`tool/check_design_tokens.sh` bans them in
/// `lib/features`).
///
/// Every field is [_fontFamily] with an explicit `fontWeight` + `fontSize` and
/// no color, so the ambient `DefaultTextStyle`/`ColorScheme` ink still applies
/// — the one exception is [sectionLabel], whose muted ink is part of its
/// definition (asserted against `JeebSemanticColors.mutedText` in
/// `test/core/theme/jeeb_text_styles_test.dart`).
///
/// Note on w800: `Inter-ExtraBold.ttf` is not bundled yet (see
/// `docs/redesign-2026-08/03-WAVE0-FOUNDATION.md`), so w800 currently renders
/// as the bundled w700. That is a graceful degradation — nothing here depends
/// on the asset existing.
@immutable
class JeebTextStyles extends ThemeExtension<JeebTextStyles> {
  const JeebTextStyles({
    required this.statHero,
    required this.statDisplay,
    required this.h1,
    required this.h2,
    required this.titleProminent,
    required this.cardTitle,
    required this.body,
    required this.bodySmall,
    required this.caption,
    required this.label,
    required this.badge,
    required this.sectionLabel,
    required this.price,
    required this.button,
    required this.keypadDigit,
    required this.codeInput,
  });

  /// Light-mode ramp. Only [sectionLabel] is brightness-dependent (it carries
  /// the muted ink); every other field is ink-free and identical in dark.
  factory JeebTextStyles.light() => const JeebTextStyles(
        statHero: _statHero,
        statDisplay: _statDisplay,
        h1: _h1,
        h2: _h2,
        titleProminent: _titleProminent,
        cardTitle: _cardTitle,
        body: _body,
        bodySmall: _bodySmall,
        caption: _caption,
        label: _label,
        badge: _badge,
        sectionLabel: _sectionLabelLight,
        price: _price,
        button: _button,
        keypadDigit: _keypadDigit,
        codeInput: _codeInput,
      );

  /// Dark-mode ramp. The redesign is light-only (§9.4); dark reuses the same
  /// metrics and only lifts the [sectionLabel] ink so it stays legible.
  factory JeebTextStyles.dark() => const JeebTextStyles(
        statHero: _statHero,
        statDisplay: _statDisplay,
        h1: _h1,
        h2: _h2,
        titleProminent: _titleProminent,
        cardTitle: _cardTitle,
        body: _body,
        bodySmall: _bodySmall,
        caption: _caption,
        label: _label,
        badge: _badge,
        sectionLabel: _sectionLabelDark,
        price: _price,
        button: _button,
        keypadDigit: _keypadDigit,
        codeInput: _codeInput,
      );

  /// 38/w800/−1.0 — navy hero numbers (earnings, wallet balance).
  final TextStyle statHero;

  /// 42/w800 — the at-door code display tiles.
  final TextStyle statDisplay;

  /// 24/w700 — screen headlines.
  final TextStyle h1;

  /// 20/w700 — top-bar titles and card headlines.
  final TextStyle h2;

  /// 17/w700 — two-line bar titles, statement lines.
  final TextStyle titleProminent;

  /// 15.5/w700 — offer / tier card names.
  final TextStyle cardTitle;

  /// 13.5/w500, 19px line — chat bubbles and body copy.
  final TextStyle body;

  /// 12/w600 — subtitles and meta rows.
  final TextStyle bodySmall;

  /// 11.5/w600 — ETA and cash lines.
  final TextStyle caption;

  /// 10.5/w700 — stepper labels, meter captions.
  final TextStyle label;

  /// 10.5/w800 — "Best value", "Most picked", the VOICE REQUEST tab.
  final TextStyle badge;

  /// 11/w700/+1.2, muted ink — UPPERCASE section headers. `toUpperCase()` is
  /// applied at the call site (see `JeebSectionLabel`) so AR passes through.
  final TextStyle sectionLabel;

  /// 21/w800 — offer prices.
  final TextStyle price;

  /// 17/w600 — CTA pill labels.
  final TextStyle button;

  /// 23/w700 — in-screen numeric keypad digits.
  final TextStyle keypadDigit;

  /// 29/w800 — OTP entry cells.
  final TextStyle codeInput;

  @override
  JeebTextStyles copyWith({
    TextStyle? statHero,
    TextStyle? statDisplay,
    TextStyle? h1,
    TextStyle? h2,
    TextStyle? titleProminent,
    TextStyle? cardTitle,
    TextStyle? body,
    TextStyle? bodySmall,
    TextStyle? caption,
    TextStyle? label,
    TextStyle? badge,
    TextStyle? sectionLabel,
    TextStyle? price,
    TextStyle? button,
    TextStyle? keypadDigit,
    TextStyle? codeInput,
  }) {
    return JeebTextStyles(
      statHero: statHero ?? this.statHero,
      statDisplay: statDisplay ?? this.statDisplay,
      h1: h1 ?? this.h1,
      h2: h2 ?? this.h2,
      titleProminent: titleProminent ?? this.titleProminent,
      cardTitle: cardTitle ?? this.cardTitle,
      body: body ?? this.body,
      bodySmall: bodySmall ?? this.bodySmall,
      caption: caption ?? this.caption,
      label: label ?? this.label,
      badge: badge ?? this.badge,
      sectionLabel: sectionLabel ?? this.sectionLabel,
      price: price ?? this.price,
      button: button ?? this.button,
      keypadDigit: keypadDigit ?? this.keypadDigit,
      codeInput: codeInput ?? this.codeInput,
    );
  }

  @override
  JeebTextStyles lerp(ThemeExtension<JeebTextStyles>? other, double t) {
    if (other is! JeebTextStyles) return this;
    return JeebTextStyles(
      statHero: TextStyle.lerp(statHero, other.statHero, t)!,
      statDisplay: TextStyle.lerp(statDisplay, other.statDisplay, t)!,
      h1: TextStyle.lerp(h1, other.h1, t)!,
      h2: TextStyle.lerp(h2, other.h2, t)!,
      titleProminent:
          TextStyle.lerp(titleProminent, other.titleProminent, t)!,
      cardTitle: TextStyle.lerp(cardTitle, other.cardTitle, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      badge: TextStyle.lerp(badge, other.badge, t)!,
      sectionLabel: TextStyle.lerp(sectionLabel, other.sectionLabel, t)!,
      price: TextStyle.lerp(price, other.price, t)!,
      button: TextStyle.lerp(button, other.button, t)!,
      keypadDigit: TextStyle.lerp(keypadDigit, other.keypadDigit, t)!,
      codeInput: TextStyle.lerp(codeInput, other.codeInput, t)!,
    );
  }
}

/// Resolves [JeebTextStyles] from the active theme.
extension JeebTextStylesX on BuildContext {
  /// The Jeeb redesign type ramp for the current theme.
  ///
  /// Falls back to [JeebTextStyles.light] if the extension is absent so call
  /// sites never null-crash; `AppTheme._build` always registers the real
  /// per-brightness variant.
  JeebTextStyles get jeebText =>
      Theme.of(this).extension<JeebTextStyles>() ?? JeebTextStyles.light();
}

/// Bundled-Inter family name. Must match `pubspec.yaml > flutter > fonts` and
/// `AppTheme._fontFamily`.
const String _fontFamily = 'Inter';

// ── The ramp itself ────────────────────────────────────────────────────────
// Sizes/weights are measured from the redesign screens, which win over
// `_ds/tokens/typography.css` (that CSS ramp matches no screen). Declared once
// at library level so light and dark cannot drift apart.

const TextStyle _statHero = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 38,
  fontWeight: FontWeight.w800,
  letterSpacing: -1,
);

const TextStyle _statDisplay = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 42,
  fontWeight: FontWeight.w800,
);

const TextStyle _h1 = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 24,
  fontWeight: FontWeight.w700,
);

const TextStyle _h2 = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 20,
  fontWeight: FontWeight.w700,
);

const TextStyle _titleProminent = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 17,
  fontWeight: FontWeight.w700,
);

const TextStyle _cardTitle = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
);

const TextStyle _body = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 13.5,
  fontWeight: FontWeight.w500,
  // `height` is a multiple of fontSize; the spec is a 19px line box.
  height: 19 / 13.5,
);

const TextStyle _bodySmall = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 12,
  fontWeight: FontWeight.w600,
);

const TextStyle _caption = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 11.5,
  fontWeight: FontWeight.w600,
);

const TextStyle _label = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 10.5,
  fontWeight: FontWeight.w700,
);

const TextStyle _badge = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 10.5,
  fontWeight: FontWeight.w800,
);

// The two section-label variants differ only in ink. The hexes mirror
// `JeebSemanticColors.mutedText` (const TextStyle cannot read a factory), and
// a theme test asserts they stay equal.
const TextStyle _sectionLabelLight = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.2,
  color: Color(0xFF777FC0),
);

const TextStyle _sectionLabelDark = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.2,
  color: Color(0xFF9DA3E0),
);

const TextStyle _price = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 21,
  fontWeight: FontWeight.w800,
);

const TextStyle _button = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 17,
  fontWeight: FontWeight.w600,
);

const TextStyle _keypadDigit = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 23,
  fontWeight: FontWeight.w700,
);

const TextStyle _codeInput = TextStyle(
  fontFamily: _fontFamily,
  fontSize: 29,
  fontWeight: FontWeight.w800,
);
