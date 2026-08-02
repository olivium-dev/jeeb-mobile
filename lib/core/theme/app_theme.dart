import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omds/omds.dart';

import 'jeeb_color_roles.dart';
import 'jeeb_semantic_colors.dart';
import 'jeeb_tier_colors.dart';

class AppTheme {
  AppTheme._();

  static const String _fontFamily = 'Inter';

  static const Color _jeebNavy = Color(0xFF0B1351);
  static const Color _jeebOrange = Color(0xFFD73B00);
  static const Color _jeebMutedPurple = Color(0xFF777FC0);
  static const Color _jeebWarmBrown = Color(0xFF916F66);
  static const Color _jeebSubtitle = Color(0xFF5C4038);
  static const Color _jeebSurfaceHigh = Color(0xFFEAE7EB);
  static const Color _jeebSurfaceHighest = Color(0xFFE5E1E5);

  static const Color _jeebOrangeContainer = Color(0xFFFFDBD1);
  static const Color _jeebOnOrangeContainer = Color(0xFF3A0B01);

  static const Color _jeebSurfaceLow = Color(0xFFFAF8FA);
  static const Color _jeebSurfaceContainer = Color(0xFFF5F3F6);

  static const Color _jeebOnSurface = Color(0xFF0B0E53);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final colorScheme = isLight
        ? const ColorScheme.light(
            primary: _jeebNavy,
            onPrimary: Colors.white,
            primaryContainer: _jeebOrangeContainer,
            onPrimaryContainer: _jeebOnOrangeContainer,
            secondary: _jeebNavy,
            onSecondary: Colors.white,
            secondaryContainer: _jeebNavy,
            onSecondaryContainer: _jeebMutedPurple,
            tertiary: _jeebOrange,
            onTertiary: Colors.white,
            tertiaryContainer: _jeebOrangeContainer,
            onTertiaryContainer: _jeebOnOrangeContainer,
            surface: Colors.white,
            onSurface: _jeebOnSurface,
            onSurfaceVariant: _jeebSubtitle,
            outline: _jeebWarmBrown,
            outlineVariant: _jeebSurfaceHighest,
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: _jeebSurfaceLow,
            surfaceContainer: _jeebSurfaceContainer,
            surfaceContainerHighest: _jeebSurfaceHighest,
            surfaceContainerHigh: _jeebSurfaceHigh,
          )
        : ColorScheme.fromSeed(
            seedColor: _jeebNavy,
            brightness: Brightness.dark,
          );

    final baseTextTheme = _interTextTheme(
      isLight ? ThemeData.light().textTheme : ThemeData.dark().textTheme,
    );

    final omds = OmdsTheme(baseTextTheme);
    final base = isLight
        ? omds.lightWithScheme(colorScheme)
        : omds.darkWithScheme(colorScheme);

    final List<ThemeExtension<dynamic>> extensions = <dynamic>[
      JeebTierColors.standard(),
      isLight ? JeebSemanticColors.light() : JeebSemanticColors.dark(),
      isLight ? JeebColorRoles.light() : JeebColorRoles.dark(),
      ...base.extensions.values,
    ].cast<ThemeExtension<dynamic>>();

    return base.copyWith(
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        hintStyle: base.inputDecorationTheme.hintStyle?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.primary,
        elevation: 0,
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              ),
      ),
      scaffoldBackgroundColor: isLight ? colorScheme.surface : null,
      chipTheme: ChipThemeData(
        selectedColor: colorScheme.primary,
        labelStyle: baseTextTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: OmdsBorderRadius.xSmall,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return baseTextTheme.labelSmall?.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.2,
            color: isSelected ? colorScheme.primary : colorScheme.outline,
          );
        }),
      ),
      extensions: extensions,
    );
  }

  static TextTheme _interTextTheme(TextTheme base) =>
      base.apply(fontFamily: _fontFamily);
}
