// W6 G3/G4: the E1 insufficient-balance sheet renders the FROZEN aggregate
// copy, the optional breakdown rows, and never a fabricated "USD".

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/offers/application/offer_submission_cubit.dart';
import 'package:jeeb_mobile/features/offers/domain/offer_submission_repository.dart';
import 'package:jeeb_mobile/features/offers/presentation/offer_submission_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

/// Repository whose submit always raises [exception] — the only way to drive
/// the cubit into a real failure state through its public API.
class _ThrowingRepo implements OfferSubmissionRepository {
  const _ThrowingRepo(this.exception);

  final OfferSubmissionException exception;

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async {
    throw exception;
  }
}

/// The FROZEN copy, read from the ARB itself (CONTRACT §5) — never retyped.
String _frozen(String key, {String lang = 'en'}) =>
    debugLoadAppLocalizationsSync(
      Locale(lang),
      File('lib/l10n/app_$lang.arb').readAsStringSync(),
    ).byKey(key)!;

Widget _harness(OfferFormCubit cubit, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: OfferSubmissionScreen(
      requestId: 'req-1',
      submissionService: null,
      cubit: cubit,
      onWithdrawn: _noop,
    ),
  );
}

void _noop() {}

/// Mounts the composer on the `cubit:` seam, then drives that same cubit into
/// the 402 state — the sheet rides a mode TRANSITION, so it must land mounted.
Future<void> _openSheet(
  WidgetTester tester,
  InsufficientBalanceInfo info, {
  Locale locale = const Locale('en'),
}) async {
  final cubit = OfferFormCubit(
    repository: _ThrowingRepo(
      OfferSubmissionException(
        OfferSubmissionFailure.insufficientBalance,
        balance: info,
      ),
    ),
  );
  addTearDown(cubit.close);

  await tester.pumpWidget(_harness(cubit, locale: locale));
  await tester.pumpAndSettle();

  await cubit.submit(requestId: 'req-1', priceUsd: 100, etaMinutes: 10);
  await tester.pumpAndSettle();
}

/// Every rendered string inside the sheet subtree.
List<String> _sheetTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(
      of: find.bySemanticsIdentifier('insufficient_balance_sheet'),
      matching: find.byType(Text),
    ))
    .map((t) => t.data ?? '')
    .toList();

const InsufficientBalanceInfo _fullAggregate = InsufficientBalanceInfo(
  needed: 20,
  available: 10,
  currency: 'USD',
  thisOffer: 10,
  outstanding: 10,
);

void main() {
  group('Insufficient-balance sheet — aggregate 402 (CONTRACT §2 E1)', () {
    testWidgets('renders the C-5 title and all five amount identifiers',
        (tester) async {
      final handle = tester.ensureSemantics();

      await _openSheet(tester, _fullAggregate);

      expect(
        find.bySemanticsIdentifier('insufficient_balance_sheet'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('insufficient_balance_needed_amount'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('insufficient_balance_available_amount'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('insufficient_balance_this_offer_amount'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('insufficient_balance_outstanding_amount'),
        findsOneWidget,
      );
      expect(
        find.text(_frozen('walletGuardInsufficientSheetTitle')),
        findsOneWidget,
      );

      handle.dispose();
    });

    testWidgets('a 402 without thisOffer/outstanding hides the two new rows '
        '(pre-aggregate gateway)', (tester) async {
      final handle = tester.ensureSemantics();

      await _openSheet(
        tester,
        const InsufficientBalanceInfo(
          needed: 20,
          available: 10,
          currency: 'USD',
        ),
      );

      expect(
        find.bySemanticsIdentifier('insufficient_balance_sheet'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('insufficient_balance_needed_amount'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('insufficient_balance_this_offer_amount'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('insufficient_balance_outstanding_amount'),
        findsNothing,
      );

      handle.dispose();
    });

    testWidgets('a blank currency renders the neutral \$ mark and NEVER the '
        'literal USD (c3-3)', (tester) async {
      final handle = tester.ensureSemantics();

      await _openSheet(
        tester,
        const InsufficientBalanceInfo(
          needed: 20,
          available: 10,
          currency: '',
          thisOffer: 10,
          outstanding: 10,
        ),
      );

      final texts = _sheetTexts(tester);
      expect(texts, isNotEmpty);
      expect(
        texts.any((s) => s.contains(r'$')),
        isTrue,
        reason: 'a blank currency falls back to the neutral money mark',
      );
      expect(find.textContaining('USD'), findsNothing,
          reason: 'mobile must never fabricate a currency the server omitted');

      handle.dispose();
    });
  });
}
