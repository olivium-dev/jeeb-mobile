// Shared dev-only fixtures for `WalletActivityListScreen` (JM-055).

import 'dart:async';

import 'package:jeeb_mobile/features/wallet/domain/wallet_ledger_repository.dart';

/// Canned [WalletLedgerRepository] — every page resolves to [entries], and the
/// envelope reports [totalPages] so `hasMore` (and with it the infinite-scroll
/// footer) can be driven from a fixture. No Dio, no GetIt, no network.
class WalletActivityListScreenFakeRepository implements WalletLedgerRepository {
  const WalletActivityListScreenFakeRepository(
    this.entries, {
    this.totalPages = 1,
    this.failure,
  });

  /// What `GET /v1/jeeb/wallet/ledger` resolves to, newest-first (the cubit
  /// keeps the order it is given).
  final List<WalletLedgerEntry> entries;

  /// The envelope's `totalPages`. `> 1` makes [WalletLedgerPage.hasMore] true,
  /// which is what puts the `wallet_activity_load_more` footer under the list.
  final int totalPages;

  /// When non-null the read throws a [WalletLedgerRepositoryException] with
  /// this typed failure, which is how the live repository fails — not a null
  final WalletLedgerFailure? failure;

  @override
  Future<WalletLedgerPage> fetchLedger({int page = 1, int pageSize = 20}) async {
    final WalletLedgerFailure? f = failure;
    if (f != null) throw WalletLedgerRepositoryException(f);
    return WalletLedgerPage(
      entries: entries,
      page: page,
      totalPages: totalPages,
    );
  }
}

/// A read that never lands, holding the screen on `WalletLedgerStatus.loading`
/// for as long as the surface is open.
/// The cubit emits `loading` from `load()` and only leaves it when the future
class WalletActivityListScreenPendingRepository
    extends WalletActivityListScreenFakeRepository {
  const WalletActivityListScreenPendingRepository()
      : super(const <WalletLedgerEntry>[]);

  @override
  Future<WalletLedgerPage> fetchLedger({int page = 1, int pageSize = 20}) =>
      Completer<WalletLedgerPage>().future;
}

/// The mixed ledger the catalog has shown since DT-04: one debit (the platform
/// fee taken when an offer is won) and two credits (a store top-up and the
const List<WalletLedgerEntry> walletActivityListScreenMixedLedger =
    <WalletLedgerEntry>[
  WalletLedgerEntry(
    id: 'ldg-1',
    type: WalletLedgerType.feeWon,
    amount: 1.5,
    sign: -1,
    ref: 'off-1001',
    timestamp: '2026-07-01T09:30:00Z',
    currency: 'USD',
  ),
  WalletLedgerEntry(
    id: 'ldg-2',
    type: WalletLedgerType.topup,
    amount: 50.0,
    sign: 1,
    ref: 'topup-001',
    timestamp: '2026-06-28T12:00:00Z',
    currency: 'USD',
  ),
  WalletLedgerEntry(
    id: 'ldg-3',
    type: WalletLedgerType.gift,
    amount: 50.0,
    sign: 1,
    ref: 'gift-kyc-001',
    timestamp: '2026-06-20T08:00:00Z',
    currency: 'USD',
  ),
];

/// A full first page — the layout ceiling for the LIST, not for one row.
/// Deliberately the worst page W2m makes plausible, front-loaded so the three
final List<WalletLedgerEntry> walletActivityListScreenFullPage =
    <WalletLedgerEntry>[
  const WalletLedgerEntry(
    id: 'ldg-topup-long',
    type: WalletLedgerType.topup,
    amount: 1250,
    sign: 1,
    ref: 'off-2026-06-18-beirut-hamra-b42-3f-abdulrahman-almuhandis-0091',
    timestamp: '2026-07-02T08:15:00Z',
    currency: 'USD',
  ),
  const WalletLedgerEntry(
    id: 'ldg-unknown',
    type: WalletLedgerType.unknown,
    amount: 1.75,
    sign: -1,
    ref: 'chg-9f2',
    timestamp: '2026-07-02T07:00:00Z',
  ),
  const WalletLedgerEntry(
    id: 'ldg-bare',
    type: WalletLedgerType.released,
    amount: 12.5,
    sign: 1,
    ref: '',
    timestamp: '',
    currency: 'USD',
  ),
  for (int i = 3; i <= 14; i++)
    WalletLedgerEntry(
      id: 'ldg-page-$i',
      type: i.isEven ? WalletLedgerType.reserve : WalletLedgerType.released,
      amount: 3 + i / 2,
      sign: i.isEven ? -1 : 1,
      ref: 'off-20260$i',
      timestamp: '2026-06-${(i + 10).toString().padLeft(2, '0')}T09:00:00Z',
      currency: 'USD',
    ),
];
