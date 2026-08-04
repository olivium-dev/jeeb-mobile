/// Widget tests for the Jeeber "Start delivery" entry point inside
/// [OfferAcceptedBanner] (jeeber active-delivery reachability fix).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/offer_accepted_banner.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------

class _SyncLocDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncLocDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncLocDelegate old) => false;
}

late _SyncLocDelegate _delegate;

void _loadArb() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _delegate = _SyncLocDelegate({'en': en, 'ar': ar});
}

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

// The CTA target key + Semantics identifier the host/Maestro rely on.
const _ctaKey = Key('chat-start-active-delivery-cta');

void main() {
  setUpAll(_loadArb);

  group('OfferAcceptedBanner — Start delivery CTA (jeeber entry point)', () {
    testWidgets('jeeber variant renders the CTA with its identifier',
        (tester) async {
      await tester.pumpWidget(
        _host(
          OfferAcceptedBanner(
            jeeberName: 'Kamal Hajj',
            onStartActiveDelivery: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(_ctaKey), findsOneWidget);
      expect(find.text('Start delivery'), findsOneWidget);
      expect(
        find.bySemanticsLabel('chat_start_active_delivery_cta'),
        findsNothing,
        reason: 'identifier is a Semantics.identifier, not a label',
      );
      // The Semantics node carries the Maestro-targetable identifier.
      final semantics = tester.getSemantics(find.byKey(_ctaKey));
      expect(semantics.identifier, 'chat_start_active_delivery_cta');
    });

    testWidgets('client variant (no callback) does NOT render the CTA',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const OfferAcceptedBanner(jeeberName: 'Kamal Hajj'),
        ),
      );
      await tester.pump();

      expect(find.byKey(_ctaKey), findsNothing);
      expect(find.text('Start delivery'), findsNothing);
      // The success strip itself still renders for the client.
      expect(find.byKey(const Key('offer-accepted-banner')), findsOneWidget);
    });

    testWidgets('tapping the CTA fires onStartActiveDelivery once',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          OfferAcceptedBanner(
            jeeberName: 'Kamal Hajj',
            onStartActiveDelivery: () => taps++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(_ctaKey));
      await tester.pump();

      expect(taps, 1);
    });
  });
}
