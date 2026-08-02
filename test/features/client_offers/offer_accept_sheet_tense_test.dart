import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'package:jeeb_mobile/features/client_offers/domain/jeeber_vehicle.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offer.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_accept_sheet.dart';

import '../../support/scripted_offers_repository.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _syncDelegate;
late AppLocalizations _en;
late AppLocalizations _ar;

void _loadArbs() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
  _en = debugLoadAppLocalizationsSync(const Locale('en'), en);
  _ar = debugLoadAppLocalizationsSync(const Locale('ar'), ar);
}

const _jeeberName = 'Kamal Hajj';

Offer _offer() => Offer(
      id: 'offer-001',
      jeeberId: 'user-jeeber-002',
      jeeberName: _jeeberName,
      fee: 6.0,
      currency: 'USD',
      etaMinutes: 20,
      vehicle: JeeberVehicle.scooter,
      rating: 4.8,
      ratingCount: 42,
      submittedAt: DateTime(2026, 6, 18, 9, 12),
    );

ScriptedOffersRepository _repo() => ScriptedOffersRepository(
      snapshots: const <OffersSnapshot>[],
    )..acceptConversationId = 'conv-journey-accepted';

Widget _harness(Widget child, Locale locale) => MaterialApp(
      theme: AppTheme.light(),
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

Future<void> _pumpSheet(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(
    _harness(
      OfferAcceptSheet(
        offer: _offer(),
        requestId: 'req-client-001-offers',
        repository: _repo(),
      ),
      locale,
    ),
  );
  await tester.pump();
}

/// The rendered text of the title node, read through the widget tree rather
/// than recomputed from the ARB, so the assertion is about what the customer
String _titleText(WidgetTester tester) {
  final finder = find.descendant(
    of: find.bySemanticsIdentifier('offer_accept_jeeber_name'),
    matching: find.byType(Text),
  );
  return tester.widget<Text>(finder).data!;
}

void main() {
  setUpAll(_loadArbs);

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  group('the past-tense chat string still exists — it is just not the title', () {
    // Guards the negative controls below from becoming vacuous. If the chat
    test('chatSystemOfferAcceptedNamed is present and still past tense', () {
      expect(_en.byKey('chatSystemOfferAcceptedNamed'), isNotNull);
      expect(_ar.byKey('chatSystemOfferAcceptedNamed'), isNotNull);
      expect(
        _en.chatSystemOfferAcceptedNamed(_jeeberName),
        "$_jeeberName's offer was accepted",
      );
      expect(_ar.chatSystemOfferAcceptedNamed(_jeeberName), contains('تم قبول'));
    });

    test('offerAcceptTitle is translated in both locales, not a stub', () {
      for (final loc in [_en, _ar]) {
        final raw = loc.byKey('offerAcceptTitle');
        expect(raw, isNotNull, reason: 'both ARBs must carry the key');
        expect(raw, contains('{name}'), reason: 'the placeholder must survive');
        expect(raw, isNot('offerAcceptTitle'), reason: 'not a sentinel stub');
        expect(
          loc.offerAcceptTitle(_jeeberName),
          isNot(contains('{name}')),
          reason: 'the placeholder must be substituted at render',
        );
      }
      expect(
        _ar.offerAcceptTitle(_jeeberName),
        isNot(_en.offerAcceptTitle(_jeeberName)),
        reason: 'AR must be a real translation, not the EN string copied over',
      );
    });
  });

  group('OfferAcceptSheet title asks, never reports', () {
    testWidgets('EN — "Accept {name}\'s offer?", not "…was accepted"', (
      tester,
    ) async {
      await _pumpSheet(tester, const Locale('en'));

      expect(
        _titleText(tester),
        "Accept $_jeeberName's offer?",
        reason: 'POSITIVE control — the title is a question about a pending act',
      );
      expect(
        find.textContaining('was accepted'),
        findsNothing,
        reason: 'NEGATIVE control — nothing on this sheet may be past tense',
      );
    });

    testWidgets('AR — the Arabic question renders, not the Arabic past tense', (
      tester,
    ) async {
      await _pumpSheet(tester, const Locale('ar'));

      expect(
        _titleText(tester),
        _ar.offerAcceptTitle(_jeeberName),
        reason: 'POSITIVE control — AR takes the same new key',
      );
      expect(
        _titleText(tester),
        isNot(_ar.chatSystemOfferAcceptedNamed(_jeeberName)),
        reason: 'NEGATIVE control — never the AR chat system message',
      );
      expect(
        find.textContaining('تم قبول عرض'),
        findsNothing,
        reason: 'NEGATIVE control — the AR past tense must be off this sheet',
      );
    });

    testWidgets('the title is still the addressable JM-029 node', (
      tester,
    ) async {
      await _pumpSheet(tester, const Locale('en'));

      expect(
        find.bySemanticsIdentifier('offer_accept_jeeber_name'),
        findsOneWidget,
        reason: 'copy changed; the Maestro-addressable id must not have',
      );
    });
  });
}
