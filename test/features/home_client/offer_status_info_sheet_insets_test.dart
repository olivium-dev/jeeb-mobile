// D5 — the More sheet must clear the system nav bar and draw a boundary under
// its pinned header. `showModalBottomSheet` strips MediaQuery.padding, so the
// SafeArea that used to guard the last row silently no-opped on-device.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/home_client/presentation/widgets/offer_status_info_sheet.dart';

import '../../support/sync_app_localizations.dart';

const double _navBarInset = 48;

Widget _host() => MaterialApp(
  theme: AppTheme.light(),
  locale: const Locale('en'),
  supportedLocales: const [Locale('en'), Locale('ar')],
  localizationsDelegates: const [
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: true,
      viewPadding: const EdgeInsets.only(bottom: _navBarInset),
      padding: const EdgeInsets.only(bottom: _navBarInset),
    ),
    child: child!,
  ),
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: ElevatedButton(
          onPressed: () => OfferStatusInfoSheet.show(context),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('the last row clears the system nav inset', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final sheet = find.bySemanticsIdentifier('offer_status_info_sheet');
    expect(sheet, findsOneWidget);

    final lastRow = find.bySemanticsIdentifier(
      'offer_status_filter_superseded',
    );
    await tester.scrollUntilVisible(lastRow, 120);
    await tester.pumpAndSettle();

    final sheetBottom = tester.getRect(sheet).bottom;
    final rowBottom = tester.getRect(lastRow).bottom;
    expect(
      sheetBottom - rowBottom,
      greaterThanOrEqualTo(_navBarInset),
      reason: 'the last status row must not sit under the system nav bar',
    );
  });

  testWidgets('a hairline separates the pinned header from the rows', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('offer-status-header-divider')),
      findsOneWidget,
    );
  });
}
