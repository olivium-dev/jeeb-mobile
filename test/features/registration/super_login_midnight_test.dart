// MIDNIGHT M6 per-element assertions for the two super-login surfaces, which
// the audit classed 3b (zero kit imports — never given a Midnight pass).
//
// These mount under `AppTheme.midnight()` deliberately: the shared
// `wrapForTest` harness themes with `ThemeData.light()`, under which the 3c
// role-badge collision cannot reproduce at all.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_radii.dart';
import 'package:jeeb_mobile/core/theme/jeeb_text_styles.dart';
import 'package:jeeb_mobile/features/registration/data/super_login_demo_user.dart';
import 'package:jeeb_mobile/features/registration/presentation/super_login/super_login_entry_points.dart';
import 'package:jeeb_mobile/features/registration/presentation/super_login/super_login_picker.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _Roster implements SuperLoginDemoUserService {
  _Roster(this.users);
  final List<SuperLoginDemoUser> users;

  @override
  Future<List<SuperLoginDemoUser>> fetchDemoUsers() async => users;
}

const _client = SuperLoginDemoUser(
  userId: 'c-1',
  name: 'Sami',
  role: 'customer',
  availableRoles: <String>['customer'],
);
const _jeeber = SuperLoginDemoUser(
  userId: 'j-1',
  name: 'Kamal',
  role: 'driver',
  availableRoles: <String>['customer', 'driver'],
);

Widget _midnightHost(Widget child) => MaterialApp(
      theme: AppTheme.midnight(),
      darkTheme: AppTheme.midnight(),
      themeMode: ThemeMode.dark,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  group('3c — the role badge no longer renders both roles identically', () {
    Future<void> openPicker(WidgetTester tester) async {
      await tester.pumpWidget(
        _midnightHost(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open'),
                  onPressed: () => showSuperLoginPicker(
                    context,
                    service: _Roster(const <SuperLoginDemoUser>[
                      _client,
                      _jeeber,
                    ]),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    testWidgets('the two badges resolve to different fills AND different inks',
        (tester) async {
      await openPicker(tester);

      final chips = tester
          .widgetList<OmdsChip>(find.byType(OmdsChip))
          .toList(growable: false);
      expect(chips, hasLength(2), reason: 'one badge per demo user');

      final Set<Color?> fills =
          chips.map((c) => c.selectedColor).toSet();
      final Set<Color?> inks =
          chips.map((c) => c.selectedTextColor).toSet();

      // The defect: the ternary branched client→primaryContainer /
      // jeeber→tertiaryContainer, which Midnight maps to the SAME hex.
      expect(fills, hasLength(2),
          reason: 'both role badges painted the same container colour');
      expect(inks, hasLength(2));

      final scheme = AppTheme.midnight().colorScheme;
      expect(fills, containsAll(<Color>[
        scheme.primaryContainer,
        scheme.secondaryContainer,
      ]));
      expect(inks, containsAll(<Color>[
        scheme.onPrimaryContainer,
        scheme.onSecondaryContainer,
      ]));
    });

    testWidgets('the sheet consumes the ratified navy + sheet rung, not its '
        'own topLarge(20) override', (tester) async {
      await openPicker(tester);

      final theme = AppTheme.midnight();
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));

      // The route resolves the fill off `bottomSheetTheme` and leaves the shape
      // for `BottomSheet` to resolve off the same theme — so a null shape here
      // is exactly what "no local override" looks like.
      expect(sheet.backgroundColor, theme.bottomSheetTheme.modalBackgroundColor);
      expect(sheet.shape, isNull);

      final shape = theme.bottomSheetTheme.shape! as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(JeebRadii.sheet)),
      );
      // Discrimination: the shipped override was `OmdsBorderRadius.topLarge`.
      expect(
        shape.borderRadius,
        isNot(const BorderRadius.vertical(top: Radius.circular(Spacing.large))),
      );
    });
  });

  group('3b — the dev entry-point links are not on the orange budget', () {
    testWidgets('both links ink periwinkle and use the Midnight ramp',
        (tester) async {
      await tester.pumpWidget(
        _midnightHost(
          Scaffold(
            body: SuperLoginEntryPoints(
              onSuperLogin: () {},
              onSuperLoginPlus: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final scheme = AppTheme.midnight().colorScheme;
      final ramp = JeebTextStyles.midnight();

      for (final key in const <Key>[
        Key('login.superLogin'),
        Key('login.superLoginPlus'),
      ]) {
        final style = tester
            .widget<Text>(
              find.descendant(of: find.byKey(key), matching: find.byType(Text)),
            )
            .style!;

        expect(style.color, scheme.onSurfaceVariant);
        expect(style.decoration, TextDecoration.underline);
        expect(style.decorationColor, scheme.onSurfaceVariant);
        expect(style.fontSize, ramp.bodySmall.fontSize);

        // Discrimination: the shipped ink was `primary` at 60%, i.e. orange.
        expect(style.color, isNot(scheme.primary));
        expect(style.color,
            isNot(scheme.primary.withValues(alpha: UIConstants.opacityMedium)));
      }
    });
  });
}
