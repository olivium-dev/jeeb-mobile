// OKG-01/OKG-02: the error phase rendered an inert muted strip with no retry,
// and the bare `catch (_)` discarded the kind entirely.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/offer_kyc_gate/application/offer_kyc_gate_cubit.dart';
import 'package:jeeb_mobile/features/offer_kyc_gate/application/offer_kyc_gate_state.dart';
import 'package:jeeb_mobile/features/offer_kyc_gate/presentation/offer_kyc_gate_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _ThrowingGateway extends FakeKycGateway {
  _ThrowingGateway(this.failure);

  final AppFailure failure;
  int reads = 0;

  @override
  Future<KycSubmission> fetchStatus() async {
    reads++;
    throw KycGatewayException(failure);
  }
}

Widget _host(KycGateway gateway, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      theme: AppTheme.midnight(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: OfferKycGateScreen(gateway: gateway),
    );

void main() {
  test('a failed read carries the classified kind', () async {
    final cubit = OfferKycGateCubit(
      gateway: _ThrowingGateway(const ServerFailure(status: 503)),
    );
    addTearDown(cubit.close);
    await cubit.loadStatus();

    expect(cubit.state.phase, OfferKycGatePhase.error);
    expect(cubit.state.failure, isA<ServerFailure>());
  });

  test('a double-tapped retry issues ONE fetch', () async {
    final gateway = _ThrowingGateway(const NetworkFailure());
    final cubit = OfferKycGateCubit(gateway: gateway);
    addTearDown(cubit.close);
    // The constructor already fires one read.
    await Future<void>.delayed(Duration.zero);
    final int base = gateway.reads;

    await Future.wait(<Future<void>>[cubit.loadStatus(), cubit.loadStatus()]);

    expect(gateway.reads - base, 1);
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('${locale.languageCode} · the error strip carries a retry that '
        're-reads', (tester) async {
      useReduceMotion(tester);
      final gateway = _ThrowingGateway(const NetworkFailure());

      await tester.pumpWidget(_host(gateway, locale: locale));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('offer_kyc_gate_error'),
        findsOneWidget,
      );
      final int before = gateway.reads;

      await tester.tap(
        find.bySemanticsIdentifier('offer_kyc_gate_retry_cta'),
      );
      await tester.pumpAndSettle();

      expect(gateway.reads, before + 1);
    });
  }

  testWidgets('a 500 does not print the connectivity line', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      _host(_ThrowingGateway(const ServerFailure(status: 500))),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('offer_kyc_gate_error'), findsOneWidget);
    expect(find.text('Check your connection and try again.'), findsNothing);
  });
}
