// Structural guard for the wave-C restyle: the date-range sheet is on the
// Midnight kit, not the light-theme Material/OMDS shape it shipped with.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_outlined_card.dart';
import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_date_filter_sheet.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:omds/omds.dart';

import '../../support/sync_app_localizations.dart';

Future<void> _openSheet(
  WidgetTester tester, {
  OrderDateRange initial = const OrderDateRange(),
}) async {
  late BuildContext host;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.midnight(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) {
          host = context;
          return const Scaffold(body: SizedBox.expand());
        },
      ),
    ),
  );
  showOrderHistoryDateFilterSheet(context: host, initial: initial);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the sheet paints the kit sheet field, not a bare surface', (
    tester,
  ) async {
    await _openSheet(tester);

    final field = tester.widget<JeebMidnightField>(
      find.byType(JeebMidnightField),
    );
    expect(field.variant, JeebFieldVariant.sheet);
  });

  testWidgets('both date rows are kit glass cards, not OMDS pickers', (
    tester,
  ) async {
    await _openSheet(tester);

    expect(find.byType(OmdsDatePicker), findsNothing);
    expect(find.byType(JeebOutlinedCard), findsNWidgets(2));
  });

  testWidgets('the two CTAs are kit pills — primary Apply, glass Clear', (
    tester,
  ) async {
    await _openSheet(tester);

    expect(find.byType(OmdsPrimaryButton), findsNothing);
    expect(find.byType(OMDSOutlinedButton), findsNothing);
    expect(
      tester
          .widget<JeebCtaButton>(
            find.byKey(const Key('order-history-filter-apply')),
          )
          .variant,
      JeebCtaVariant.primary,
    );
    expect(
      tester
          .widget<JeebCtaButton>(
            find.byKey(const Key('order-history-filter-clear')),
          )
          .variant,
      JeebCtaVariant.outline,
    );
  });

  testWidgets('Apply stays inert until the range actually changes', (
    tester,
  ) async {
    await _openSheet(tester);

    JeebCtaButton apply() => tester.widget<JeebCtaButton>(
      find.byKey(const Key('order-history-filter-apply')),
    );
    expect(apply().isInteractive, isFalse);

    await tester.tap(
      find.bySemanticsIdentifier('order_history_sheet_from_cta'),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(apply().isInteractive, isTrue);
  });
}
