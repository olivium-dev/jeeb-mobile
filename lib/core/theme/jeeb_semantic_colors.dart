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
@immutable
class JeebSemanticColors extends ThemeExtension<JeebSemanticColors> {
  const JeebSemanticColors({
    required this.mutedText,
  });

  /// Light-mode variant.
  factory JeebSemanticColors.light() => const JeebSemanticColors(
        mutedText: Color(0xFF777FC0),
      );

  /// Dark-mode variant. Muted text shifts toward the brand's lighter purple.
  factory JeebSemanticColors.dark() => const JeebSemanticColors(
        mutedText: Color(0xFF9DA3E0),
      );

  /// Secondary/muted body text where `onSurfaceVariant` is too strong.
  final Color mutedText;

  @override
  JeebSemanticColors copyWith({
    Color? mutedText,
  }) {
    return JeebSemanticColors(
      mutedText: mutedText ?? this.mutedText,
    );
  }

  @override
  JeebSemanticColors lerp(ThemeExtension<JeebSemanticColors>? other, double t) {
    if (other is! JeebSemanticColors) return this;
    return JeebSemanticColors(
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
    );
  }
}
