// F9 — offer-review failure copy is split by phase.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/offers_failure_copy.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

void main() {
  tearDown(NetworkReachabilitySignals.debugReset);
  final arb = File('lib/l10n/app_en.arb').readAsStringSync();
  final l10n = debugLoadAppLocalizationsSync(const Locale('en'), arb);

  for (final language in <String>['en', 'ar']) {
    final copy = debugLoadAppLocalizationsSync(
      Locale(language),
      File('lib/l10n/app_$language.arb').readAsStringSync(),
    );
    for (final online in <bool?>[true, false, null]) {
      test('legacy network copy follows reachability $online · $language', () {
        if (online != null) {
          NetworkReachabilitySignals.instance.debugObserve(online: online);
        }
        for (final phase in OffersErrorPhase.values) {
          expect(
            offersFailureCopy(copy, OffersFailure.network, phase: phase),
            online == false ? copy.errorNetworkBody : copy.errorUnreachableBody,
          );
        }
      });
    }
    test('carried failure wins over current reachability · $language', () {
      NetworkReachabilitySignals.instance.debugObserve(online: false);
      for (final phase in OffersErrorPhase.values) {
        expect(
          offersFailureCopy(
            copy,
            OffersFailure.network,
            phase: phase,
            appFailure: const NetworkFailure(
              reason: NetworkFailureReason.hostLookup,
            ),
          ),
          copy.errorUnreachableBody,
        );
        expect(
          offersFailureCopy(
            copy,
            OffersFailure.network,
            phase: phase,
            appFailure: const TimeoutFailure(
              phase: DioExceptionType.receiveTimeout,
            ),
          ),
          copy.errorTimeoutBody,
        );
      }
      NetworkReachabilitySignals.instance.debugObserve(online: true);
      expect(
        offersFailureCopy(
          copy,
          OffersFailure.network,
          phase: OffersErrorPhase.load,
          appFailure: const NetworkFailure(offline: true),
        ),
        copy.errorNetworkBody,
      );
    });
  }

  test('unknown load failure uses the load copy, never "accepting"', () {
    final copy = offersFailureCopy(
      l10n,
      OffersFailure.unknown,
      phase: OffersErrorPhase.load,
    );
    // COPY-05: the load fallback is the shared generic body, never the
    // "Couldn't load offers. Retry." line printed above a Retry button.
    expect(copy, l10n.errorGenericBody);
    expect(copy.toLowerCase(), isNot(contains('retry')));
    expect(copy.toLowerCase(), isNot(contains('accepting')));
  });

  test('null (unclassified) load failure also uses the load copy', () {
    final copy = offersFailureCopy(l10n, null, phase: OffersErrorPhase.load);
    expect(copy, l10n.errorGenericBody);
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
      OffersFailure.requestExpired,
      OffersFailure.offerNotPending,
      OffersFailure.jeeberAtCapacity,
      OffersFailure.jeeberWalletShort,
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
