// redesign-2026-08 · w4 prohibited-item lane.
//
// The screen shipped with no test of its own. These pin the re-skin's
// structure (kit widgets, one docked CTA), the unchanged enable rule
// (description non-empty) and the copy now flowing through the feature-local
// [ProhibitedItemReportL10n] stopgap in both locales.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_top_bar.dart';
import 'package:jeeb_mobile/features/prohibited_item_report/presentation/prohibited_item_report_l10n.dart';
import 'package:jeeb_mobile/features/prohibited_item_report/presentation/prohibited_item_report_screen.dart';

const ProhibitedItemReportL10n _en = ProhibitedItemReportL10n(isArabic: false);
const ProhibitedItemReportL10n _ar = ProhibitedItemReportL10n(isArabic: true);

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    supportedLocales: const [Locale('en'), Locale('ar')],
    home: child,
  );
}

void main() {
  testWidgets('renders the kit shell and keeps the CTA disabled when empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const ProhibitedItemReportScreen(requestId: 'REQ-1')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(JeebTopBar), findsOneWidget);
    expect(find.byType(JeebInfoNote), findsOneWidget);
    expect(find.byType(JeebCtaButton), findsNWidgets(2));
    expect(find.text(_en.title), findsOneWidget);
    expect(find.text(_en.guidanceNote), findsOneWidget);

    final JeebCtaButton submit = tester.widget(
      find.widgetWithText(JeebCtaButton, _en.reportCta),
    );
    expect(submit.isEnabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seeded description enables the report CTA', (tester) async {
    await tester.pumpWidget(
      _host(
        const ProhibitedItemReportScreen(
          requestId: 'REQ-1',
          initialDescription: 'liquor',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final JeebCtaButton submit = tester.widget(
      find.widgetWithText(JeebCtaButton, _en.reportCta),
    );
    expect(submit.isEnabled, isTrue);
  });

  testWidgets('typing flips the CTA on', (tester) async {
    await tester.pumpWidget(
      _host(const ProhibitedItemReportScreen(requestId: 'REQ-1')),
    );
    await tester.enterText(find.byType(TextField), 'unsealed bottle');
    await tester.pumpAndSettle();

    final JeebCtaButton submit = tester.widget(
      find.widgetWithText(JeebCtaButton, _en.reportCta),
    );
    expect(submit.isEnabled, isTrue);
  });

  testWidgets('AR locale renders Arabic copy RTL without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ProhibitedItemReportScreen(requestId: 'REQ-1'),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_ar.title), findsOneWidget);
    expect(find.text(_ar.reportCta), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives 2x text scale without overflowing', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ProhibitedItemReportScreen(requestId: 'REQ-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
