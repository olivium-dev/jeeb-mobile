// Shared dev-only fixtures for `WalletActivityListScreen` (JM-055).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_11_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/wallet/presentation/wallet_activity_list_screen.dart`.
//
// The catalog owned three private fakes (`_StaticWalletLedgerRepository`,
// `_PendingWalletLedgerRepository`, `_FailingWalletLedgerRepository`) plus an
// inline three-row ledger; copying that into the preview section would have
// given the two surfaces two different ledgers, free to drift. Both now import
// this file, so a change to the fixture ledger shows up in the catalog and in
// the canvas together.
//
// Everything here is a LOCAL fake: `WalletActivityListScreen` takes a
// `repository:` seam, so neither surface ever resolves the Dio-backed
// `DioWalletLedgerRepository` out of GetIt — `_resolveRepository()`'s `sl<>()`
// branch is never reached. Network-free by construction, not merely by the
// guard the hosts install.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import 'package:jeeb_mobile/features/wallet/domain/wallet_ledger_repository.dart';

/// Canned [WalletLedgerRepository] — every page resolves to [entries], and the
/// envelope reports [totalPages] so `hasMore` (and with it the infinite-scroll
/// footer) can be driven from a fixture. No Dio, no GetIt, no network.
///
/// `const`-constructible so the catalog can keep building
/// `const WalletActivityListScreen(repository: ...)`.
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
  /// and not an empty page. Drives the screen's `failed` branch, and the
  /// specific value picks which of the two error strings is rendered
  /// (`network` → "No connection…", everything else → "Could not load…").
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
///
/// The cubit emits `loading` from `load()` and only leaves it when the future
/// completes, so this is the only way to inspect the eight full-screen D73
/// skeletons without a real slow connection.
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
/// approval starter credit).
///
/// Three types, both signs, and three different leading glyphs — enough for the
/// row to be judged against its neighbours rather than in isolation.
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
///
/// Deliberately the worst page W2m makes plausible, front-loaded so the three
/// awkward rows are the ones a reviewer (and the render test) sees first:
///
///   * row 0 carries the longest reference a payment gateway plausibly returns
///     beside the widest amount a top-up plausibly carries — the pair that
///     starves [WalletActivityRow]'s text column, since the amount is the one
///     child of the row that is not inside the `Expanded`;
///   * row 1 is a `type` this build's enum does not know (`unknown`) AND has no
///     `currency`, so it renders the generic "Activity" label over a bare
///     unitted number;
///   * row 2 has neither `ref` nor `ts`, the row's floor: one label, one
///     number, and 56 pt of leading icon holding the height up anyway;
///   * rows 3-14 are ordinary reserve/release pairs that fill the page past one
///     screen so the scroll behaviour — and the divider rhythm — is real.
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
