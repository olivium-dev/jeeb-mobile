import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omds/omds.dart';

import 'jeeb_color_roles.dart';
import 'jeeb_midnight_palette.dart';
import 'jeeb_semantic_colors.dart';
import 'jeeb_text_styles.dart';
import 'jeeb_tier_colors.dart';

/// The one Jeeb theme: MIDNIGHT (token sheet §1, master plan §2.2/§2.4).
/// [light] and [dark] both return [midnight]; `themeMode` is pinned dark.
class AppTheme {
  AppTheme._();

  /// Token sheet §1. `surfaceTint` is transparent because M3 elevation tinting
  /// overlays `primary` and drifts every raised navy surface orange-purple.
  static const ColorScheme midnightScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: JeebMidnight.orange,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: JeebMidnight.orangeContainer,
    onPrimaryContainer: JeebMidnight.orangeTint,
    secondary: JeebMidnight.inkMuted,
    onSecondary: JeebMidnight.page,
    secondaryContainer: JeebMidnight.surfaceHigh,
    onSecondaryContainer: JeebMidnight.inkSoft,
    // Compat alias of `primary` — pass-1 files reference `.tertiary`.
    tertiary: JeebMidnight.orange,
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: JeebMidnight.orangeContainer,
    onTertiaryContainer: JeebMidnight.orangeTint,
    error: JeebMidnight.danger,
    // NOT white: white on #FF5252 is ~3.1:1 and fails AA; navy is 5.93:1.
    onError: JeebMidnight.page,
    errorContainer: JeebMidnight.dangerContainer,
    onErrorContainer: JeebMidnight.dangerSoft,
    surface: JeebMidnight.surface,
    onSurface: JeebMidnight.ink,
    onSurfaceVariant: JeebMidnight.inkMuted,
    surfaceDim: JeebMidnight.page,
    surfaceBright: JeebMidnight.surfaceHighest,
    surfaceContainerLowest: JeebMidnight.page,
    surfaceContainerLow: JeebMidnight.surfaceLow,
    surfaceContainer: JeebMidnight.surface,
    surfaceContainerHigh: JeebMidnight.surfaceHigh,
    surfaceContainerHighest: JeebMidnight.surfaceHighest,
    outline: JeebMidnight.outline,
    outlineVariant: JeebMidnight.outlineVariant,
    surfaceTint: Colors.transparent,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    // Set so nothing falls back to a Material default light slab.
    inverseSurface: JeebMidnight.ink,
    onInverseSurface: JeebMidnight.page,
    inversePrimary: JeebMidnight.orangeTint,
  );

  /// §2.4. `statusBarBrightness` (iOS) is the BACKGROUND brightness while
  /// `statusBarIconBrightness` (Android) is the GLYPH brightness — hence dark/light.
  static const SystemUiOverlayStyle systemOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: JeebMidnight.page,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  /// Named `light()` for API stability only.
  static ThemeData light() => midnight();

  /// Named `dark()` for API stability only.
  static ThemeData dark() => midnight();

  /// The one theme.
  static ThemeData midnight() => _build();

  // Radii ladder §5, private: the public kit tokens are M1's call.
  static const double _rSm = 9;
  static const double _rMd = 14;
  static const double _rLg = 18;
  static const double _rSheet = 26;

  static ThemeData _build() {
    const ColorScheme scheme = midnightScheme;

    // Metrics untouched; only the family + Arabic/emoji fallback are applied.
    final TextTheme baseTextTheme = ThemeData.dark().textTheme.apply(
          fontFamily: jeebFontFamily,
          fontFamilyFallback: jeebFontFamilyFallback,
        );

    final ThemeData base = OmdsTheme(baseTextTheme).darkWithScheme(scheme);

    final List<ThemeExtension<dynamic>> extensions = <dynamic>[
      JeebTierColors.standard(),
      JeebSemanticColors.midnight(),
      JeebColorRoles.midnight(),
      JeebTextStyles.midnight(),
      ...base.extensions.values,
    ].cast<ThemeExtension<dynamic>>();

    return base.copyWith(
      // Fallback only — screens mount `JeebMidnightField` (M0-3). OMDS would
      // default this to the card navy, one step too light.
      scaffoldBackgroundColor: JeebMidnight.page,
      canvasColor: JeebMidnight.surface,
      cardColor: JeebMidnight.surface,
      dividerColor: JeebMidnight.divider,
      shadowColor: const Color(0xFF000000),
      hintColor: JeebMidnight.inkMuted,
      disabledColor: const Color(0x61FFFFFF),
      unselectedWidgetColor: JeebMidnight.inkMuted,

      // White alpha, never Material purple.
      splashFactory: InkRipple.splashFactory,
      splashColor: const Color(0x14FFFFFF),
      highlightColor: const Color(0x0DFFFFFF),
      hoverColor: const Color(0x0FFFFFFF),
      focusColor: const Color(0x1FFFFFFF),

      // Transparent over the field; scrolled-under elevation would tint it.
      appBarTheme: AppBarThemeData(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: JeebMidnight.ink,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: JeebMidnight.ink),
        actionsIconTheme: const IconThemeData(color: JeebMidnight.ink),
        titleTextStyle: JeebTextStyles.midnight()
            .h2
            .copyWith(color: JeebMidnight.ink),
        systemOverlayStyle: systemOverlayStyle,
      ),

      // Fallbacks only — the real nav is a kit glass pill (M1). Active tab is
      // sanctioned orange (R1 caption).
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: JeebMidnight.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return JeebTextStyles.midnight().label.copyWith(
                color: selected ? JeebMidnight.orange : JeebMidnight.inkMuted,
              );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final bool selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? JeebMidnight.orange : JeebMidnight.inkMuted,
          );
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: JeebMidnight.surface,
        selectedItemColor: JeebMidnight.orange,
        unselectedItemColor: JeebMidnight.inkMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),

      cardTheme: CardThemeData(
        color: JeebMidnight.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rLg),
          side: const BorderSide(color: JeebMidnight.glassBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: JeebMidnight.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0xFF000000),
        elevation: 0,
        iconColor: JeebMidnight.inkMuted,
        barrierColor: const Color(0xB3070C33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rSheet),
          side: const BorderSide(color: JeebMidnight.glassBorder),
        ),
        titleTextStyle:
            JeebTextStyles.midnight().h2.copyWith(color: JeebMidnight.ink),
        contentTextStyle: JeebTextStyles.midnight()
            .body
            .copyWith(color: JeebMidnight.inkSoft),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: JeebMidnight.surface,
        modalBackgroundColor: JeebMidnight.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0xFF000000),
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: JeebMidnight.inkMuted,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_rSheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        // NOT `inverseSurface`: M3 would invert this to a light slab.
        backgroundColor: JeebMidnight.surfaceHigh,
        contentTextStyle: JeebTextStyles.midnight()
            .body
            .copyWith(color: JeebMidnight.ink),
        actionTextColor: JeebMidnight.inkSoft,
        closeIconColor: JeebMidnight.inkMuted,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rMd),
          side: const BorderSide(color: JeebMidnight.glassBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: JeebMidnight.divider,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: JeebMidnight.glassFill,
        textColor: JeebMidnight.ink,
        iconColor: JeebMidnight.inkMuted,
        selectedColor: JeebMidnight.inkSoft,
        titleTextStyle:
            JeebTextStyles.midnight().body.copyWith(color: JeebMidnight.ink),
        subtitleTextStyle: JeebTextStyles.midnight()
            .bodySmall
            .copyWith(color: JeebMidnight.inkMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rMd),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: JeebMidnight.surfaceHighest,
          borderRadius: BorderRadius.circular(_rSm),
          border: const Border.fromBorderSide(
            BorderSide(color: JeebMidnight.glassBorder),
          ),
        ),
        textStyle: JeebTextStyles.midnight()
            .bodySmall
            .copyWith(color: JeebMidnight.ink),
      ),

      // Highest slab so a menu separates from the card underneath.
      popupMenuTheme: PopupMenuThemeData(
        color: JeebMidnight.surfaceHighest,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0xFF000000),
        elevation: 8,
        textStyle:
            JeebTextStyles.midnight().body.copyWith(color: JeebMidnight.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rMd),
          side: const BorderSide(color: JeebMidnight.glassBorder),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const WidgetStatePropertyAll<Color>(
            JeebMidnight.surfaceHighest,
          ),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
          shadowColor: const WidgetStatePropertyAll<Color>(Color(0xFF000000)),
          elevation: const WidgetStatePropertyAll<double>(8),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_rMd),
              side: const BorderSide(color: JeebMidnight.glassBorder),
            ),
          ),
        ),
      ),

      // Frosted capsules, never an orange fill.
      chipTheme: ChipThemeData(
        backgroundColor: JeebMidnight.glassFill,
        selectedColor: JeebMidnight.glassFillPressed,
        disabledColor: JeebMidnight.glassFill,
        checkmarkColor: JeebMidnight.ink,
        surfaceTintColor: Colors.transparent,
        side: const BorderSide(color: JeebMidnight.glassBorder),
        labelStyle: JeebTextStyles.midnight()
            .bodySmall
            .copyWith(color: JeebMidnight.ink),
        secondaryLabelStyle: JeebTextStyles.midnight()
            .bodySmall
            .copyWith(color: JeebMidnight.inkSoft),
        // Pill, not an 8px rect — `OmdsChip` already draws itself as a pill and
        // the two chip families must not disagree side by side.
        shape: const StadiumBorder(),
      ),

      // ONE frosted box, no box-in-a-box. Replaces the OMDS white-field theme.
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: JeebMidnight.glassFill,
        hintStyle: JeebTextStyles.midnight()
            .body
            .copyWith(color: JeebMidnight.inkMuted),
        labelStyle: JeebTextStyles.midnight()
            .bodySmall
            .copyWith(color: JeebMidnight.inkMuted),
        floatingLabelStyle: JeebTextStyles.midnight()
            .bodySmall
            .copyWith(color: JeebMidnight.inkSoft),
        helperStyle: JeebTextStyles.midnight()
            .caption
            .copyWith(color: JeebMidnight.inkMuted),
        errorStyle: JeebTextStyles.midnight()
            .caption
            .copyWith(color: JeebMidnight.dangerSoft),
        counterStyle: JeebTextStyles.midnight()
            .caption
            .copyWith(color: JeebMidnight.inkMuted),
        prefixIconColor: JeebMidnight.inkMuted,
        suffixIconColor: JeebMidnight.inkMuted,
        iconColor: JeebMidnight.inkMuted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: _inputBorder(JeebMidnight.glassBorder),
        enabledBorder: _inputBorder(JeebMidnight.glassBorder),
        disabledBorder: _inputBorder(const Color(0x0FFFFFFF)),
        focusedBorder: _inputBorder(JeebMidnight.inkMuted, width: 1.5),
        errorBorder: _inputBorder(JeebMidnight.danger, width: 1.5),
        focusedErrorBorder: _inputBorder(JeebMidnight.danger, width: 2),
      ),
      // Periwinkle, not orange: a caret is not brand state (§2.2).
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: JeebMidnight.inkMuted,
        selectionColor: Color(0x4D8A93D8),
        selectionHandleColor: JeebMidnight.inkMuted,
      ),

      // Orange-budget override: OMDS points all four at `primary`. The kit's
      // accent CTA (M1) is where an orange button comes from.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: JeebMidnight.inkMuted,
          foregroundColor: JeebMidnight.page,
          disabledBackgroundColor: JeebMidnight.glassFillPressed,
          disabledForegroundColor: JeebMidnight.inkMuted,
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          textStyle: JeebTextStyles.midnight().button,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: JeebMidnight.inkMuted,
          foregroundColor: JeebMidnight.page,
          disabledBackgroundColor: JeebMidnight.glassFillPressed,
          disabledForegroundColor: JeebMidnight.inkMuted,
          shadowColor: Colors.transparent,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          textStyle: JeebTextStyles.midnight().button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: JeebMidnight.ink,
          disabledForegroundColor: JeebMidnight.inkMuted,
          side: const BorderSide(color: JeebMidnight.glassBorderStrong),
          minimumSize: const Size(64, 48),
          shape: const StadiumBorder(),
          textStyle: JeebTextStyles.midnight().button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: JeebMidnight.inkSoft,
          disabledForegroundColor: JeebMidnight.inkMuted,
          minimumSize: const Size(64, 40),
          textStyle: JeebTextStyles.midnight().button,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: JeebMidnight.inkMuted,
        foregroundColor: JeebMidnight.page,
        splashColor: Color(0x14FFFFFF),
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: JeebMidnight.inkMuted,
          disabledForegroundColor: const Color(0x61FFFFFF),
        ),
      ),

      // Widget-level `activeColor` still wins, so `OmdsSwitchTile`'s green
      // availability toggle keeps its explicit color.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? JeebMidnight.page
              : JeebMidnight.inkMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? JeebMidnight.inkMuted
              : JeebMidnight.glassFill;
        }),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          JeebMidnight.glassBorderStrong,
        ),
        overlayColor: const WidgetStatePropertyAll<Color>(Color(0x14FFFFFF)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? JeebMidnight.inkMuted
              : Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll<Color>(JeebMidnight.page),
        overlayColor: const WidgetStatePropertyAll<Color>(Color(0x14FFFFFF)),
        side: const BorderSide(
          color: JeebMidnight.glassBorderStrong,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? JeebMidnight.inkMuted
              : JeebMidnight.glassBorderStrong;
        }),
        overlayColor: const WidgetStatePropertyAll<Color>(Color(0x14FFFFFF)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: JeebMidnight.inkMuted,
        inactiveTrackColor: JeebMidnight.glassBorder,
        thumbColor: JeebMidnight.ink,
        overlayColor: const Color(0x1F8A93D8),
        valueIndicatorColor: JeebMidnight.surfaceHigh,
        activeTickMarkColor: JeebMidnight.page,
        inactiveTickMarkColor: JeebMidnight.inkMuted,
        valueIndicatorTextStyle: JeebTextStyles.midnight()
            .bodySmall
            .copyWith(color: JeebMidnight.ink),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: JeebMidnight.inkMuted,
        linearTrackColor: JeebMidnight.glassBorder,
        circularTrackColor: JeebMidnight.glassBorder,
        refreshBackgroundColor: JeebMidnight.surfaceHigh,
      ),

      // The one place Material keeps the orange (R1: mic + active tab).
      tabBarTheme: TabBarThemeData(
        labelColor: JeebMidnight.orange,
        unselectedLabelColor: JeebMidnight.inkMuted,
        indicatorColor: JeebMidnight.orange,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        overlayColor: const WidgetStatePropertyAll<Color>(Color(0x14FFFFFF)),
        labelStyle: JeebTextStyles.midnight().cardTitle,
        unselectedLabelStyle: JeebTextStyles.midnight().cardTitle,
      ),

      // Material's most stubborn light surfaces.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: JeebMidnight.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0xFF000000),
        elevation: 0,
        headerBackgroundColor: JeebMidnight.surfaceHigh,
        headerForegroundColor: JeebMidnight.ink,
        weekdayStyle: JeebTextStyles.midnight()
            .caption
            .copyWith(color: JeebMidnight.inkMuted),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return JeebMidnight.page;
          if (states.contains(WidgetState.disabled)) {
            return const Color(0x61FFFFFF);
          }
          return JeebMidnight.ink;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? JeebMidnight.inkMuted
              : Colors.transparent;
        }),
        todayForegroundColor:
            const WidgetStatePropertyAll<Color>(JeebMidnight.inkSoft),
        todayBorder: const BorderSide(color: JeebMidnight.inkMuted),
        yearForegroundColor:
            const WidgetStatePropertyAll<Color>(JeebMidnight.ink),
        rangeSelectionBackgroundColor: JeebMidnight.surfaceHigh,
        dividerColor: JeebMidnight.divider,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rSheet),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: JeebMidnight.surface,
        elevation: 0,
        dialBackgroundColor: JeebMidnight.surfaceHigh,
        dialHandColor: JeebMidnight.inkMuted,
        // Typed `Color?` but resolve `WidgetStateColor`, which is a Color.
        dialTextColor: WidgetStateColor.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? JeebMidnight.page
              : JeebMidnight.ink;
        }),
        hourMinuteColor: WidgetStateColor.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? JeebMidnight.surfaceHighest
              : JeebMidnight.glassFill;
        }),
        hourMinuteTextColor: JeebMidnight.ink,
        dayPeriodColor: JeebMidnight.glassFill,
        dayPeriodTextColor: JeebMidnight.ink,
        dayPeriodBorderSide:
            const BorderSide(color: JeebMidnight.glassBorder),
        entryModeIconColor: JeebMidnight.inkMuted,
        helpTextStyle: JeebTextStyles.midnight()
            .caption
            .copyWith(color: JeebMidnight.inkMuted),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rSheet),
        ),
      ),

      extensions: extensions,
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(_rMd),
        borderSide: BorderSide(color: color, width: width),
      );
}
