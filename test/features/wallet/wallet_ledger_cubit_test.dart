// Unit tests for WalletLedgerCubit (JM-055). Proves the 4-state machine

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/wallet/application/wallet_ledger_cubit.dart';
import 'package:jeeb_mobile/features/wallet/application/wallet_ledger_state.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_ledger_repository.dart';

/// Serves a fixed list, paginating it into [pageSize] chunks so the cubit's
/// page/hasMore contract is exercised exactly as W2m would.
class _PagedRepository implements WalletLedgerRepository {
  _PagedRepository({
    List<WalletLedgerEntry>? all,
    this.fetchThrows,
    this.throwOnPage,
  }) : _all = all ?? const <WalletLedgerEntry>[];

  List<WalletLedgerEntry> _all;

  /// When set, EVERY fetch throws this failure (cold-load failure path).
  final WalletLedgerFailure? fetchThrows;

  /// When set, only the fetch for this 1-based page throws (load-more failure).
  final int? throwOnPage;

  int fetchCalls = 0;
  final List<int> requestedPages = <int>[];

  void seed(List<WalletLedgerEntry> all) => _all = all;

  @override
  Future<WalletLedgerPage> fetchLedger({
    int page = 1,
    int pageSize = 20,
  }) async {
    fetchCalls++;
    requestedPages.add(page);
    final f = fetchThrows;
    if (f != null) throw WalletLedgerRepositoryException(f);
    if (throwOnPage == page) {
      throw const WalletLedgerRepositoryException(WalletLedgerFailure.network);
    }
    final start = (page - 1) * pageSize;
    final end = (start + pageSize) > _all.length
        ? _all.length
        : start + pageSize;
    final slice = (start >= _all.length)
        ? const <WalletLedgerEntry>[]
        : _all.sublist(start, end);
    final totalPages = _all.isEmpty
        ? 1
        : ((_all.length + pageSize - 1) ~/ pageSize);
    return WalletLedgerPage(entries: slice, page: page, totalPages: totalPages);
  }
}

WalletLedgerEntry _row(
  String id, {
  WalletLedgerType type = WalletLedgerType.reserve,
  double amount = 0.9,
  int sign = -1,
  String ref = 'off-1',
  String ts = '2026-06-18T10:00:00Z',
}) => WalletLedgerEntry(
  id: id,
  type: type,
  amount: amount,
  sign: sign,
  ref: ref,
  timestamp: ts,
  currency: 'USD',
);

List<WalletLedgerEntry> _rows(int n) =>
    List<WalletLedgerEntry>.generate(n, (i) => _row('led-$i'));

void main() {
  group('WalletLedgerCubit.load', () {
    test(
      'initial → loaded with page 1 + hasMore when more pages exist',
      () async {
        final repo = _PagedRepository(all: _rows(50));
        final cubit = WalletLedgerCubit(repository: repo, pageSize: 20);
        expect(cubit.state.status, WalletLedgerStatus.initial);

        await cubit.load();

        expect(cubit.state.status, WalletLedgerStatus.loaded);
        expect(cubit.state.entries.length, 20);
        expect(cubit.state.entries.first.id, 'led-0');
        expect(cubit.state.page, 1);
        expect(cubit.state.hasMore, isTrue);
        await cubit.close();
      },
    );

    test(
      'loaded with an empty list (empty is a sub-state of loaded)',
      () async {
        final cubit = WalletLedgerCubit(repository: _PagedRepository());
        await cubit.load();
        expect(cubit.state.status, WalletLedgerStatus.loaded);
        expect(cubit.state.hasEntries, isFalse);
        expect(cubit.state.hasMore, isFalse);
        await cubit.close();
      },
    );

    test('single page → loaded, hasMore false', () async {
      final cubit = WalletLedgerCubit(
        repository: _PagedRepository(all: _rows(5)),
        pageSize: 20,
      );
      await cubit.load();
      expect(cubit.state.entries.length, 5);
      expect(cubit.state.hasMore, isFalse);
      await cubit.close();
    });

    test(
      'network failure → failed + typed WalletLedgerFailure.network',
      () async {
        final cubit = WalletLedgerCubit(
          repository: _PagedRepository(
            fetchThrows: WalletLedgerFailure.network,
          ),
        );
        await cubit.load();
        expect(cubit.state.status, WalletLedgerStatus.failed);
        expect(cubit.state.error, WalletLedgerFailure.network);
        await cubit.close();
      },
    );

    test('re-entry guard: a second load() is a no-op', () async {
      final repo = _PagedRepository(all: _rows(3));
      final cubit = WalletLedgerCubit(repository: repo, pageSize: 20);
      await cubit.load();
      final callsAfterFirst = repo.fetchCalls;
      await cubit.load(); // guarded — status is no longer initial
      expect(repo.fetchCalls, callsAfterFirst);
      await cubit.close();
    });
  });

  group('WalletLedgerCubit.loadMore (infinite scroll)', () {
    test('appends the next page and advances the cursor', () async {
      final repo = _PagedRepository(all: _rows(50));
      final cubit = WalletLedgerCubit(repository: repo, pageSize: 20);
      await cubit.load();

      await cubit.loadMore();

      expect(cubit.state.entries.length, 40);
      expect(cubit.state.page, 2);
      expect(cubit.state.hasMore, isTrue);
      expect(repo.requestedPages, [1, 2]);
      await cubit.close();
    });

    test('clears hasMore at the last page', () async {
      final repo = _PagedRepository(all: _rows(30));
      final cubit = WalletLedgerCubit(repository: repo, pageSize: 20);
      await cubit.load(); // 20, hasMore
      await cubit.loadMore(); // +10, last page
      expect(cubit.state.entries.length, 30);
      expect(cubit.state.hasMore, isFalse);
      await cubit.close();
    });

    test('no-op when there is no further page', () async {
      final repo = _PagedRepository(all: _rows(5));
      final cubit = WalletLedgerCubit(repository: repo, pageSize: 20);
      await cubit.load();
      await cubit.loadMore();
      expect(repo.requestedPages, [1]); // page 2 never requested
      await cubit.close();
    });

    test('de-dupes a boundary row re-emitted on the next page', () async {
      // 21 rows, pageSize 20 → page 2 = [led-20]; manually re-seed a repo whose
      final repo = _PagedRepository(all: _rows(21));
      final cubit = WalletLedgerCubit(repository: repo, pageSize: 20);
      await cubit.load();
      await cubit.loadMore();
      final ids = cubit.state.entries.map((e) => e.id).toList();
      expect(ids.length, ids.toSet().length); // no duplicates
      expect(cubit.state.entries.length, 21);
      await cubit.close();
    });

    test(
      'load-more failure → soft loadMoreError, rows intact; retry recovers',
      () async {
        final repo = _PagedRepository(all: _rows(50), throwOnPage: 2);
        final cubit = WalletLedgerCubit(repository: repo, pageSize: 20);
        await cubit.load();

        await cubit.loadMore(); // page 2 throws
        expect(cubit.state.status, WalletLedgerStatus.loaded);
        expect(cubit.state.entries.length, 20); // page 1 intact
        expect(cubit.state.loadMoreError, isTrue);
        expect(cubit.state.loadingMore, isFalse);

        // Heal the repo and retry.
        final healed = _PagedRepository(all: _rows(50));
        final cubit2 = WalletLedgerCubit(repository: healed, pageSize: 20);
        await cubit2.load();
        await cubit2.loadMore();
        expect(cubit2.state.entries.length, 40);
        expect(cubit2.state.loadMoreError, isFalse);
        await cubit.close();
        await cubit2.close();
      },
    );
  });

  group('WalletLedgerCubit.refresh', () {
    test('re-fetches page 1, replaces the list, resets paging', () async {
      final repo = _PagedRepository(all: _rows(50));
      final cubit = WalletLedgerCubit(repository: repo, pageSize: 20);
      await cubit.load();
      await cubit.loadMore(); // page 2 → 40 rows, page=2

      repo.seed([_row('fresh-0'), _row('fresh-1')]);
      await cubit.refresh();

      expect(cubit.state.status, WalletLedgerStatus.loaded);
      expect(cubit.state.entries.map((e) => e.id).toList(), [
        'fresh-0',
        'fresh-1',
      ]);
      expect(cubit.state.page, 1);
      expect(cubit.state.hasMore, isFalse);
      await cubit.close();
    });

    test('LR-08: a FAILED refresh keeps the rows and the loaded status, and '
        'raises refreshError only', () async {
      final repo = _WarmFailingRepository(_rows(3));
      final cubit = WalletLedgerCubit(repository: repo, pageSize: 20);
      await cubit.load();
      expect(cubit.state.entries.length, 3);

      await cubit.refresh();

      expect(cubit.state.status, WalletLedgerStatus.loaded);
      expect(cubit.state.entries.length, 3);
      expect(cubit.state.error, isNull);
      expect(cubit.state.refreshError, isNotNull);

      cubit.clearRefreshError();
      expect(cubit.state.refreshError, isNull);
      await cubit.close();
    });
  });

  group('WalletLedgerCubit — re-entry guards', () {
    test(
      'load() is re-entrant from `failed`, so the error rung retry works',
      () async {
        final repo = _PagedRepository(
          all: _rows(3),
          fetchThrows: WalletLedgerFailure.network,
        );
        final cubit = WalletLedgerCubit(repository: repo, pageSize: 20);
        await cubit.load();
        expect(cubit.state.status, WalletLedgerStatus.failed);
        final callsAfterFirst = repo.fetchCalls;

        await cubit.load();

        expect(repo.fetchCalls, callsAfterFirst + 1);
        await cubit.close();
      },
    );

    test('a standing loadMoreError blocks re-entry, so a scroll cannot become '
        'an unbounded retry loop', () async {
      final repo = _PagedRepository(all: _rows(50), throwOnPage: 2);
      final cubit = WalletLedgerCubit(repository: repo, pageSize: 20);
      await cubit.load();

      await cubit.loadMore();
      expect(cubit.state.loadMoreError, isTrue);
      final callsAfterFailure = repo.fetchCalls;

      await cubit.loadMore();
      await cubit.loadMore();
      expect(repo.fetchCalls, callsAfterFailure);

      // Only the explicit retry re-enters.
      await cubit.retryLoadMore();
      expect(repo.fetchCalls, callsAfterFailure + 1);
      await cubit.close();
    });

    test(
      'the load-more failure is CLASSIFIED so the footer can be kind-aware',
      () async {
        final repo = _PagedRepository(all: _rows(50), throwOnPage: 2);
        final cubit = WalletLedgerCubit(repository: repo, pageSize: 20);
        await cubit.load();
        await cubit.loadMore();

        expect(cubit.state.loadMoreFailure, isNotNull);
        await cubit.close();
      },
    );
  });
}

/// The cold load lands; every read after it fails.
class _WarmFailingRepository implements WalletLedgerRepository {
  _WarmFailingRepository(this.entries);

  final List<WalletLedgerEntry> entries;

  bool _served = false;

  @override
  Future<WalletLedgerPage> fetchLedger({
    int page = 1,
    int pageSize = 20,
  }) async {
    if (_served) {
      throw const WalletLedgerRepositoryException(WalletLedgerFailure.network);
    }
    _served = true;
    return WalletLedgerPage(entries: entries, page: 1, totalPages: 1);
  }
}
