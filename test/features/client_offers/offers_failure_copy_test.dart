// F9 — offer-review failure copy is split by phase.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/client_offers/domain/jeeber_vehicle.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offer.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/client_offers_screen.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_accept_sheet.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/scripted_offers_repository.dart';

/// Failure → the FROZEN ARB key its copy must resolve to (CONTRACT §5
/// C-1/C-2/C-3 for the wallet-guard arms, C-7 for the de-leaked accept 409).
const Map<OffersFailure, String> _copyKeyByFailure = {
  OffersFailure.holderUnresolved: 'walletGuardErrorHolderUnresolved',
  OffersFailure.feeUnresolvable: 'walletGuardErrorFeeUnresolvable',
  OffersFailure.exposureUnresolvable: 'walletGuardErrorExposureUnresolvable',
  OffersFailure.offerNotPending: 'offersErrorOfferNotPending',
};

class _SyncEnDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncEnDelegate(this._arb);

  final String _arb;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arb);

  @override
  bool shouldReload(_SyncEnDelegate old) => false;
}

Offer _offer() => Offer(
      id: 'offer-001',
      jeeberId: 'user-jeeber-002',
      jeeberName: 'Kamal Hajj',
      fee: 6.0,
      currency: 'USD',
      etaMinutes: 20,
      vehicle: JeeberVehicle.scooter,
      rating: 4.8,
      ratingCount: 42,
      submittedAt: DateTime(2026, 6, 18, 9, 12),
    );

Widget _sheetHarness(String arb, Widget child) => MaterialApp(
      theme: AppTheme.light(),
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _SyncEnDelegate(arb),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

void main() {
  final arb = File('lib/l10n/app_en.arb').readAsStringSync();
  final l10n = debugLoadAppLocalizationsSync(const Locale('en'), arb);

  test('unknown load failure uses the load copy, never "accepting"', () {
    final copy = offersFailureCopy(
      l10n,
      OffersFailure.unknown,
      phase: OffersErrorPhase.load,
    );
    expect(copy, l10n.offersLoadErrorGeneric);
    expect(copy.toLowerCase(), contains("couldn't load offers"));
    expect(copy.toLowerCase(), isNot(contains('accepting')));
  });

  test('null (unclassified) load failure also uses the load copy', () {
    final copy = offersFailureCopy(
      l10n,
      null,
      phase: OffersErrorPhase.load,
    );
    expect(copy, l10n.offersLoadErrorGeneric);
    expect(copy.toLowerCase(), isNot(contains('accepting')));
  });

  test('unknown accept failure keeps the "accepting" copy', () {
    final copy = offersFailureCopy(
      l10n,
      OffersFailure.unknown,
      phase: OffersErrorPhase.accept,
    );
    expect(copy, l10n.offersErrorGeneric);
    expect(copy.toLowerCase(), contains('accepting'));
  });

  test('classified failures share the same copy across both phases', () {
    for (final failure in const [
      OffersFailure.network,
      OffersFailure.requestNotOpen,
      OffersFailure.offerNotPending,
      OffersFailure.jeeberAtCapacity,
    ]) {
      final load = offersFailureCopy(
        l10n,
        failure,
        phase: OffersErrorPhase.load,
      );
      final accept = offersFailureCopy(
        l10n,
        failure,
        phase: OffersErrorPhase.accept,
      );
      expect(load, accept, reason: '$failure must be phase-agnostic');
    }
  });

  test(
      'wallet-guard accept failures resolve the frozen C-1/C-2/C-3 copy on the '
      'shared mapper, and offerNotPending still resolves C-7', () {
    for (final entry in _copyKeyByFailure.entries) {
      final expected = l10n.byKey(entry.value);
      expect(expected, isNotNull,
          reason: '${entry.value} must exist in app_en.arb');
      for (final phase in OffersErrorPhase.values) {
        expect(
          offersFailureCopy(l10n, entry.key, phase: phase),
          expected,
          reason: '${entry.key} must render ${entry.value} in $phase',
        );
      }
    }
  });

  testWidgets(
      'the accept sheet renders the SAME frozen copy for the wallet-guard '
      'failures and for the de-leaked 409', (tester) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    for (final entry in _copyKeyByFailure.entries) {
      final expected = l10n.byKey(entry.value);
      expect(expected, isNotNull,
          reason: '${entry.value} must exist in app_en.arb');

      await tester.pumpWidget(
        _sheetHarness(
          arb,
          OfferAcceptSheet(
            // Unique key per arm: same-position reuse would keep iteration 1's
            // BlocProvider cubit (and its already-consumed scripted failure).
            key: ValueKey<OffersFailure>(entry.key),
            offer: _offer(),
            requestId: 'req-client-001-offers',
            repository: ScriptedOffersRepository(
              snapshots: const <OffersSnapshot>[],
              acceptFailure: entry.key,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.bySemanticsIdentifier('offer_accept_confirm_cta'));
      await tester.pump(); // submitting
      await tester.pump(); // failed → inline banner

      expect(find.byKey(const Key('offer-accept-error')), findsOneWidget);
      expect(
        find.text(expected!),
        findsOneWidget,
        reason: '${entry.key} must render ${entry.value} in the sheet',
      );
    }
  });
}
