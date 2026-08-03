import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/home_client/presentation/tabs/pending_requests_tab.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../preview_test_harness.dart';

const Key _bannerBody = Key('pending-reconnect-banner');

String _reconnectingLabel(WidgetTester tester) => AppLocalizations.of(
      tester.element(find.byType(PendingReconnectBanner).first),
    ).pendingTabReconnecting;

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'PendingReconnectBanner',
    const <String, Widget Function()>{
      'Connected (collapsed)': pendingReconnectBannerHidden,
      'Reconnecting · 390 pt': pendingReconnectBannerReconnecting,
      'Reconnecting · 320 pt': pendingReconnectBannerNarrow,
      'Height cost': pendingReconnectBannerHeightCost,
    },
    expectedText: const <String, String>{
      'Connected (collapsed)': 'Connected · list top',
      'Reconnecting · 390 pt': 'Reconnecting · 390 pt',
      'Reconnecting · 320 pt': 'Reconnecting · 320 pt',
      'Height cost': 'Height cost · reconnecting',
    },
  );

  group('PendingReconnectBanner preview specifics', () {
    testWidgets('connected state takes no space at all', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingReconnectBannerHidden);

      expect(find.byKey(_bannerBody), findsNothing);
      expect(
        tester.getSize(find.byType(PendingReconnectBanner)).height,
        0,
        reason: 'A hidden banner must not reserve height above the list.',
      );
    });

    testWidgets('reconnecting state renders the localized label', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingReconnectBannerReconnecting);

      expect(find.byKey(_bannerBody), findsOneWidget);
      expect(find.text(_reconnectingLabel(tester)), findsOneWidget);
      expect(find.text('Reconnecting…'), findsOneWidget);
    });

    testWidgets('Arabic renders the translation, not the English string', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        pendingReconnectBannerNarrow,
        locale: const Locale('ar'),
      );

      final String label = _reconnectingLabel(tester);
      expect(label, isNot('Reconnecting…'));
      expect(find.text(label), findsOneWidget);
      expect(find.text('Reconnecting…'), findsNothing);
    });

    testWidgets('the row mirrors in RTL — spinner leads the label', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingReconnectBannerReconnecting);
      final double ltrSpinner = tester
          .getCenter(find.byType(CircularProgressIndicator))
          .dx;
      final double ltrLabel =
          tester.getCenter(find.text(_reconnectingLabel(tester))).dx;
      expect(ltrSpinner, lessThan(ltrLabel));

      await pumpPreview(
        tester,
        pendingReconnectBannerReconnecting,
        locale: const Locale('ar'),
      );
      final double rtlSpinner = tester
          .getCenter(find.byType(CircularProgressIndicator))
          .dx;
      final double rtlLabel =
          tester.getCenter(find.text(_reconnectingLabel(tester))).dx;
      expect(
        rtlSpinner,
        greaterThan(rtlLabel),
        reason: 'In Arabic the spinner must sit on the trailing (right) edge.',
      );
    });

    testWidgets('height-cost preview shows both states, one body', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, pendingReconnectBannerHeightCost);

      final Finder banners = find.byType(PendingReconnectBanner);
      expect(banners, findsNWidgets(2));
      expect(find.byKey(_bannerBody), findsOneWidget);
      expect(tester.getSize(banners.at(0)).height, 0);
      expect(tester.getSize(banners.at(1)).height, greaterThan(0));
    });
  });
}
