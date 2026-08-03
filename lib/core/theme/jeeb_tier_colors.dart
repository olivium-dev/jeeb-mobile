import 'package:flutter/material.dart';

@immutable
class JeebTierColors extends ThemeExtension<JeebTierColors> {
  const JeebTierColors({
    required this.flash,
    required this.express,
    required this.standard,
    required this.onTheWay,
    required this.eco,
  });

  factory JeebTierColors.standard() => const JeebTierColors(
        flash: Color(0xFFE53935),
        express: Color(0xFFFB8C00),
        standard: Color(0xFF1E88E5),
        onTheWay: Color(0xFF43A047),
        eco: Color(0xFF7CB342),
      );

  final Color flash;
  final Color express;
  final Color standard;
  final Color onTheWay;
  final Color eco;

  @override
  JeebTierColors copyWith({
    Color? flash,
    Color? express,
    Color? standard,
    Color? onTheWay,
    Color? eco,
  }) {
    return JeebTierColors(
      flash: flash ?? this.flash,
      express: express ?? this.express,
      standard: standard ?? this.standard,
      onTheWay: onTheWay ?? this.onTheWay,
      eco: eco ?? this.eco,
    );
  }

  @override
  JeebTierColors lerp(ThemeExtension<JeebTierColors>? other, double t) {
    if (other is! JeebTierColors) return this;
    return JeebTierColors(
      flash: Color.lerp(flash, other.flash, t)!,
      express: Color.lerp(express, other.express, t)!,
      standard: Color.lerp(standard, other.standard, t)!,
      onTheWay: Color.lerp(onTheWay, other.onTheWay, t)!,
      eco: Color.lerp(eco, other.eco, t)!,
    );
  }
}
