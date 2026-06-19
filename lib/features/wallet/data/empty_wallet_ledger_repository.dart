import '../domain/wallet_ledger_repository.dart';

/// In-memory empty [WalletLedgerRepository] — a presentation FALLBACK / test
/// seam only, NEVER registered in DI (40_GUARDRAILS_ARCH §6 / §12: fakes are a
/// constructor seam, not a DI default; the LIVE `DioWalletLedgerRepository` is
/// the registered binding — `injection_container.dart` JM-055, W2m LIVE).
///
/// Used by [WalletActivityListScreen] when `sl<WalletLedgerRepository>()` is not
/// registered (e.g. the router-resolution widget tests, which build the route
/// tree without `configureDependencies()`) — mirrors
/// `EmptyNotificationsRepository` (JM-057) /
/// `ClientOffersScreen._resolveRepository()` falling back to a fake. Returns one
/// empty page so the screen renders its empty state instead of throwing on an
/// unconfigured GetIt.
class EmptyWalletLedgerRepository implements WalletLedgerRepository {
  const EmptyWalletLedgerRepository();

  @override
  Future<WalletLedgerPage> fetchLedger({int page = 1, int pageSize = 20}) async {
    return const WalletLedgerPage(
      entries: <WalletLedgerEntry>[],
      page: 1,
      totalPages: 1,
    );
  }
}
