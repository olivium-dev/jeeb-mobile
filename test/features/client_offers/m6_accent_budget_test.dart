/// M6 accent-budget guards for `client_offers/`.
/// Every row reads a colour off the widget — the 5% golden tolerance cannot
/// see an ink swap. Each was proved discriminating by reverting the value.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/features/client_offers/domain/jeeber_vehicle.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offer.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_accept_sheet.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:omds/omds.dart';

const ColorScheme _scheme = AppTheme.midnightScheme;
final JeebSemanticColors _tokens = JeebSemanticColors.midnight();

class _SyncLocDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncLocDelegate(this._arb);

  final Map<String, String> _arb;

  @override
  bool isSupported(Locale locale) => _arb.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arb[locale.languageCode]!);

  @override
  bool shouldReload(_SyncLocDelegate old) => false;
}

late _SyncLocDelegate _delegate;

Widget _host(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: <LocalizationsDelegate<Object?>>[
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.midnight(),
      home: Scaffold(body: child),
    );

final Offer _offer = Offer(
  id: 'offer-1',
  jeeberId: 'j-1',
  jeeberName: 'Kamal Hajj',
  fee: 35,
  currency: 'USD',
  etaMinutes: 30,
  vehicle: JeeberVehicle.motorcycle,
  rating: 4.6,
  ratingCount: 12,
  submittedAt: DateTime(2026, 6, 1, 9, 41),
);

void main() {
  setUpAll(() {
    _delegate = _SyncLocDelegate(<String, String>{
      'en': File('lib/l10n/app_en.arb').readAsStringSync(),
      'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
    });
  });

  testWidgets('the accept sheet spends orange on the ACT, not on the price',
      (WidgetTester tester) async {
    await tester.pumpWidget(_host(
      OfferAcceptSheet(offer: _offer, requestId: 'req-1'),
    ));
    await tester.pump();

    final Text price = tester.widget<Text>(
      find.descendant(
        of: find.bySemanticsIdentifier('offer_accept_price_label'),
        matching: find.byType(Text),
      ),
    );
    // Money is a FACT. The orange belongs to the confirm CTA below it.
    expect(price.style?.color, _scheme.onSurface);
    expect(price.style?.color, isNot(_scheme.primary));

    // The grabber is the only Container tightly sized 24x4 on this sheet.
    final BoxDecoration grabber = tester
        .widgetList<Container>(find.byType(Container))
        .firstWhere(
          (Container c) =>
              c.constraints ==
              const BoxConstraints.tightFor(
                width: Spacing.twoXLarge,
                height: Spacing.twoXSmall,
              ),
        )
        .decoration! as BoxDecoration;
    expect(grabber.color, _tokens.glassBorderVivid);
    expect(grabber.color, isNot(_scheme.primary));
  });
}
