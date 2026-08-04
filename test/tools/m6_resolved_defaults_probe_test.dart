// M6 RESOLVED-DEFAULTS PROBE — TEMPORARY AUDIT INSTRUMENT, NOT A GATE.
// Prints the value a Material widget would actually resolve under
// AppTheme.midnight() for every sub-theme the app leaves unset. Always passes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';

String _hex(Color? c) {
  if (c == null) return 'null';
  int ch(double v) => (v * 255).round();
  return '#${ch(c.a).toRadixString(16).padLeft(2, '0')}'
          '${ch(c.r).toRadixString(16).padLeft(2, '0')}'
          '${ch(c.g).toRadixString(16).padLeft(2, '0')}'
          '${ch(c.b).toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

const Set<WidgetState> _sel = <WidgetState>{WidgetState.selected};

void main() {
  testWidgets('resolved Material defaults under Midnight', (
    WidgetTester tester,
  ) async {
    final ThemeData theme = AppTheme.midnight();
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (BuildContext c) {
            ctx = c;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    final StringBuffer sb = StringBuffer('\n### RESOLVED DEFAULTS\n');
    void line(String k, Object? v) => sb.writeln('    $k = $v');

    line('colorScheme.primary', _hex(theme.colorScheme.primary));
    line('iconTheme.color (bare Icon)', _hex(theme.iconTheme.color));
    line('primaryIconTheme.color', _hex(theme.primaryIconTheme.color));

    // Sub-themes the app never sets (study notes ruling 5 + neighbours).
    for (final MapEntry<String, Object?> e in <String, Object?>{
      'drawerTheme': theme.drawerTheme,
      'navigationDrawerTheme': theme.navigationDrawerTheme,
      'navigationRailTheme': theme.navigationRailTheme,
      'searchBarTheme': theme.searchBarTheme,
      'searchViewTheme': theme.searchViewTheme,
      'dropdownMenuTheme': theme.dropdownMenuTheme,
      'segmentedButtonTheme': theme.segmentedButtonTheme,
      'expansionTileTheme': theme.expansionTileTheme,
      'scrollbarTheme': theme.scrollbarTheme,
      'badgeTheme': theme.badgeTheme,
      'bannerTheme': theme.bannerTheme,
      'bottomAppBarTheme': theme.bottomAppBarTheme,
      'toggleButtonsTheme': theme.toggleButtonsTheme,
      'dataTableTheme': theme.dataTableTheme,
      'menuButtonTheme': theme.menuButtonTheme,
      'menuBarTheme': theme.menuBarTheme,
      'buttonBarTheme?': theme.actionIconTheme,
    }.entries) {
      line('${e.key} == its bare default?', '${e.value}'.length < 200
          ? '${e.value}'
          : 'set (long)');
    }

    // The two DatePicker slots the theme forgot.
    final DatePickerThemeData dpApp = DatePickerTheme.of(ctx);
    final DatePickerThemeData dpDef = DatePickerTheme.defaults(ctx);
    line('datePicker.dayBackgroundColor[selected] (APP)',
        _hex(dpApp.dayBackgroundColor?.resolve(_sel)));
    line('datePicker.todayBackgroundColor (APP)',
        dpApp.todayBackgroundColor == null
            ? 'NULL -> falls through'
            : _hex(dpApp.todayBackgroundColor?.resolve(_sel)));
    line('datePicker.todayBackgroundColor[selected] (DEFAULT)',
        _hex(dpDef.todayBackgroundColor?.resolve(_sel)));
    line('datePicker.yearBackgroundColor (APP)',
        dpApp.yearBackgroundColor == null
            ? 'NULL -> falls through'
            : _hex(dpApp.yearBackgroundColor?.resolve(_sel)));
    line('datePicker.yearBackgroundColor[selected] (DEFAULT)',
        _hex(dpDef.yearBackgroundColor?.resolve(_sel)));
    line('datePicker.rangePickerHeaderBackgroundColor (DEFAULT)',
        _hex(dpDef.rangePickerHeaderBackgroundColor));
    line('datePicker.rangeSelectionBackgroundColor (APP)',
        _hex(dpApp.rangeSelectionBackgroundColor));

    // ExpansionTile: the expanded icon.
    final ExpansionTileThemeData etApp = ExpansionTileTheme.of(ctx);
    line('expansionTile.iconColor (APP)', _hex(etApp.iconColor));
    line('expansionTile.textColor (APP)', _hex(etApp.textColor));

    // DropdownMenu: does it inherit the app frosted field?
    final DropdownMenuThemeData dmApp = DropdownMenuTheme.of(ctx);
    line('dropdownMenu.inputDecorationTheme (APP)',
        dmApp.inputDecorationTheme == null
            ? 'NULL -> DropdownMenu uses its OWN bare OutlineInputBorder'
            : 'set');
    line('theme.inputDecorationTheme.fillColor',
        _hex(theme.inputDecorationTheme.fillColor));

    // Bottom-sheet scrim.
    line('bottomSheetTheme.modalBarrierColor',
        theme.bottomSheetTheme.modalBarrierColor == null
            ? 'NULL -> Colors.black54'
            : _hex(theme.bottomSheetTheme.modalBarrierColor));
    line('dialogTheme.barrierColor', _hex(theme.dialogTheme.barrierColor));

    // The scrim expression 5 sheet launchers use.
    line('onSecondaryContainer @0.87 (production sheet scrim)',
        _hex(theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.87)));

    // Progress / refresh.
    line('progressIndicatorTheme.color', _hex(theme.progressIndicatorTheme.color));
    line('progressIndicatorTheme.refreshBackgroundColor',
        _hex(theme.progressIndicatorTheme.refreshBackgroundColor));

    // Splash-screen contrast pair (BrandedSplash).
    line('splash bg (secondaryContainer)', _hex(theme.colorScheme.secondaryContainer));
    line('splash tagline ink (onSecondary)', _hex(theme.colorScheme.onSecondary));

    // ignore: avoid_print
    print(sb.toString());
  });
}
