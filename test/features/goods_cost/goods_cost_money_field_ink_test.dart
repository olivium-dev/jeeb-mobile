// M6 orange-budget lane — the goods-cost money field's ink/caret/stroke split.
//
// `JeebMoneyField` is the ratified reference (R17 `tpl 995`): the 2px accent
// stroke is the screen's ONE budgeted orange, the digits stay `onSurface` so
// they read, and the caret stays periwinkle per theme ruling 4. This screen
// borrows that treatment, so it must land the same three values.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/features/goods_cost/data/fake_goods_cost_repository.dart';
import 'package:jeeb_mobile/features/goods_cost/presentation/goods_cost_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

Widget _host() => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: GoodsCostScreen(
        deliveryId: 'DEL-1',
        repository: FakeGoodsCostRepository(currency: 'USD'),
      ),
    );

TextField _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

void main() {
  testWidgets('the amount reads in onSurface ink, never the accent',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(TextField));
    final ColorScheme scheme = Theme.of(context).colorScheme;

    expect(_field(tester).style?.color?.toARGB32(), scheme.onSurface.toARGB32());
    // The discriminator: reverting to `scheme.primary` fails here.
    expect(
      _field(tester).style?.color?.toARGB32(),
      isNot(scheme.primary.toARGB32()),
    );
    expect(_field(tester).style?.fontWeight, FontWeight.w800);
  });

  testWidgets('the caret stays periwinkle (theme ruling 4)', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(TextField));
    final JeebSemanticColors semantics =
        Theme.of(context).extension<JeebSemanticColors>()!;

    expect(
      _field(tester).cursorColor?.toARGB32(),
      semantics.mutedText.toARGB32(),
    );
    expect(
      _field(tester).cursorColor?.toARGB32(),
      isNot(Theme.of(context).colorScheme.primary.toARGB32()),
    );
  });

  testWidgets('the rest-state stroke IS the lit accent — verified legitimate',
      (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(TextField));
    final BoxDecoration box = tester
        .widgetList<DecoratedBox>(
          find.ancestor(
            of: find.byType(TextField),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((DecoratedBox d) => d.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((BoxDecoration d) => d.border != null);

    final BorderSide side = (box.border! as Border).top;
    expect(side.color.toARGB32(), context.jeebRoles.accent.toARGB32());
    expect(side.width, 2);
    // No orange halo: this screen has no tile, and glow lands only where a
    // tile draws it (wave-A `selectedShadow` ruling).
    expect(box.boxShadow, isNull);
  });
}
