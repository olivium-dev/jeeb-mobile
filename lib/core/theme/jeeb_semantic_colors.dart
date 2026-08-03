import 'package:flutter/material.dart';

/// App-specific semantic color tokens that don't map onto the Material 3
/// `ColorScheme` and aren't covered by `OmdsColorTokens`.
///
/// Lives as a `ThemeExtension` so call sites read from
/// `Theme.of(context).extension<JeebSemanticColors>()!.<role>` rather than
/// reaching for hex literals. Documented in
/// `docs/design/03-color-token-mapping.md` §4 (semantic roles).
///
/// NOTE (sprint-009 §G2): the `availableNow` / `availableNowRing` raw greens
/// (#22C55E family) that used to live here were deleted with the legacy
/// availability disc. Online/offline styling now resolves through the
/// semantic role layer — `context.jeebRoles.success*` (`JeebColorRoles`) —
/// never through ad-hoc greens.
///
/// Light/dark variants are provided via [JeebSemanticColors.light] and
/// [JeebSemanticColors.dark]; the active variant is wired in
/// `AppTheme._build` based on the requested [Brightness].
///
/// NOTE (redesign-2026-08 §4.1): everything added here beyond [mutedText] is
/// **decorative and NOT contrast-gated** — fills, rings, tints and an icon ink.
/// None of them may carry body text. Text ink comes from [ColorScheme] or
/// `context.jeebRoles`, both of which the WCAG gate covers.
@immutable
class JeebSemanticColors extends ThemeExtension<JeebSemanticColors> {
  const JeebSemanticColors({
    required this.mutedText,
    required this.mutedSurface,
    required this.readTick,
    required this.accentTint,
    required this.accentRing,
  });

  /// Light-mode variant.
  factory JeebSemanticColors.light() => const JeebSemanticColors(
        mutedText: Color(0xFF777FC0),
        mutedSurface: Color(0xFFF4F4F6),
        readTick: _readTick,
        accentTint: _accentTint,
        accentRing: _accentRing,
      );

  /// Dark-mode variant. Muted text shifts toward the brand's lighter purple;
  /// the muted surface becomes the dark scheme's own `surfaceContainerHigh`
  /// (`ColorScheme.fromSeed(navy, dark)`) so it stays a real step above the
  /// dark background instead of a near-white slab.
  factory JeebSemanticColors.dark() => const JeebSemanticColors(
        mutedText: Color(0xFF9DA3E0),
        mutedSurface: Color(0xFF29292F),
        readTick: _readTick,
        accentTint: _accentTint,
        accentRing: _accentRing,
      );

  /// Secondary/muted body text where `onSurfaceVariant` is too strong.
  final Color mutedText;

  /// The light-grey card fill behind offer / message rows (`#F4F4F6`). A fill
  /// only — pair it with `onSurface` ink, never with [mutedText].
  final Color mutedSurface;

  /// Cyan read-receipt double-tick, on navy outgoing chat bubbles only. A
  /// decorative icon ink at ~16px; it is not AA as text and must not be used
  /// as one.
  final Color readTick;

  /// Brand orange at 12% — badge and pill backgrounds ("Most picked", "Best
  /// value"). Translucent, so it composites over whatever surface it sits on;
  /// the badge label on top is `jeebRoles.accent` at w800.
  final Color accentTint;

  /// Brand orange at 30% — the decorative stroked circles on navy hero cards.
  /// Stroke only, never a fill behind content.
  final Color accentRing;

  @override
  JeebSemanticColors copyWith({
    Color? mutedText,
    Color? mutedSurface,
    Color? readTick,
    Color? accentTint,
    Color? accentRing,
  }) {
    return JeebSemanticColors(
      mutedText: mutedText ?? this.mutedText,
      mutedSurface: mutedSurface ?? this.mutedSurface,
      readTick: readTick ?? this.readTick,
      accentTint: accentTint ?? this.accentTint,
      accentRing: accentRing ?? this.accentRing,
    );
  }

  @override
  JeebSemanticColors lerp(ThemeExtension<JeebSemanticColors>? other, double t) {
    if (other is! JeebSemanticColors) return this;
    return JeebSemanticColors(
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      mutedSurface: Color.lerp(mutedSurface, other.mutedSurface, t)!,
      readTick: Color.lerp(readTick, other.readTick, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      accentRing: Color.lerp(accentRing, other.accentRing, t)!,
    );
  }
}

// Brightness-independent decorative values. The two accent tints are
// alpha-based (`rgba(215,59,0,…)` in `_ds/tokens`), so they composite
// correctly on either background and are deliberately NOT re-toned for dark.
const Color _readTick = Color(0xFF20F0FF);
const Color _accentTint = Color.fromRGBO(215, 59, 0, 0.12);
const Color _accentRing = Color.fromRGBO(215, 59, 0, 0.30);
