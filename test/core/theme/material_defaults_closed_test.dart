// The M6 Material sweep: every sub-theme below was UNSET and fell through to a
// Material default that is wrong under Midnight — orange (`primary`), pure
// white, `black54`, or `surfaceContainerLow`, a navy the app never draws.
// Goldens cannot see any of it (5% tolerance, and most of these need a gesture
// to render at all), so each is read off the resolved theme here.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_midnight_palette.dart';

const Set<WidgetState> _selected = <WidgetState>{WidgetState.selected};

void main() {
  final ThemeData theme = AppTheme.midnight();
  final ColorScheme scheme = theme.colorScheme;

  /// The navy Material reaches for when a container slot is unset. Nothing in
  /// this sweep may land on it — the app draws page/surface/high/highest only.
  final Color unthemedNavy = scheme.surfaceContainerLow;

  group('L1 — modal sheets had Material\'s black54 barrier', () {
    test('the sheet scrim is the page navy, and the dialog\'s twin', () {
      expect(theme.bottomSheetTheme.modalBarrierColor, JeebMidnight.scrim);
      expect(theme.bottomSheetTheme.modalBarrierColor, isNot(Colors.black54));
      expect(
        theme.bottomSheetTheme.modalBarrierColor,
        theme.dialogTheme.barrierColor,
        reason: 'one barrier ink for both, or sheets and dialogs disagree',
      );
    });
  });

  group('L2 — the date picker drew ORANGE', () {
    test('today and the selected year resolve periwinkle, not primary', () {
      for (final WidgetStateProperty<Color?>? slot
          in <WidgetStateProperty<Color?>?>[
        theme.datePickerTheme.todayBackgroundColor,
        theme.datePickerTheme.yearBackgroundColor,
      ]) {
        expect(slot, isNotNull, reason: 'unset falls through to primary');
        expect(slot!.resolve(_selected), JeebMidnight.inkMuted);
        expect(slot.resolve(_selected), isNot(scheme.primary));
        expect(slot.resolve(<WidgetState>{}), Colors.transparent);
      }
    });

    test('their ink flips to page navy so the pair clears AA', () {
      expect(
        theme.datePickerTheme.todayForegroundColor?.resolve(_selected),
        JeebMidnight.page,
      );
      expect(
        theme.datePickerTheme.yearForegroundColor?.resolve(_selected),
        JeebMidnight.page,
      );
    });
  });

  group('L3 — a bare Icon inherited pure white', () {
    test('iconTheme is onSurface; primaryIconTheme stays white ON orange', () {
      expect(theme.iconTheme.color, JeebMidnight.ink);
      expect(theme.iconTheme.color, isNot(const Color(0xFFFFFFFF)));
      expect(theme.primaryIconTheme.color, scheme.onPrimary);
    });
  });

  group('L4 — the expanded ExpansionTile chevron was primary', () {
    test('both chevrons are periwinkle ink', () {
      expect(theme.expansionTileTheme.iconColor, JeebMidnight.inkSoft);
      expect(theme.expansionTileTheme.iconColor, isNot(scheme.primary));
      expect(theme.expansionTileTheme.collapsedIconColor, JeebMidnight.inkMuted);
      expect(theme.expansionTileTheme.textColor, JeebMidnight.ink);
    });
  });

  group('L5 — DropdownMenu drew a bare OutlineInputBorder', () {
    test('it takes the app\'s own frosted field, not one of its own', () {
      expect(theme.dropdownMenuTheme.inputDecorationTheme, isNotNull);
      expect(
        theme.dropdownMenuTheme.inputDecorationTheme?.fillColor,
        theme.inputDecorationTheme.fillColor,
      );
      expect(
        theme.dropdownMenuTheme.inputDecorationTheme?.border,
        theme.inputDecorationTheme.border,
      );
    });

    test('and the popup slab the OTHER menu family already uses', () {
      expect(
        theme.dropdownMenuTheme.menuStyle?.backgroundColor?.resolve(
          <WidgetState>{},
        ),
        theme.popupMenuTheme.color,
      );
      expect(
        theme.menuTheme.style?.backgroundColor?.resolve(<WidgetState>{}),
        theme.popupMenuTheme.color,
      );
    });
  });

  group('L6 — the route transition painted the CARD navy', () {
    test('the three colour-bearing builders carry the page navy', () {
      final PageTransitionsBuilder? android =
          theme.pageTransitionsTheme.builders[TargetPlatform.android];
      expect(android, isA<PredictiveBackPageTransitionsBuilder>());
      expect(
        (android! as PredictiveBackPageTransitionsBuilder).fallbackColor,
        JeebMidnight.page,
      );
      for (final TargetPlatform platform in <TargetPlatform>[
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        final PageTransitionsBuilder? builder =
            theme.pageTransitionsTheme.builders[platform];
        expect(builder, isA<ZoomPageTransitionsBuilder>());
        expect(
          (builder! as ZoomPageTransitionsBuilder).backgroundColor,
          JeebMidnight.page,
        );
      }
    });

    test('iOS keeps the Cupertino slide — it paints no slab to re-colour', () {
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
        isNotNull,
      );
      expect(
        theme.pageTransitionsTheme.builders[TargetPlatform.iOS],
        isNot(isA<ZoomPageTransitionsBuilder>()),
      );
    });
  });

  group('L7 — the unthemed-navy cluster', () {
    test('drawer, rail and banner sit on the card navy, not #0A1147', () {
      expect(theme.drawerTheme.backgroundColor, JeebMidnight.surface);
      expect(theme.drawerTheme.backgroundColor, isNot(unthemedNavy));
      expect(theme.navigationDrawerTheme.backgroundColor, JeebMidnight.surface);
      expect(theme.navigationRailTheme.backgroundColor, JeebMidnight.surface);
      expect(theme.bannerTheme.backgroundColor, JeebMidnight.surface);
      expect(theme.bannerTheme.backgroundColor, isNot(unthemedNavy));
    });

    test('the drawer scrim is the one barrier ink', () {
      expect(theme.drawerTheme.scrimColor, JeebMidnight.scrim);
    });
  });

  group('theme ruling 5 — the rest of the deferred list', () {
    test('search sits on the glass field rungs', () {
      expect(
        theme.searchBarTheme.backgroundColor?.resolve(<WidgetState>{}),
        JeebMidnight.glassFill,
      );
      expect(theme.searchViewTheme.backgroundColor, JeebMidnight.surface);
      expect(theme.searchViewTheme.dividerColor, JeebMidnight.divider);
    });

    test('segmented active is a WHITE fill with navy ink (M1 ruling 3)', () {
      final ButtonStyle? style = theme.segmentedButtonTheme.style;
      expect(style?.backgroundColor?.resolve(_selected), scheme.onPrimary);
      expect(style?.foregroundColor?.resolve(_selected), JeebMidnight.surface);
      expect(
        style?.backgroundColor?.resolve(<WidgetState>{}),
        JeebMidnight.glassFill,
      );
      expect(
        style?.backgroundColor?.resolve(_selected),
        isNot(scheme.primary),
        reason: 'orange is not in this control',
      );
    });

    test('the scrollbar thumb is visible on navy', () {
      final Color? rest = theme.scrollbarTheme.thumbColor?.resolve(
        <WidgetState>{},
      );
      expect(rest, JeebMidnight.glassBorderVivid);
      expect(
        theme.scrollbarTheme.thumbColor?.resolve(<WidgetState>{
          WidgetState.dragged,
        }),
        JeebMidnight.inkMuted,
      );
      // Material's default is `outline` @80% — white 11%, effectively invisible.
      expect(rest!.a, greaterThan(scheme.outline.a * 0.8));
    });

    test('the badge stays error-red with navy ink (no orange spend)', () {
      expect(theme.badgeTheme.backgroundColor, scheme.error);
      expect(theme.badgeTheme.textColor, scheme.onError);
      expect(theme.badgeTheme.backgroundColor, isNot(scheme.primary));
    });
  });
}
