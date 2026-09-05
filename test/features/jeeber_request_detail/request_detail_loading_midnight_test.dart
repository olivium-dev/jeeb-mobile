// MIDNIGHT M4 — inventory row #36: the by-id recovery loader's wait.
//
// The frame was already right (field + top bar); only the mark was an
// `OmdsLoadingState` inking its ring `colorScheme.primary`, which IS #D73B00
// under Midnight. Read the swap back off the widget, not off a golden.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/feed_request.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import 'package:jeeb_mobile/features/jeeber_request_detail/presentation/jeeber_request_detail_loader.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

Widget _harness({Locale locale = const Locale('en')}) => MaterialApp(
  theme: AppTheme.midnight(),
  locale: locale,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const <LocalizationsDelegate<Object?>>[
    SyncAppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: JeeberRequestDetailLoader(
    requestId: 'req-303',
    initial: null,
    // Never resolves — the loading branch is the subject.
    fetch: () => Completer<FeedRequest?>().future,
    reportService: const ProhibitedItemReportService(),
    onDeclined: (_) {},
    onBack: () {},
  ),
);

void main() {
  testWidgets('the wait is the PARCEL skeleton — the recovered subject is an '
      'order, not a quiet street', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final JeebEmptyState block = tester.widget<JeebEmptyState>(
      find.byType(JeebEmptyState),
    );
    final AppLocalizations l10n = AppLocalizations.of(
      tester.element(find.byType(JeebEmptyState)),
    );
    expect(block.status, JeebEmptyStateStatus.loading);
    expect(block.variant, JeebEmptyStateVariant.parcel);
    expect(block.identifier, 'jeeber_request_detail_loading_state');
    expect(block.headline, l10n.jeeberRequestDetailLoadingHeadline);
    // Loading withholds the CTA (kit contract) — nothing to pass here either.
    expect(block.action, isNull);
  });

  testWidgets('no OMDS state widget is left on the loading branch', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (Widget w) =>
            w.runtimeType.toString().startsWith('Omds') &&
            w.runtimeType.toString().contains('State'),
      ),
      findsNothing,
    );
  });

  testWidgets('the frame the loader already had is untouched', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final JeebMidnightField field = tester.widget<JeebMidnightField>(
      find.byType(JeebMidnightField),
    );
    expect(field.variant, JeebFieldVariant.content);
    expect(field.glowPlacement, JeebFieldGlowPlacement.topStart);
    expect(field.animateDecor, isFalse);
    expect(
      find.bySemanticsIdentifier('jeeber-request-detail-loading'),
      findsOneWidget,
    );
  });

  testWidgets('mirrors under Arabic without throwing', (tester) async {
    await tester.pumpWidget(_harness(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(
      Directionality.of(tester.element(find.byType(JeebEmptyState))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
}
