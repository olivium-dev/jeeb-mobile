// F9 — offer-review failure copy is split by phase.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/client_offers_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

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
}
