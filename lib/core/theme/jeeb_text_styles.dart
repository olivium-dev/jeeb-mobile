import 'package:flutter/material.dart';

import 'jeeb_midnight_palette.dart';

/// The MIDNIGHT type ramp (token sheet §6). Rides ALONGSIDE the M3 [TextTheme],
/// which stays unreshaped so the ~770 existing files are untouched.
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

  /// Named `.light()` for API stability only.
  factory JeebTextStyles.light() => JeebTextStyles.midnight();

  /// Named `.dark()` for API stability only.
  factory JeebTextStyles.dark() => JeebTextStyles.midnight();

  /// Token sheet §6.
  factory JeebTextStyles.midnight() => const JeebTextStyles(
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
        sectionLabel: _sectionLabel,
        price: _price,
        button: _button,
        keypadDigit: _keypadDigit,
        codeInput: _codeInput,
      );

  /// 40/w800/−1.2 — hero numbers (earnings, wallet balance).
  final TextStyle statHero;

  /// 44/w800 — the at-door code display tiles.
  final TextStyle statDisplay;

  /// 26/w700/−0.6 — screen headlines.
  final TextStyle h1;

  /// 20/w700/−0.5 — top-bar titles and card headlines.
  final TextStyle h2;

  /// 17/w700/−0.2 — two-line bar titles, statement lines.
  final TextStyle titleProminent;

  /// 15.5/w700 — offer / tier card names.
  final TextStyle cardTitle;

  /// 14.5/w500, 21px line — chat bubbles and body copy.
  final TextStyle body;

  /// 12.5/w600 — subtitles and meta rows.
  final TextStyle bodySmall;

  /// 11.5/w600 — ETA and cash lines.
  final TextStyle caption;

  /// 10.5/w700 — stepper labels, meter captions.
  final TextStyle label;

  /// 10.5/w800/+1.0 — uppercase badges ("Best value", "Most picked").
  final TextStyle badge;

  /// 11/w700/+1.2, muted ink. `toUpperCase()` is applied at the call site.
  final TextStyle sectionLabel;

  /// 22/w800/−0.5 — offer prices and money emphasis.
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
  /// Falls back to the ramp when no theme provides it, so no call site crashes.
  JeebTextStyles get jeebText =>
      Theme.of(this).extension<JeebTextStyles>() ?? JeebTextStyles.midnight();
}

/// Must match `pubspec.yaml > flutter > fonts`.
const String jeebFontFamily = 'Inter';

/// Arabic brand face (exact `_ds/tokens/typography.css` string) then the iOS
/// and Android emoji families — Inter covers neither.
const List<String> jeebFontFamilyFallback = <String>[
  'Baloo Bhaijaan 2',
  'Apple Color Emoji',
  'Noto Color Emoji',
];


const TextStyle _statHero = TextStyle(
  fontFamily: jeebFontFamily,
  fontFamilyFallback: jeebFontFamilyFallback,
  fontSize: 40,
  fontWeight: FontWeight.w800,
  letterSpacing: -1.2,
);

const TextStyle _statDisplay = TextStyle(
  fontFamily: jeebFontFamily,
  fontFamilyFallback: jeebFontFamilyFallback,
  fontSize: 44,
  fontWeight: FontWeight.w800,
);

const TextStyle _h1 = TextStyle(
  fontFamily: jeebFontFamily,
  fontFamilyFallback: jeebFontFamilyFallback,
  fontSize: 26,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.6,
);

const TextStyle _h2 = TextStyle(
  fontFamily: jeebFontFamily,
  fontFamilyFallback: jeebFontFamilyFallback,
  fontSize: 20,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.5,
);

const TextStyle _titleProminent = TextStyle(
  fontFamily: jeebFontFamily,
  fontFamilyFallback: jeebFontFamilyFallback,
  fontSize: 17,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
);

const TextStyle _cardTitle = TextStyle(
  fontFamily: jeebFontFamily,
  fontFamilyFallback: jeebFontFamilyFallback,
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
);

const TextStyle _body = TextStyle(
  fontFamily: jeebFontFamily,
  fontFamilyFallback: jeebFontFamilyFallback,
  fontSize: 14.5,
  fontWeight: FontWeight.w500,
  height: 21 / 14.5,
);

const TextStyle _bodySmall = TextStyle(
  fontFamily: jeebFontFamily,
  fontFamilyFallback: jeebFontFamilyFallback,
  fontSize: 12.5,
  fontWeight: FontWeight.w600,
);

const TextStyle _caption = TextStyle(
  fontFamily: jeebFontFamily,
  fontFamilyFallback: jeebFontFamilyFallback,
  fontSize: 11.5,
  fontWeight: FontWeight.w600,
);

const TextStyle _label = TextStyle(
  fontFamily: jeebFontFamily,
  fontFamilyFallback: jeebFontFamilyFallback,
  fontSize: 10.5,
  fontWeight: FontWeight.w700,
);

const TextStyle _badge = TextStyle(
  fontFamily: jeebFontFamily,
  fontFamilyFallback: jeebFontFamilyFallback,
  fontSize: 10.5,
  fontWeight: FontWeight.w800,
  letterSpacing: 1,
);

/// One ink for both factories; a theme test binds it to `mutedText`.
const TextStyle _sectionLabel = TextStyle(
  fontFamily: jeebFontFamily,
  fontFamilyFallback: jeebFontFamilyFallback,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.2,
  color: JeebMidnight.inkMuted,
);

const TextStyle _price = TextStyle(
  fontFamily: jeebFontFamily,
  fontFamilyFallback: jeebFontFamilyFallback,
  fontSize: 22,
  fontWeight: FontWeight.w800,
  letterSpacing: -0.5,
);

const TextStyle _button = TextStyle(
  fontFamily: jeebFontFamily,
  fontFamilyFallback: jeebFontFamilyFallback,
  fontSize: 17,
  fontWeight: FontWeight.w600,
);

const TextStyle _keypadDigit = TextStyle(
  fontFamily: jeebFontFamily,
  fontFamilyFallback: jeebFontFamilyFallback,
  fontSize: 23,
  fontWeight: FontWeight.w700,
);

const TextStyle _codeInput = TextStyle(
  fontFamily: jeebFontFamily,
  fontFamilyFallback: jeebFontFamilyFallback,
  fontSize: 29,
  fontWeight: FontWeight.w800,
);
