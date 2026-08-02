import 'package:flutter/material.dart';

@immutable
class JeebSemanticColors extends ThemeExtension<JeebSemanticColors> {
  const JeebSemanticColors({
    required this.mutedText,
  });

  factory JeebSemanticColors.light() => const JeebSemanticColors(
        mutedText: Color(0xFF777FC0),
      );

  factory JeebSemanticColors.dark() => const JeebSemanticColors(
        mutedText: Color(0xFF9DA3E0),
      );

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
