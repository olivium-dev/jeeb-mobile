import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag_redaction.dart';
import 'package:jeeb_mobile/devtool/gateway/dev_gateway_client.dart';
import 'package:jeeb_mobile/devtool/users/fund_jeeber_wallet_page.dart';
import 'package:jeeb_mobile/devtool/users/scenario_users_page.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:omds/omds.dart';

import 'support/sync_app_localizations.dart';

void main() {
  test('staging Maestro flow pins the real wallet funding journey', () {
    final flow = File(
      '.maestro/flows/devtool-wallet-funding-staging.yaml',
    ).readAsStringSync();

    for (final contract in <String>[
      'Scenario Users',
      'devtool.scenarioUsers.scenario',
      'devtool.scenarioUsers.create',
      'devtool.walletFunding.lastCreated',
      'devtool.walletFunding.submit',
      'Verified receipt',
      'timeout: 120000',
      'takeScreenshot: devtool_wallet_funding_verified_receipt',
    ]) {
      expect(flow, contains(contract));
    }
    expect(flow, isNot(contains('clearState')));
    expect(flow, isNot(contains('point:')));
  });

  test(
    'wallet funding client sends request-scoped bearers and exact money contracts',
    () async {
      final dio = _WalletFundingDio();
      final client = DevGatewayClient(dio: dio);

      await client.ensureJeeberWallet(_WalletFundingDio.jeeberId);
      await client.provisionPartnerCredential(
        identifier: 'partner-login',
        holderId: _WalletFundingDio.partnerId,
        displayName: 'Demo Partner',
        password: 'runtime-only',
      );
      final partner = await client.loginPartner(
        identifier: 'partner-login',
        password: 'runtime-only',
      );
      await client.creditPartner(
        partnerId: partner.partnerId,
        amount: 60,
        adminToken: 'admin-token',
        idempotencyKey: 'test',
      );
      final preview = await client.predictPartnerTopup(
        jeeberId: _WalletFundingDio.jeeberId,
        amount: 60,
        partnerToken: partner.accessToken,
      );
      final otp = await client.requestPartnerTopupOtp(
        jeeberId: _WalletFundingDio.jeeberId,
        amount: 60,
        partnerToken: partner.accessToken,
      );
      await client.executePartnerTopup(
        jeeberId: _WalletFundingDio.jeeberId,
        amount: 60,
        partnerToken: partner.accessToken,
        idempotencyKey: 'test2',
        otp: otp,
      );
      await client.removePartnerCredential(
        'partner-login',
        holderId: _WalletFundingDio.partnerId,
      );

      expect(preview.netToJeeber, 57);
      expect(preview.otpRequired, isTrue);
      expect(
        dio.single(
          'PUT',
          '/dev/wallets/jeeber/${_WalletFundingDio.jeeberId}/ensure',
        ),
        isNotNull,
      );
      expect(
        dio.single('POST', '/dev/partner/credentials').data,
        containsPair('holderId', _WalletFundingDio.partnerId),
      );
      expect(
        dio
            .single(
              'POST',
              '/v1/admin/partners/${_WalletFundingDio.partnerId}/wallet/credits',
            )
            .authorization,
        'Bearer admin-token',
      );
      expect(
        dio
            .single('POST', '/v1/partner/wallet/transfers/predict')
            .authorization,
        'Bearer partner-token',
      );
      final transfer = dio.single('POST', '/v1/partner/wallet/transfers');
      expect(transfer.authorization, 'Bearer partner-token');
      expect(transfer.data, containsPair('idempotencyKey', 'test2'));
      expect(transfer.data, containsPair('otpChallengeId', 'otp-challenge'));
      expect(transfer.data, containsPair('otpCode', '123456'));
      expect(
        dio.single('DELETE', '/dev/partner/credentials/partner-login'),
        isNotNull,
      );
    },
  );

  testWidgets(
    'Dev Tool funds a Jeeber and proves both retries do not duplicate',
    (tester) async {
      final dio = _WalletFundingDio();
      final client = DevGatewayClient(dio: dio);
      const jeeber = DevUser(
        id: _WalletFundingDio.jeeberId,
        username: 'demo_jeeber',
        status: 'active',
        role: 'jeeber',
        roles: <String>['driver'],
      );

      await tester.pumpWidget(
        _testApp(FundJeeberWalletPage(jeeber: jeeber, client: client)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Add money'), findsOneWidget);
      await tester.tap(find.text('Add money'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Verified receipt'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Verified receipt'), findsOneWidget);
      expect(find.textContaining('Before: 0.00'), findsOneWidget);
      expect(find.textContaining('USD'), findsAtLeastNWidgets(2));
      expect(find.textContaining('After: 47.50'), findsOneWidget);
      expect(
        find.text('✓ Cash credit replay did not duplicate'),
        findsOneWidget,
      );
      expect(find.text('✓ Top-up replay did not duplicate'), findsOneWidget);

      expect(
        dio.matching(
          'POST',
          '/v1/admin/partners/${_WalletFundingDio.partnerId}/wallet/credits',
        ),
        hasLength(2),
      );
      expect(
        dio.matching('POST', '/v1/partner/wallet/transfers'),
        hasLength(2),
      );
      expect(
        dio
            .matching('POST', '/v1/partner/wallet/transfers')
            .map((call) => call.data['idempotencyKey'])
            .toSet(),
        hasLength(1),
      );
      expect(
        dio.matching('DELETE', RegExp(r'^/dev/partner/credentials/')),
        hasLength(1),
      );
    },
  );

  test('OTP ProblemDetails keeps the correct recovery message', () async {
    final client = DevGatewayClient(dio: _WalletFundingDio(otpFailure: true));

    await expectLater(
      client.executePartnerTopup(
        jeeberId: _WalletFundingDio.jeeberId,
        amount: 60,
        partnerToken: 'partner-token',
        idempotencyKey: 'test',
        otp: const DevPartnerOtp(challengeId: 'challenge', code: '000000'),
      ),
      throwsA(
        isA<DevGatewayException>()
            .having(
              (error) => error.problemType,
              'problemType',
              'https://jeeb.dev/errors/otp-consumed',
            )
            .having(
              (error) => error.message,
              'message',
              contains('already been used'),
            ),
      ),
    );
  });

  test('diagnostics redact the staging OTP devCode', () {
    final scrubbed = DiagRedaction.scrubMap(<String, Object?>{
      'challengeId': 'challenge',
      'devCode': '123456',
    });

    expect(scrubbed['challengeId'], 'challenge');
    expect(scrubbed['devCode'], isNot('123456'));
  });

  testWidgets('Arabic amount above 50 completes OTP and replay verification', (
    tester,
  ) async {
    final dio = _WalletFundingDio();
    final client = DevGatewayClient(dio: dio);
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(
        FundJeeberWalletPage(jeeber: jeeber, client: client),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '٦٠٫٠٠');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '60.00',
    );
    await tester.tap(find.text('إضافة المال'));
    await tester.pumpAndSettle();

    expect(find.text('توقفت العملية'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('إيصال تم التحقق منه'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('إيصال تم التحقق منه'), findsOneWidget);
    expect(find.textContaining('بعد:'), findsOneWidget);
    expect(
      tester
          .widget<Directionality>(find.byType(Directionality).first)
          .textDirection,
      TextDirection.rtl,
    );
    expect(
      dio.matching('POST', '/v1/partner/wallet/transfers/otp/challenge'),
      hasLength(2),
    );
    expect(dio.matching('POST', '/v1/partner/wallet/transfers'), hasLength(2));
  });

  testWidgets('Dev Tool follows the gateway preview OTP policy', (
    tester,
  ) async {
    final dio = _WalletFundingDio(otpThreshold: 10);
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(
        FundJeeberWalletPage(
          jeeber: jeeber,
          client: DevGatewayClient(dio: dio),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();

    expect(find.text('Verified receipt'), findsOneWidget);
    expect(
      dio.matching('POST', '/v1/partner/wallet/transfers/otp/challenge'),
      hasLength(2),
    );
  });

  testWidgets('missing preview OTP policy stops before any money mutation', (
    tester,
  ) async {
    final dio = _WalletFundingDio(omitOtpPolicy: true);
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(
        FundJeeberWalletPage(
          jeeber: jeeber,
          client: DevGatewayClient(dio: dio),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();

    expect(find.text('Stopped'), findsWidgets);
    expect(dio.creditCalls, isEmpty);
    expect(dio.matching('POST', '/v1/partner/wallet/transfers'), isEmpty);
    expect(
      dio.matching('DELETE', RegExp(r'^/dev/partner/credentials/')),
      hasLength(1),
    );
  });

  testWidgets('missing Jeeber currency stops before any money mutation', (
    tester,
  ) async {
    final dio = _WalletFundingDio(omitJeeberCurrency: true);
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(
        FundJeeberWalletPage(
          jeeber: jeeber,
          client: DevGatewayClient(dio: dio),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();

    expect(find.text('Verified receipt'), findsNothing);
    expect(dio.creditCalls, isEmpty);
    expect(dio.matching('POST', '/v1/partner/wallet/transfers'), isEmpty);
    expect(
      dio.matching('POST', '/v1/partner/wallet/transfers/predict'),
      isEmpty,
    );
    expect(
      dio.matching('DELETE', RegExp(r'^/dev/partner/credentials/')),
      hasLength(1),
    );

    dio.omitJeeberCurrency = false;
    await tester.ensureVisible(find.text('Add money'));
    await tester.pumpAndSettle();
    final submit = tester.widget<OmdsLoadingButton>(
      find.byType(OmdsLoadingButton).first,
    );
    expect(submit.isEnabled, isTrue);
    submit.onTap();
    await tester.pumpAndSettle();

    expect(dio.matching('GET', '/v1/jeeb/wallet'), hasLength(4));
    expect(dio.matching('GET', '/v1/partner/wallet'), isNotEmpty);
    expect(dio.creditCalls, hasLength(2));
    expect(dio.matching('POST', '/v1/partner/wallet/transfers'), hasLength(2));
  });

  testWidgets('missing partner currency stops before any money mutation', (
    tester,
  ) async {
    final dio = _WalletFundingDio(omitPartnerCurrency: true);
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(
        FundJeeberWalletPage(
          jeeber: jeeber,
          client: DevGatewayClient(dio: dio),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();

    expect(find.text('Verified receipt'), findsNothing);
    expect(dio.creditCalls, isEmpty);
    expect(dio.matching('POST', '/v1/partner/wallet/transfers'), isEmpty);
    expect(
      dio.matching('POST', '/v1/partner/wallet/transfers/predict'),
      isEmpty,
    );
  });

  testWidgets('wrong wallet delta never produces a verified receipt', (
    tester,
  ) async {
    final dio = _WalletFundingDio(jeeberDeltaOffset: 1);
    final client = DevGatewayClient(dio: dio);
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(FundJeeberWalletPage(jeeber: jeeber, client: client)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();

    expect(find.text('Verified receipt'), findsNothing);
    expect(find.text('Reconciliation required'), findsWidgets);
    expect(
      find.textContaining('The wallet response did not match'),
      findsOneWidget,
    );
    expect(
      dio.matching('DELETE', RegExp(r'^/dev/partner/credentials/')),
      hasLength(1),
    );
    expect(
      tester
          .widget<OmdsLoadingButton>(find.byType(OmdsLoadingButton).first)
          .isEnabled,
      isFalse,
    );
  });

  testWidgets('fee mismatch never produces a verified receipt', (tester) async {
    final dio = _WalletFundingDio(transferFeeOffset: 1);
    final client = DevGatewayClient(dio: dio);
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(FundJeeberWalletPage(jeeber: jeeber, client: client)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();

    expect(find.text('Verified receipt'), findsNothing);
    expect(find.text('Reconciliation required'), findsWidgets);
    expect(
      find.textContaining('The wallet response did not match'),
      findsOneWidget,
    );
    expect(
      dio.matching('DELETE', RegExp(r'^/dev/partner/credentials/')),
      hasLength(1),
    );
  });

  testWidgets(
    'uncertain money response requires reconciliation and blocks retry',
    (tester) async {
      final client = DevGatewayClient(
        dio: _WalletFundingDio(uncertainTopup: true),
      );
      const jeeber = DevUser(
        id: _WalletFundingDio.jeeberId,
        username: 'demo_jeeber',
        status: 'active',
        role: 'jeeber',
      );

      await tester.pumpWidget(
        _testApp(FundJeeberWalletPage(jeeber: jeeber, client: client)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add money'));
      await tester.pumpAndSettle();

      expect(find.text('Reconciliation required'), findsWidgets);
      expect(find.textContaining('may already be committed'), findsOneWidget);
      expect(find.text('Verified receipt'), findsNothing);
    },
  );

  testWidgets('in-flight money response also blocks retry', (tester) async {
    final dio = _WalletFundingDio(inFlightTopup: true);
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(
        FundJeeberWalletPage(
          jeeber: jeeber,
          client: DevGatewayClient(dio: dio),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();

    expect(find.text('Reconciliation required'), findsWidgets);
    expect(
      tester
          .widget<OmdsLoadingButton>(find.byType(OmdsLoadingButton).first)
          .isEnabled,
      isFalse,
    );
  });

  testWidgets('transport ambiguity on a money POST blocks retry', (
    tester,
  ) async {
    final dio = _WalletFundingDio(transportAmbiguousTopup: true);
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(
        FundJeeberWalletPage(
          jeeber: jeeber,
          client: DevGatewayClient(dio: dio),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();

    expect(find.text('Reconciliation required'), findsWidgets);
    expect(find.textContaining('may already be committed'), findsOneWidget);
  });

  testWidgets(
    'a failed post-commit read requires reconciliation and disables retry',
    (tester) async {
      final dio = _WalletFundingDio(failPostTopupReadOnce: true);
      const jeeber = DevUser(
        id: _WalletFundingDio.jeeberId,
        username: 'demo_jeeber',
        status: 'active',
        role: 'jeeber',
      );

      await tester.pumpWidget(
        _testApp(
          FundJeeberWalletPage(
            jeeber: jeeber,
            client: DevGatewayClient(dio: dio),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add money'));
      await tester.pumpAndSettle();
      expect(find.text('Reconciliation required'), findsWidgets);
      expect(find.text('Verified receipt'), findsNothing);
      expect(
        tester
            .widget<OmdsLoadingButton>(find.byType(OmdsLoadingButton).first)
            .isEnabled,
        isFalse,
      );
      expect(
        dio.matching('DELETE', RegExp(r'^/dev/partner/credentials/')),
        hasLength(1),
      );
    },
  );

  testWidgets('cleanup failure withholds receipt until retry succeeds', (
    tester,
  ) async {
    final dio = _WalletFundingDio(cleanupFailures: 3);
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(
        FundJeeberWalletPage(
          jeeber: jeeber,
          client: DevGatewayClient(dio: dio),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();

    expect(find.text('Session cleanup required'), findsOneWidget);
    expect(find.text('Verified receipt'), findsNothing);
    expect(
      tester.widget<PopScope<dynamic>>(find.byType(PopScope)).canPop,
      isFalse,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry cleanup'));
    await tester.pumpAndSettle();

    expect(find.text('Session cleanup required'), findsNothing);
    expect(find.text('Verified receipt'), findsOneWidget);
    expect(
      dio.matching('DELETE', RegExp(r'^/dev/partner/credentials/')),
      hasLength(4),
    );
  });

  testWidgets('receipt stays hidden while credential cleanup is pending', (
    tester,
  ) async {
    final cleanupGate = Completer<void>();
    final dio = _WalletFundingDio(cleanupGate: cleanupGate);
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(
        FundJeeberWalletPage(
          jeeber: jeeber,
          client: DevGatewayClient(dio: dio),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pump();
    await tester.pump();

    expect(
      dio.matching('DELETE', RegExp(r'^/dev/partner/credentials/')),
      hasLength(1),
    );
    expect(find.text('Verified receipt'), findsNothing);
    cleanupGate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Verified receipt'), findsOneWidget);
  });

  testWidgets('a safe pre-money failure revokes the credential before exit', (
    tester,
  ) async {
    final dio = _WalletFundingDio(failPartnerWalletRead: true);
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(
        FundJeeberWalletPage(
          jeeber: jeeber,
          client: DevGatewayClient(dio: dio),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();

    expect(find.text('Stopped'), findsWidgets);
    expect(
      dio.matching('DELETE', RegExp(r'^/dev/partner/credentials/')),
      hasLength(1),
    );
    expect(
      tester.widget<PopScope<dynamic>>(find.byType(PopScope)).canPop,
      isTrue,
    );

    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Verified receipt'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Verified receipt'), findsOneWidget);
    final seededPartners = dio
        .matching('POST', '/dev/seed/user')
        .where((call) => call.data['role'] == 'partner')
        .toList(growable: false);
    expect(seededPartners, hasLength(2));
    final credentials = dio.matching('POST', '/dev/partner/credentials');
    expect(credentials, hasLength(2));
    expect(credentials.map((call) => call.data['holderId']).toSet(), <Object?>{
      _WalletFundingDio.partnerId,
      _WalletFundingDio.retryPartnerId,
    });
  });

  testWidgets('lost credential activation response still triggers cleanup', (
    tester,
  ) async {
    final dio = _WalletFundingDio(credentialResponseLost: true);
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(
        FundJeeberWalletPage(
          jeeber: jeeber,
          client: DevGatewayClient(dio: dio),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();

    expect(find.text('Stopped'), findsWidgets);
    expect(find.text('Verified receipt'), findsNothing);
    expect(
      dio.matching('DELETE', RegExp(r'^/dev/partner/credentials/')),
      hasLength(1),
    );
    expect(
      tester.widget<PopScope<dynamic>>(find.byType(PopScope)).canPop,
      isTrue,
    );
  });

  testWidgets(
    'credential failure before activation treats cleanup 404 as already absent',
    (tester) async {
      final dio = _WalletFundingDio(
        credentialFailureBeforeCreate: true,
        cleanupNotFound: true,
      );
      const jeeber = DevUser(
        id: _WalletFundingDio.jeeberId,
        username: 'demo_jeeber',
        status: 'active',
        role: 'jeeber',
      );

      await tester.pumpWidget(
        _testApp(
          FundJeeberWalletPage(
            jeeber: jeeber,
            client: DevGatewayClient(dio: dio),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add money'));
      await tester.pumpAndSettle();

      expect(find.text('Session cleanup required'), findsNothing);
      expect(
        dio.matching('DELETE', RegExp(r'^/dev/partner/credentials/')),
        hasLength(1),
      );
      expect(
        tester.widget<PopScope<dynamic>>(find.byType(PopScope)).canPop,
        isTrue,
      );
    },
  );

  testWidgets('currency drift cannot produce a verified receipt', (
    tester,
  ) async {
    final dio = _WalletFundingDio(jeeberCurrencyAfter: 'EUR');
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(
        FundJeeberWalletPage(
          jeeber: jeeber,
          client: DevGatewayClient(dio: dio),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();

    expect(find.text('Verified receipt'), findsNothing);
    expect(find.text('Reconciliation required'), findsWidgets);
  });

  testWidgets('sub-cent balance drift cannot produce a receipt', (
    tester,
  ) async {
    final dio = _WalletFundingDio(jeeberDeltaOffset: 0.001);
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(
        FundJeeberWalletPage(
          jeeber: jeeber,
          client: DevGatewayClient(dio: dio),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();

    expect(find.text('Verified receipt'), findsNothing);
    expect(find.text('Reconciliation required'), findsWidgets);
  });

  testWidgets('altered replay amount and status cannot produce a receipt', (
    tester,
  ) async {
    final dio = _WalletFundingDio(
      topupReplayAmountOffset: 0.01,
      topupReplayStatus: 'rejected',
    );
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(
        FundJeeberWalletPage(
          jeeber: jeeber,
          client: DevGatewayClient(dio: dio),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pumpAndSettle();

    expect(find.text('Verified receipt'), findsNothing);
    expect(find.text('Reconciliation required'), findsWidgets);
  });

  testWidgets('active funding blocks pop and forced unmount still cleans up', (
    tester,
  ) async {
    final creditGate = Completer<void>();
    final dio = _WalletFundingDio(creditGate: creditGate);
    const jeeber = DevUser(
      id: _WalletFundingDio.jeeberId,
      username: 'demo_jeeber',
      status: 'active',
      role: 'jeeber',
    );

    await tester.pumpWidget(
      _testApp(
        FundJeeberWalletPage(
          jeeber: jeeber,
          client: DevGatewayClient(dio: dio),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add money'));
    await tester.pump();

    expect(
      tester.widget<PopScope<dynamic>>(find.byType(PopScope)).canPop,
      false,
    );

    await tester.pumpWidget(_testApp(const SizedBox.shrink()));
    creditGate.complete();
    await tester.pumpAndSettle();

    expect(
      dio.matching('DELETE', RegExp(r'^/dev/partner/credentials/')),
      hasLength(1),
    );
  });

  testWidgets('Scenario Users roster uses the OMDS loading state', (
    tester,
  ) async {
    final rosterGate = Completer<void>();
    final client = DevGatewayClient(
      dio: _WalletFundingDio(rosterGate: rosterGate),
    );

    await tester.pumpWidget(_testApp(ScenarioUsersPage(client: client)));
    await tester.pump();

    expect(find.byType(OmdsLoadingState), findsOneWidget);
    rosterGate.complete();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Scenario Users creates a Jeeber and opens its real Add money flow',
    (tester) async {
      final dio = _WalletFundingDio();
      final client = DevGatewayClient(dio: dio);

      await tester.pumpWidget(_testApp(ScenarioUsersPage(client: client)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Regular customer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jeeber').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create user').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add money'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add money'));
      await tester.pumpAndSettle();

      expect(find.text('Fund Jeeber wallet'), findsOneWidget);
      expect(
        find.textContaining(_WalletFundingDio.jeeberId),
        findsAtLeastNWidgets(1),
      );
    },
  );

  testWidgets('Scenario Users localizes the Arabic Add money entry', (
    tester,
  ) async {
    final client = DevGatewayClient(dio: _WalletFundingDio());

    await tester.pumpWidget(
      _testApp(ScenarioUsersPage(client: client), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('عميل عادي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('موصّل').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('إنشاء مستخدم').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('إضافة المال'));

    expect(find.text('إضافة المال'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('إضافة المال'))),
      TextDirection.rtl,
    );
  });

  testWidgets('Scenario Users localizes Arabic roster metadata with bidi ID', (
    tester,
  ) async {
    final client = DevGatewayClient(
      dio: _WalletFundingDio(includeRosterJeeber: true),
    );

    await tester.pumpWidget(
      _testApp(ScenarioUsersPage(client: client), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('المعرّف: \u2068${_WalletFundingDio.jeeberId}\u2069'),
      findsOneWidget,
    );
    expect(find.textContaining('الدور: موصّل'), findsOneWidget);
    expect(find.textContaining('الحالة: نشط'), findsOneWidget);
    expect(find.textContaining('id:'), findsNothing);
    expect(find.textContaining('role:'), findsNothing);
    expect(find.textContaining('status:'), findsNothing);
  });
}

Widget _testApp(Widget home, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

class _WalletFundingDio extends Fake implements Dio {
  _WalletFundingDio({
    this.jeeberDeltaOffset = 0,
    this.uncertainTopup = false,
    this.inFlightTopup = false,
    this.transportAmbiguousTopup = false,
    this.failPostTopupReadOnce = false,
    this.cleanupFailures = 0,
    this.otpFailure = false,
    this.transferFeeOffset = 0,
    this.creditGate,
    this.cleanupGate,
    this.failPartnerWalletRead = false,
    this.topupReplayAmountOffset = 0,
    this.topupReplayStatus,
    this.credentialResponseLost = false,
    this.credentialFailureBeforeCreate = false,
    this.cleanupNotFound = false,
    this.jeeberCurrencyAfter,
    this.includeRosterJeeber = false,
    this.rosterGate,
    this.otpThreshold = 50,
    this.omitOtpPolicy = false,
    this.omitJeeberCurrency = false,
    this.omitPartnerCurrency = false,
  });

  static const partnerId = '11111111-1111-1111-1111-111111111111';
  static const retryPartnerId = '44444444-4444-4444-4444-444444444444';
  static const adminId = '22222222-2222-2222-2222-222222222222';
  static const jeeberId = '33333333-3333-3333-3333-333333333333';

  final List<_Call> calls = <_Call>[];
  final double jeeberDeltaOffset;
  final bool uncertainTopup;
  final bool inFlightTopup;
  final bool transportAmbiguousTopup;
  final bool failPostTopupReadOnce;
  int cleanupFailures;
  final bool otpFailure;
  final double transferFeeOffset;
  final Completer<void>? creditGate;
  final Completer<void>? cleanupGate;
  final bool failPartnerWalletRead;
  final double topupReplayAmountOffset;
  final String? topupReplayStatus;
  final bool credentialResponseLost;
  final bool credentialFailureBeforeCreate;
  final bool cleanupNotFound;
  final String? jeeberCurrencyAfter;
  final bool includeRosterJeeber;
  final Completer<void>? rosterGate;
  final double otpThreshold;
  final bool omitOtpPolicy;
  bool omitJeeberCurrency;
  bool omitPartnerCurrency;
  double _fundAmount = 50;
  var _uncertainRaised = false;
  var _postTopupReadFailureRaised = false;
  var _creditCommitted = false;
  var _topupCommitted = false;
  var _partnerWalletReadFailureRaised = false;
  var _topupPosts = 0;
  var _partnerSeedCount = 0;
  var _activePartnerId = partnerId;

  List<_Call> matching(String method, Pattern path) => calls
      .where(
        (call) =>
            call.method == method &&
            (path is String
                ? call.path == path
                : path.matchAsPrefix(call.path) != null),
      )
      .toList(growable: false);

  List<_Call> get creditCalls => calls
      .where(
        (call) =>
            call.method == 'POST' && call.path.endsWith('/wallet/credits'),
      )
      .toList(growable: false);

  _Call single(String method, Pattern path) => matching(method, path).single;

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    calls.add(_Call('POST', path, _map(data), _authorization(options)));
    if (path == '/dev/partner/credentials' && credentialFailureBeforeCreate) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<Object?>(
          requestOptions: RequestOptions(path: path),
          statusCode: 503,
        ),
        type: DioExceptionType.badResponse,
      );
    }
    if (path == '/dev/partner/credentials' && credentialResponseLost) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.connectionError,
        error: StateError('connection lost after credential activation'),
      );
    }
    if (path == '/v1/partner/wallet/transfers' && otpFailure) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<Object?>(
          requestOptions: RequestOptions(path: path),
          statusCode: 403,
          data: <String, dynamic>{
            'type': 'https://jeeb.dev/errors/otp-consumed',
            'title':
                'This step-up code has already been used; request a new one.',
          },
        ),
        type: DioExceptionType.badResponse,
      );
    }
    if (path == '/v1/partner/wallet/transfers' &&
        uncertainTopup &&
        !_uncertainRaised) {
      _uncertainRaised = true;
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<Object?>(
          requestOptions: RequestOptions(path: path),
          statusCode: 502,
          data: <String, dynamic>{
            'type': 'https://jeeb.dev/errors/partner-wallet-uncertain',
            'title': 'Wallet result uncertain',
          },
        ),
        type: DioExceptionType.badResponse,
      );
    }
    if (path == '/v1/partner/wallet/transfers' && inFlightTopup) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<Object?>(
          requestOptions: RequestOptions(path: path),
          statusCode: 409,
          data: <String, dynamic>{
            'type': 'https://jeeb.dev/errors/partner-wallet-in-flight',
            'title': 'Wallet operation in flight',
          },
        ),
        type: DioExceptionType.badResponse,
      );
    }
    if (path == '/v1/partner/wallet/transfers' && transportAmbiguousTopup) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        type: DioExceptionType.connectionError,
        error: StateError('connection lost after request send'),
      );
    }
    if (path.endsWith('/wallet/credits') && creditGate != null) {
      await creditGate!.future;
    }
    final body = _postBody(path, _map(data));
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: path == '/dev/partner/credentials' ? 204 : 200,
      data: body as T?,
    );
  }

  @override
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    calls.add(_Call('PUT', path, _map(data), _authorization(options)));
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 204,
    );
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    calls.add(
      _Call('DELETE', path, <String, dynamic>{
        ..._map(data),
        ...?queryParameters,
      }, _authorization(options)),
    );
    if (cleanupGate != null) await cleanupGate!.future;
    if (cleanupNotFound) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<Object?>(
          requestOptions: RequestOptions(path: path),
          statusCode: 404,
        ),
        type: DioExceptionType.badResponse,
      );
    }
    if (cleanupFailures > 0) {
      cleanupFailures--;
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<Object?>(
          requestOptions: RequestOptions(path: path),
          statusCode: 502,
          data: <String, dynamic>{
            'type': 'https://jeeb.dev/errors/dev-partner-session-cleanup',
            'title': 'Cleanup unavailable',
          },
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 204,
    );
  }

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    calls.add(_Call('GET', path, _map(data), _authorization(options)));
    final Map<String, dynamic> body;
    if (path == '/v1/jeeb/wallet') {
      if (_topupCommitted &&
          failPostTopupReadOnce &&
          !_postTopupReadFailureRaised) {
        _postTopupReadFailureRaised = true;
        throw DioException(
          requestOptions: RequestOptions(path: path),
          type: DioExceptionType.connectionError,
          error: StateError('post-commit read failed'),
        );
      }
      body = <String, dynamic>{
        'availableBalance': _topupCommitted
            ? (_fundAmount * 0.95) + jeeberDeltaOffset
            : 0,
        if (!omitJeeberCurrency)
          'currency': _topupCommitted ? jeeberCurrencyAfter ?? 'USD' : 'USD',
      };
    } else if (path == '/v1/partner/wallet') {
      if (failPartnerWalletRead && !_partnerWalletReadFailureRaised) {
        _partnerWalletReadFailureRaised = true;
        throw DioException(
          requestOptions: RequestOptions(path: path),
          response: Response<Object?>(
            requestOptions: RequestOptions(path: path),
            statusCode: 503,
          ),
          type: DioExceptionType.badResponse,
        );
      }
      body = <String, dynamic>{
        'partnerId': _activePartnerId,
        'balance': _topupCommitted
            ? 0
            : _creditCommitted
            ? _fundAmount
            : 0,
        if (!omitPartnerCurrency) 'currencyId': 1,
      };
    } else if (path == '/api/User/super-login/users') {
      if (rosterGate != null) await rosterGate!.future;
      body = <String, dynamic>{
        'users': includeRosterJeeber
            ? <Object>[
                <String, dynamic>{
                  'userId': jeeberId,
                  'username': 'demo_jeeber',
                  'status': 'active',
                  'role': 'jeeber',
                  'roles': <String>['jeeber'],
                },
              ]
            : <Object>[],
      };
    } else if (path == '/dev/data/users') {
      body = <String, dynamic>{'users': <Object>[]};
    } else {
      throw StateError('Unexpected GET $path');
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: body as T,
    );
  }

  Map<String, dynamic>? _postBody(String path, Map<String, dynamic> data) {
    if (path == '/dev/partner/credentials') return null;
    if (path == '/dev/seed/user') {
      final role = data['role'];
      if (role == 'partner') {
        _partnerSeedCount++;
        _activePartnerId = _partnerSeedCount == 1 ? partnerId : retryPartnerId;
      }
      final id = role == 'partner'
          ? _activePartnerId
          : role == 'jeeber'
          ? jeeberId
          : adminId;
      return <String, dynamic>{
        'userId': id,
        'username': data['displayName'],
        'status': 'created',
        'role': role,
      };
    }
    if (path == '/v1/partner/auth/login') {
      return <String, dynamic>{
        'accessToken': 'partner-token',
        'partner': <String, dynamic>{'partnerId': _activePartnerId},
      };
    }
    if (path == '/auth/tokens') {
      return <String, dynamic>{
        'accessToken':
            (data['roles'] as List<Object?>?)?.contains('admin') == true
            ? 'admin-token'
            : 'jeeber-token',
        'refreshToken': 'refresh-token',
      };
    }
    if (path.endsWith('/wallet/credits')) {
      _fundAmount = (data['amount'] as num).toDouble();
      _creditCommitted = true;
      return <String, dynamic>{
        'transactionId': 'cash-transaction',
        'amount': data['amount'],
        'fees': 0,
        'status': 'executed',
      };
    }
    if (path == '/v1/partner/wallet/transfers/predict') {
      final amount = (data['amount'] as num).toDouble();
      _fundAmount = amount;
      return <String, dynamic>{
        'grossAmount': amount,
        'fees': amount * 0.05,
        'netToJeeber': amount * 0.95,
        if (!omitOtpPolicy) 'otpRequired': amount > otpThreshold,
      };
    }
    if (path == '/v1/partner/wallet/transfers/otp/challenge') {
      return <String, dynamic>{
        'challengeId': 'otp-challenge',
        'devCode': '123456',
      };
    }
    if (path == '/v1/partner/wallet/transfers') {
      _topupPosts++;
      _fundAmount = (data['amount'] as num).toDouble();
      _topupCommitted = true;
      return <String, dynamic>{
        'transactionId': 'topup-transaction',
        'amount': _fundAmount + (_topupPosts > 1 ? topupReplayAmountOffset : 0),
        'fees': (_fundAmount * 0.05) + transferFeeOffset,
        'status': _topupPosts > 1 && topupReplayStatus != null
            ? topupReplayStatus
            : 'executed',
      };
    }
    throw StateError('Unexpected POST $path');
  }

  static Map<String, dynamic> _map(Object? data) =>
      data is Map<String, dynamic> ? data : <String, dynamic>{};

  static String? _authorization(Options? options) =>
      options?.headers?['Authorization'] as String?;
}

class _Call {
  const _Call(this.method, this.path, this.data, this.authorization);

  final String method;
  final String path;
  final Map<String, dynamic> data;
  final String? authorization;
}
