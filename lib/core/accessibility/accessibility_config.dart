import 'package:flutter/material.dart';

class AccessibilityConfig {
  static const double minTouchTarget = 48.0;
  static const double minContrastRatio = 4.5;

  static TextTheme scaledTextTheme(TextTheme base, double scaleFactor) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(fontSize: (base.displayLarge?.fontSize ?? 57) * scaleFactor),
      displayMedium: base.displayMedium?.copyWith(fontSize: (base.displayMedium?.fontSize ?? 45) * scaleFactor),
      displaySmall: base.displaySmall?.copyWith(fontSize: (base.displaySmall?.fontSize ?? 36) * scaleFactor),
      headlineLarge: base.headlineLarge?.copyWith(fontSize: (base.headlineLarge?.fontSize ?? 32) * scaleFactor),
      headlineMedium: base.headlineMedium?.copyWith(fontSize: (base.headlineMedium?.fontSize ?? 28) * scaleFactor),
      headlineSmall: base.headlineSmall?.copyWith(fontSize: (base.headlineSmall?.fontSize ?? 24) * scaleFactor),
      titleLarge: base.titleLarge?.copyWith(fontSize: (base.titleLarge?.fontSize ?? 22) * scaleFactor),
      titleMedium: base.titleMedium?.copyWith(fontSize: (base.titleMedium?.fontSize ?? 16) * scaleFactor),
      titleSmall: base.titleSmall?.copyWith(fontSize: (base.titleSmall?.fontSize ?? 14) * scaleFactor),
      bodyLarge: base.bodyLarge?.copyWith(fontSize: (base.bodyLarge?.fontSize ?? 16) * scaleFactor),
      bodyMedium: base.bodyMedium?.copyWith(fontSize: (base.bodyMedium?.fontSize ?? 14) * scaleFactor),
      bodySmall: base.bodySmall?.copyWith(fontSize: (base.bodySmall?.fontSize ?? 12) * scaleFactor),
      labelLarge: base.labelLarge?.copyWith(fontSize: (base.labelLarge?.fontSize ?? 14) * scaleFactor),
      labelMedium: base.labelMedium?.copyWith(fontSize: (base.labelMedium?.fontSize ?? 12) * scaleFactor),
      labelSmall: base.labelSmall?.copyWith(fontSize: (base.labelSmall?.fontSize ?? 11) * scaleFactor),
    );
  }
}
