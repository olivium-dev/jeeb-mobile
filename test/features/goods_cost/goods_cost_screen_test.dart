import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_section_label.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_top_bar.dart';
import 'package:jeeb_mobile/features/goods_cost/data/fake_goods_cost_repository.dart';
import 'package:jeeb_mobile/features/goods_cost/domain/goods_cost_repository.dart';
import 'package:jeeb_mobile/features/goods_cost/presentation/goods_cost_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Redesign-2026-08 guard for the goods-cost re-skin: the kit widgets it now
/// composes from, the identifiers Maestro/a11y read, and the two layout limits
/// a hand-built money field is most likely to break (RTL and 200% text).
Widget _host({
  GoodsCostRepository? repository,
  TextDirection direction = TextDirection.ltr,
  double textScale = 1,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Directionality(
      textDirection: direction,
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: GoodsCostScreen(
          deliveryId: 'DEL-1',
          repository: repository ?? FakeGoodsCostRepository(currency: 'USD'),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('composes the kit surfaces, not bespoke ones', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.byType(JeebTopBar), findsOneWidget);
    expect(find.byType(JeebSectionLabel), findsOneWidget);
    expect(find.byType(JeebInfoNote), findsOneWidget);
    expect(find.byType(JeebCtaButton), findsOneWidget);
    // R3: the in-body bar replaced the Material chrome bar.
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('exposes the screen identifiers', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('goods_cost_root'), findsOneWidget);
    expect(find.bySemanticsIdentifier('goods_cost_back'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('goods_cost_amount_field'),
      findsOneWidget,
    );
    expect(find.bySemanticsIdentifier('goods_cost_cash_note'), findsOneWidget);
    expect(find.bySemanticsIdentifier('goods_cost_submit_cta'), findsOneWidget);
  });

  testWidgets('section label carries the gateway currency', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.text('GOODS COST (USD)'), findsOneWidget);
  });

  testWidgets('label degrades neutrally when the currency read fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        repository: FakeGoodsCostRepository(
          fetchFailure: GoodsCostFailure.network,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('GOODS COST'), findsOneWidget);
  });

  testWidgets('submit stays disabled until an amount is typed', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    JeebCtaButton cta() => tester.widget<JeebCtaButton>(
      find.byType(JeebCtaButton),
    );
    expect(cta().isInteractive, isFalse);

    await tester.enterText(find.byType(TextField), '12.50');
    await tester.pumpAndSettle();
    expect(cta().isInteractive, isTrue);
  });

  testWidgets('lays out in RTL without overflow', (tester) async {
    await tester.pumpWidget(
      _host(direction: TextDirection.rtl, locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out at 200% text without overflow', (tester) async {
    await tester.pumpWidget(_host(textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
