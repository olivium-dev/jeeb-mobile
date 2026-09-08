// LR-08/LR-09/UX-18: a failed refresh keeps the rows and raises a note.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/session/jeeber_kyc_status_gate.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_ledger_repository.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_activity_list_screen.dart';
import 'package:jeeb_mobile/features/wallet/presentation/wallet_hub_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

/// The cold load lands; every read after it fails.
class _WarmFailingWallet implements WalletRepository {
  _WarmFailingWallet();

  bool _served = false;

  @override
  Future<WalletBalance> fetchBalance() async {
    if (_served) {
      throw const WalletRepositoryException(
        WalletFailure.network,
        cause: NetworkFailure(),
      );
    }
    _served = true;
    return const WalletBalance(
      availableBalance: 40,
      affordabilityState: WalletAffordability.enough,
      reservedNow: 4,
      giftCredit: 5,
      currency: 'USD',
    );
  }
}

class _WarmFailingLedger implements WalletLedgerRepository {
  _WarmFailingLedger(this.entries);

  final List<WalletLedgerEntry> entries;

  bool _served = false;

  @override
  Future<WalletLedgerPage> fetchLedger({
    int page = 1,
    int pageSize = 20,
  }) async {
    if (_served) {
      throw const WalletLedgerRepositoryException(
        WalletLedgerFailure.network,
        cause: NetworkFailure(),
      );
    }
    _served = true;
    return WalletLedgerPage(entries: entries, page: 1, totalPages: 1);
  }
}

class _ApprovedGate implements JeeberKycStatusGate {
  const _ApprovedGate();

  @override
  JeeberKycStatus get status => JeeberKycStatus.approved;

  @override
  bool get isApproved => true;
}

const WalletLedgerEntry _entry = WalletLedgerEntry(
  id: 'ldg-1',
  type: WalletLedgerType.feeWon,
  amount: 0.9,
  sign: -1,
  ref: 'off-1',
  timestamp: '2026-06-18T10:00:00Z',
  currency: 'USD',
);

Widget _reduced(Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child,
  ),
);

void main() {
  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('hub (${locale.languageCode}): a failed refresh keeps the '
        'balance and raises the note, never the error rung', (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapForTest(
          _reduced(
            WalletHubScreen(
              repository: _WarmFailingWallet(),
              kycStatusGate: const _ApprovedGate(),
            ),
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('wallet_available_balance'),
        findsOneWidget,
      );

      await tester.fling(
        find.bySemanticsIdentifier('wallet_available_balance'),
        const Offset(0, 320),
        1000,
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('wallet_refresh_failed_note'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('wallet_available_balance'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('wallet_load_error'), findsNothing);

      await tester.tap(
        find.bySemanticsIdentifier('wallet_refresh_failed_note_dismiss_cta'),
      );
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsIdentifier('wallet_refresh_failed_note'),
        findsNothing,
      );

      handle.dispose();
    });

    testWidgets('activity (${locale.languageCode}): a failed refresh keeps the '
        'rows and raises the note', (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapForTest(
          _reduced(
            WalletActivityListScreen(
              repository: _WarmFailingLedger(const <WalletLedgerEntry>[_entry]),
            ),
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('wallet_activity_row_ldg-1'),
        findsOneWidget,
      );

      await tester.fling(
        find.bySemanticsIdentifier('wallet_activity_row_ldg-1'),
        const Offset(0, 320),
        1000,
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('wallet_activity_refresh_failed_note'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('wallet_activity_row_ldg-1'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('wallet_activity_error'), findsNothing);

      handle.dispose();
    });
  }
}
