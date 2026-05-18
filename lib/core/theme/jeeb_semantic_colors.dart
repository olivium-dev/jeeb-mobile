import 'package:flutter/material.dart';

/// App-specific semantic color tokens that don't map onto the Material 3
/// `ColorScheme` and aren't covered by `OmdsColorTokens`.
///
/// Lives as a `ThemeExtension` so call sites read from
/// `Theme.of(context).extension<JeebSemanticColors>()!.<role>` rather than
/// reaching for hex literals. Documented in
/// `docs/design/03-color-token-mapping.md` §4 (semantic roles).
///
/// Light/dark variants are provided via [JeebSemanticColors.light] and
/// [JeebSemanticColors.dark]; the active variant is wired in
/// `AppTheme._build` based on the requested [Brightness].
@immutable
class JeebSemanticColors extends ThemeExtension<JeebSemanticColors> {
  const JeebSemanticColors({
    required this.availableNow,
    required this.availableNowRing,
    required this.mutedText,
  });

  /// Light-mode variant. Brand greens are the dispatcher "online toggle"
  /// colors agreed with design (Figma node 56535:1525, "Available now"
  /// switch).
  factory JeebSemanticColors.light() => const JeebSemanticColors(
        availableNow: Color(0xFF22C55E),
        availableNowRing: Color(0xFF16A34A),
        mutedText: Color(0xFF777FC0),
      );

  /// Dark-mode variant. Lifted greens for AA contrast on dark surfaces;
  /// muted text shifts toward the brand's lighter purple.
  factory JeebSemanticColors.dark() => const JeebSemanticColors(
        availableNow: Color(0xFF4ADE80),
        availableNowRing: Color(0xFF22C55E),
        mutedText: Color(0xFF9DA3E0),
      );

  /// Fill color of the dispatcher "available now" toggle when active.
  final Color availableNow;

  /// Outer ring of the "available now" toggle (focus / pressed state).
  final Color availableNowRing;

  /// Secondary/muted body text where `onSurfaceVariant` is too strong.
  final Color mutedText;

  @override
  JeebSemanticColors copyWith({
    Color? availableNow,
    Color? availableNowRing,
    Color? mutedText,
  }) {
    return JeebSemanticColors(
      availableNow: availableNow ?? this.availableNow,
      availableNowRing: availableNowRing ?? this.availableNowRing,
      mutedText: mutedText ?? this.mutedText,
    );
  }

  @override
  JeebSemanticColors lerp(ThemeExtension<JeebSemanticColors>? other, double t) {
    if (other is! JeebSemanticColors) return this;
    return JeebSemanticColors(
      availableNow: Color.lerp(availableNow, other.availableNow, t)!,
      availableNowRing:
          Color.lerp(availableNowRing, other.availableNowRing, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
    );
  }
}
