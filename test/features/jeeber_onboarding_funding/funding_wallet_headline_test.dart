// ES-17 + R2 seam: the funding wallet rung stops borrowing another screen's
// app-bar title, and an unregistered repository reaches the failed rung.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding_funding/presentation/onboarding_funding_screen.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _FailingWallet implements WalletRepository {
  const _FailingWallet(this.failure, {this.cause});

  final WalletFailure failure;
  final AppFailure? cause;

  @override
  Future<WalletBalance> fetchBalance() async {
    throw WalletRepositoryException(failure, cause: cause);
  }
}

class _StalledWallet implements WalletRepository {
  _StalledWallet();

  final Completer<WalletBalance> _never = Completer<WalletBalance>();

  @override
  Future<WalletBalance> fetchBalance() => _never.future;
}

Future<void> _pump(
  WidgetTester tester, {
  WalletRepository? repo,
  Locale locale = const Locale('en'),
  bool settle = true,
}) async {
  await tester.pumpWidget(
    wrapForTest(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: OnboardingFundingScreen(repository: repo),
        ),
      ),
      locale: locale,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String tag = locale.languageCode;
    final String expected = locale.languageCode == 'ar'
        ? 'جارٍ التحقق من رصيد البداية…'
        : 'Checking your starter credit…';

    testWidgets('$tag: the loading headline is the funding key, NOT '
        'walletHubTitle', (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, repo: _StalledWallet(), locale: locale);

      expect(
        find.bySemanticsIdentifier('funding_wallet_loading'),
        findsOneWidget,
      );
      expect(find.text(expected), findsOneWidget);
      // The other screen's app-bar title never appears here.
      expect(find.text('Jeeber fee balance'), findsNothing);

      handle.dispose();
    });

    testWidgets('$tag: the error rung is kind-aware and keeps its frozen ids',
        (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(
        tester,
        repo: const _FailingWallet(
          WalletFailure.network,
          cause: NetworkFailure(),
        ),
        locale: locale,
      );

      expect(
        find.bySemanticsIdentifier('funding_wallet_error'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('funding_wallet_retry'),
        findsOneWidget,
      );
      expect(find.text('Jeeber fee balance'), findsNothing);

      handle.dispose();
    });
  }

  testWidgets('a 500 does NOT blame the connection; a network failure does',
      (tester) async {
    useReduceMotion(tester);
    await _pump(
      tester,
      repo: const _FailingWallet(
        WalletFailure.unknown,
        cause: ServerFailure(status: 500),
      ),
    );
    expect(find.text('Check your connection and try again.'), findsNothing);
    expect(find.bySemanticsIdentifier('funding_wallet_error'), findsOneWidget);
  });

  testWidgets('R2 seam: an UNREGISTERED WalletRepository reaches the failed '
      'rung instead of throwing a raw GetIt StateError', (tester) async {
    useReduceMotion(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pump(tester);

    expect(tester.takeException(), isNull);
    expect(
      find.bySemanticsIdentifier('funding_wallet_error'),
      findsOneWidget,
    );

    handle.dispose();
  });
}
