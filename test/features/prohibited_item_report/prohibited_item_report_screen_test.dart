// redesign-2026-08 · w4 prohibited-item lane.
//
// Pins the re-skin's structure (kit widgets, one docked CTA), the unchanged
// enable rule (description non-empty) and the ARB copy in both locales.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_info_note.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_top_bar.dart';
import 'package:jeeb_mobile/features/prohibited_item_report/presentation/prohibited_item_report_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

late AppLocalizations _en;
late AppLocalizations _ar;

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('ar')],
    home: child,
  );
}

void main() {
  setUpAll(() async {
    const SyncAppLocalizationsDelegate delegate = SyncAppLocalizationsDelegate();
    _en = await delegate.load(const Locale('en'));
    _ar = await delegate.load(const Locale('ar'));
  });

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
    expect(find.text(_en.prohibitedItemReportTitle), findsOneWidget);
    expect(find.text(_en.prohibitedItemReportGuidance), findsOneWidget);

    final JeebCtaButton submit = tester.widget(
      find.widgetWithText(JeebCtaButton, _en.prohibitedItemReportSubmitCta),
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
      find.widgetWithText(JeebCtaButton, _en.prohibitedItemReportSubmitCta),
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
      find.widgetWithText(JeebCtaButton, _en.prohibitedItemReportSubmitCta),
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
    expect(find.text(_ar.prohibitedItemReportTitle), findsOneWidget);
    expect(find.text(_ar.prohibitedItemReportSubmitCta), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('survives 2x text scale without overflowing', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ProhibitedItemReportScreen(requestId: 'REQ-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
