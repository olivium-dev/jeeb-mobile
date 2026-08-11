import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_fee_banner.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/confirm_delivery_action_sheet.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/delivery_confirm_illustration.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// Synchronous localizations delegate that loads the real ARB files from disk
/// so the tests exercise the same key→value path the app uses.
class _SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncAppLocalizationsDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

late _SyncAppLocalizationsDelegate _syncDelegate;

void _loadArbFromDisk() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncAppLocalizationsDelegate({'en': en, 'ar': ar});
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

void main() {
  setUpAll(_loadArbFromDisk);

  group('ChatFeeBanner', () {
    testWidgets('renders the localized notice with the formatted amount',
        (tester) async {
      await tester.pumpWidget(_host(const ChatFeeBanner(amount: r'$0.5')));
      await tester.pumpAndSettle();

      expect(find.byKey(ChatFeeBanner.bannerKey), findsOneWidget);
      expect(
        find.text(r'Note $0.5 will be reduced from your Balance'),
        findsOneWidget,
      );
    });

    testWidgets('none trailing renders neither dismiss nor order-picked',
        (tester) async {
      await tester.pumpWidget(_host(const ChatFeeBanner(amount: r'$0.5')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byKey(const Key('chat-fee-banner-order-picked')), findsNothing);
    });

    testWidgets('dismiss trailing fires onDismiss', (tester) async {
      var dismissed = false;
      await tester.pumpWidget(_host(ChatFeeBanner(
        amount: r'$0.5',
        trailing: ChatFeeBannerTrailing.dismiss,
        onDismiss: () => dismissed = true,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      expect(dismissed, isTrue);
    });

    testWidgets('orderPicked trailing renders the action pill and fires its tap',
        (tester) async {
      var picked = false;
      await tester.pumpWidget(_host(ChatFeeBanner(
        amount: r'$0.5',
        trailing: ChatFeeBannerTrailing.orderPicked,
        onOrderPicked: () => picked = true,
      )));
      await tester.pumpAndSettle();

      expect(find.text('Order picked'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-fee-banner-order-picked')));
      expect(picked, isTrue);
    });

    testWidgets('renders the Arabic notice under RTL without overflow',
        (tester) async {
      await tester.pumpWidget(_host(
        const ChatFeeBanner(
          amount: r'$0.5',
          trailing: ChatFeeBannerTrailing.dismiss,
        ),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      final direction = Directionality.of(
        tester.element(find.byKey(ChatFeeBanner.bannerKey)),
      );
      expect(direction, TextDirection.rtl);
      expect(find.textContaining('رصيدك'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ConfirmDeliveryActionSheet', () {
    testWidgets('picking variant renders title, subtitle, illustration and CTA',
        (tester) async {
      await tester.pumpWidget(_host(ConfirmDeliveryActionSheet(
        kind: DeliveryConfirmKind.picking,
        onConfirm: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Picking the order'), findsOneWidget);
      expect(find.text('Help user track the order'), findsOneWidget);
      expect(find.byType(DeliveryConfirmIllustration), findsOneWidget);
      expect(
        find.byKey(const Key('confirm-delivery-confirm-button')),
        findsOneWidget,
      );
    });

    testWidgets('heading-off variant renders its own title', (tester) async {
      await tester.pumpWidget(_host(ConfirmDeliveryActionSheet(
        kind: DeliveryConfirmKind.headingOff,
        onConfirm: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Heading off'), findsOneWidget);
    });

    testWidgets('Confirm CTA fires onConfirm', (tester) async {
      var confirmed = false;
      await tester.pumpWidget(_host(ConfirmDeliveryActionSheet(
        kind: DeliveryConfirmKind.picking,
        onConfirm: () => confirmed = true,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm-delivery-confirm-button')));
      expect(confirmed, isTrue);
    });

    testWidgets(
        'Confirm CTA is an independent tappable semantics node (QA B1 fix)',
        (tester) async {
      final handle = tester.ensureSemantics();
      var confirmed = false;
      await tester.pumpWidget(_host(ConfirmDeliveryActionSheet(
        kind: DeliveryConfirmKind.picking,
        onConfirm: () => confirmed = true,
      )));
      await tester.pumpAndSettle();

      // The CTA must expose its OWN button semantics node carrying the stable
      final ctaFinder = find.bySemanticsIdentifier(
        'confirm_delivery_confirm_button',
      );
      expect(ctaFinder, findsOneWidget);
      expect(
        tester.getSemantics(ctaFinder),
        isSemantics(
          identifier: 'confirm_delivery_confirm_button',
          isButton: true,
          hasTapAction: true,
        ),
      );

      // Driving the SEMANTICS tap action (what Maestro/TalkBack does) fires
      await tester.tap(ctaFinder, warnIfMissed: false);
      expect(confirmed, isTrue);
      handle.dispose();
    });

    testWidgets('sheet exposes its leaf nodes as explicit children (QA B1)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(ConfirmDeliveryActionSheet(
        kind: DeliveryConfirmKind.picking,
        onConfirm: () {},
      )));
      await tester.pumpAndSettle();

      // The drag handle, title, subtitle, and CTA stay independently
      for (final id in const [
        'confirm_delivery_drag_handle',
        'confirm_delivery_title',
        'confirm_delivery_subtitle',
        'confirm_delivery_confirm_button',
      ]) {
        expect(
          find.bySemanticsIdentifier(id),
          findsOneWidget,
          reason: 'expected an independent semantics node for $id',
        );
      }
      handle.dispose();
    });

    testWidgets('renders Arabic copy under RTL', (tester) async {
      await tester.pumpWidget(_host(
        ConfirmDeliveryActionSheet(
          kind: DeliveryConfirmKind.headingOff,
          onConfirm: () {},
        ),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('تأكيد الانطلاق'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
