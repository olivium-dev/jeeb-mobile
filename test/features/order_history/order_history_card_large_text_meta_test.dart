// F5 regression lock — device run, B06-fs2.png / C14.png: at the large system
// font scale the meta row ellipsized to `Se… · Ca… · Re-broadcast`, so neither
// the date nor the status survived. The row must wrap, never clip.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/order_history/domain/order_summary.dart';
import 'package:jeeb_mobile/features/order_history/presentation/order_history_card.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

OrderSummary _cancelled() => OrderSummary(
  id: 'defb1f07-efa5-4b8f-bc1a-09d6fcd1140b',
  displayId: 'defb1f07',
  title: 'F8-resolve-probe-parcel',
  createdAt: DateTime.utc(2026, 9, 5, 11, 21),
  pickupAddress: 'Current location',
  dropoffAddress: 'Current location',
  status: OrderRequestStatus.cancelled,
  tier: OrderTier.standard,
  amountMinor: null,
  currency: 'USD',
);

/// Phone width at the device's own 1080/3 logical width, so the meta row gets
/// exactly the space it had on the S24 capture.
Future<void> _pump(
  WidgetTester tester,
  OrderSummary order, {
  double textScale = 2,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: OrderHistoryCard(
              order: order,
              onTap: () {},
              onReorder: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// True when the paragraph lost characters to its line budget — an ellipsis or
/// a hard clip. A soft-wrapped run reports false: nothing was dropped.
bool _isTruncated(WidgetTester tester, Finder finder) =>
    tester.renderObject<RenderParagraph>(finder).didExceedMaxLines;

void main() {
  testWidgets('EN @2.0: the date is not ellipsized to "Se…"', (tester) async {
    await _pump(tester, _cancelled());

    final Finder date = find.text('Sep 5');
    expect(date, findsOneWidget);
    expect(
      _isTruncated(tester, date),
      isFalse,
      reason: 'device B06-fs2.png showed "Se…" — the date must stay readable',
    );
  });

  testWidgets('EN @2.0: the status is not ellipsized to "Ca…"', (tester) async {
    await _pump(tester, _cancelled());

    final Finder status = find.text('Cancelled');
    expect(status, findsOneWidget);
    expect(_isTruncated(tester, status), isFalse);
  });

  testWidgets('EN @2.0: the Re-broadcast spark still renders in full', (
    tester,
  ) async {
    await _pump(tester, _cancelled());

    expect(find.text('Re-broadcast'), findsOneWidget);
    expect(_isTruncated(tester, find.text('Re-broadcast')), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AR @2.0: the Arabic status stays readable too', (tester) async {
    await _pump(tester, _cancelled(), locale: const Locale('ar'));

    final Finder status = find.text('ملغى');
    expect(status, findsOneWidget);
    expect(_isTruncated(tester, status), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('@1.0 the meta row still fits on one line (no regression)', (
    tester,
  ) async {
    await _pump(tester, _cancelled(), textScale: 1);

    final RenderParagraph date = tester.renderObject<RenderParagraph>(
      find.text('Sep 5'),
    );
    final RenderParagraph status = tester.renderObject<RenderParagraph>(
      find.text('Cancelled'),
    );
    expect(
      date.localToGlobal(Offset.zero).dy,
      status.localToGlobal(Offset.zero).dy,
    );
  });
}
