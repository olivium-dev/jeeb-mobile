import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_deep_link.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';
import 'package:jeeb_mobile/core/notifications/presentation/push_banner_host.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

NotificationMessage _msg(String id, {String title = 'Title', String body = 'Body'}) {
  return NotificationMessage(
    id: id,
    category: NotificationCategory.delivery,
    title: title,
    body: body,
    receivedAt: DateTime.utc(2026, 5, 17),
    data: const {'delivery_id': 'd-1'},
  );
}

/// The guard-2 auto-withdraw push (CONTRACT §3). The wire title/body are
/// deliberately NOT the frozen copy, so a pass can only come from l10n.
NotificationMessage _walletWithdrawMsg({String id = 'w-1'}) {
  return NotificationMessage(
    id: id,
    category: NotificationCategory.wallet,
    title: 'WIRE TITLE FROM GATEWAY',
    body: 'WIRE BODY FROM GATEWAY',
    receivedAt: DateTime.utc(2026, 8, 24),
    data: const {
      'type': 'offer_withdrawn_insufficient_balance',
      'offerId': 'o1',
      'requestId': 'r1',
    },
  );
}

const Locale _en = Locale('en');
const Locale _ar = Locale('ar');

/// Same load path as `test/l10n/*`: the ARB file straight through
/// `debugLoadAppLocalizationsSync`, so expectations cannot drift from it.
String _copy(Locale locale, String key) => debugLoadAppLocalizationsSync(
      locale,
      File('lib/l10n/app_${locale.languageCode}.arb').readAsStringSync(),
    ).byKey(key)!;

const String _pushTitleKey = 'walletGuardPushOfferWithdrawnTitle';
const String _pushBodyKey = 'walletGuardPushOfferWithdrawnBody';

void main() {
  late FakePushTransport transport;
  late BadgeCountCubit badge;
  late PushNotificationHandler handler;

  setUp(() {
    transport = FakePushTransport();
    badge = BadgeCountCubit();
    handler = PushNotificationHandler(transport: transport, badgeCount: badge);
  });

  tearDown(() async {
    await handler.close();
    await badge.close();
  });

  Future<void> pumpHost(WidgetTester tester,
      {Duration autoDismiss = const Duration(seconds: 5)}) async {
    await tester.pumpWidget(MaterialApp(
      home: PushBannerHost(
        handler: handler,
        autoDismiss: autoDismiss,
        child: const Scaffold(body: SizedBox.expand()),
      ),
    ));
  }

  // Same host, but inside the app's real localization stack.
  Future<void> pumpLocalizedHost(
    WidgetTester tester, {
    Locale locale = _en,
    void Function(NotificationMessage message)? onBannerTap,
  }) async {
    await tester.pumpWidget(wrapForTest(
      PushBannerHost(
        handler: handler,
        onBannerTap: onBannerTap,
        child: const Scaffold(body: SizedBox.expand()),
      ),
      locale: locale,
    ));
    await tester.pump();
  }

  Future<void> emit(WidgetTester tester, NotificationMessage message) async {
    await tester.runAsync(() async {
      transport.emitForeground(message);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
  }

  testWidgets('renders the banner when a foreground message arrives',
      (tester) async {
    await pumpHost(tester);
    await tester.runAsync(() async {
      transport.emitForeground(
          _msg('a', title: 'New delivery', body: 'Order #42'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(find.text('New delivery'), findsOneWidget);
    expect(find.text('Order #42'), findsOneWidget);
  });

  testWidgets('tap fires onBannerTap with the underlying message',
      (tester) async {
    NotificationMessage? tapped;
    await tester.pumpWidget(MaterialApp(
      home: PushBannerHost(
        handler: handler,
        onBannerTap: (m) => tapped = m,
        child: const Scaffold(body: SizedBox.expand()),
      ),
    ));

    await tester.runAsync(() async {
      transport.emitForeground(
        _msg('a', title: 'Banner Headline', body: 'Banner Body'),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(find.text('Banner Headline'), findsOneWidget);

    await tester.tap(find.text('Banner Headline'));
    await tester.pump();

    expect(tapped?.id, 'a');
    expect(handler.state.banner, isNull,
        reason: 'tapBanner should clear the banner');
  });

  testWidgets('dismiss button clears the banner without routing',
      (tester) async {
    NotificationMessage? tapped;
    await tester.pumpWidget(MaterialApp(
      home: PushBannerHost(
        handler: handler,
        onBannerTap: (m) => tapped = m,
        child: const Scaffold(body: SizedBox.expand()),
      ),
    ));
    await tester.runAsync(() async {
      transport.emitForeground(_msg('a', title: 'Banner Headline'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    expect(find.text('Banner Headline'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(tapped, isNull);
    expect(find.text('Banner Headline'), findsNothing);
  });

  testWidgets('banner auto-dismisses after the configured duration',
      (tester) async {
    await pumpHost(tester, autoDismiss: const Duration(milliseconds: 200));
    await tester.runAsync(() async {
      transport.emitForeground(_msg('a', title: 'Auto Dismiss Banner'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();

    expect(find.text('Auto Dismiss Banner'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    expect(find.text('Auto Dismiss Banner'), findsNothing);
  });

  // W6-T3 — CONTRACT §3: the wire copy is gateway-rendered EN, so the banner
  // renders the app's own P-1/P-2 strings whenever a delegate is in scope.
  group('wallet-guard withdraw push banner', () {
    testWidgets('renders the localized (EN) title and body over the wire '
        'strings, with the wallet glyph, and taps through to /wallet',
        (tester) async {
      NotificationMessage? tapped;
      await pumpLocalizedHost(tester, onBannerTap: (m) => tapped = m);
      await emit(tester, _walletWithdrawMsg());

      expect(find.text(_copy(_en, _pushTitleKey)), findsOneWidget);
      expect(find.text(_copy(_en, _pushBodyKey)), findsOneWidget);
      expect(find.text('WIRE TITLE FROM GATEWAY'), findsNothing);
      expect(find.text('WIRE BODY FROM GATEWAY'), findsNothing);
      expect(find.byIcon(Icons.account_balance_wallet_outlined),
          findsOneWidget);

      await tester.tap(find.byKey(pushBannerCardKey));
      await tester.pump();

      expect(tapped, isNotNull);
      expect(deepLinkForMessage(tapped!), '/wallet');
    });

    testWidgets('without a localizations delegate it falls back to the wire '
        'title and body verbatim (the documented fallback rung)',
        (tester) async {
      await pumpHost(tester);
      await emit(tester, _walletWithdrawMsg());

      expect(find.text('WIRE TITLE FROM GATEWAY'), findsOneWidget);
      expect(find.text('WIRE BODY FROM GATEWAY'), findsOneWidget);
      expect(find.text(_copy(_en, _pushTitleKey)), findsNothing);
    });

    testWidgets('renders the Arabic title under an ar locale (OD-C4-3)',
        (tester) async {
      await pumpLocalizedHost(tester, locale: _ar);
      await emit(tester, _walletWithdrawMsg());

      expect(find.text(_copy(_ar, _pushTitleKey)), findsOneWidget);
      expect(find.text('WIRE TITLE FROM GATEWAY'), findsNothing);
    });
  });
}
