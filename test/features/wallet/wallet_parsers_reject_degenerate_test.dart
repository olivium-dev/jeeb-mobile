// UX-16/UX-17/UX-22: the wallet parsers must fail rather than fabricate money.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/wallet/data/dio_wallet_ledger_repository.dart';
import 'package:jeeb_mobile/features/wallet/data/dio_wallet_repository.dart';
import 'package:jeeb_mobile/features/wallet/data/dio_wallet_transaction_repository.dart';
import 'package:jeeb_mobile/features/wallet/data/unavailable_wallet_ledger_repository.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_ledger_repository.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_repository.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_transaction_repository.dart';

/// Answers every request with one canned JSON body.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.body);

  Object? body;

  static const int status = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

Dio _dio(_ScriptedAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'http://gw.test'))..httpClientAdapter = adapter;

void main() {
  group('DioWalletRepository — a broke wallet is never fabricated (UX-16)', () {
    test('an empty body throws instead of returning 0.0/empty/USD', () async {
      final repo = DioWalletRepository(_dio(_ScriptedAdapter(const {})));

      await expectLater(
        repo.fetchBalance(),
        throwsA(
          isA<WalletRepositoryException>().having(
            (e) => e.failure,
            'failure',
            WalletFailure.unknown,
          ),
        ),
      );
    });

    test(
      'a missing currency throws — a money screen invents no unit',
      () async {
        final repo = DioWalletRepository(
          _dio(_ScriptedAdapter(const {'availableBalance': 12.0})),
        );

        await expectLater(
          repo.fetchBalance(),
          throwsA(isA<WalletRepositoryException>()),
        );
      },
    );

    test('an UNRECOGNISED affordabilityState throws rather than claiming the '
        'worst state', () async {
      final repo = DioWalletRepository(
        _dio(
          _ScriptedAdapter(const {
            'availableBalance': 12.0,
            'currency': 'USD',
            'affordabilityState': 'brand-new-server-value',
          }),
        ),
      );

      await expectLater(
        repo.fetchBalance(),
        throwsA(isA<WalletRepositoryException>()),
      );
    });

    test('an ABSENT affordabilityState is derived from the balance', () async {
      final repo = DioWalletRepository(
        _dio(
          _ScriptedAdapter(const {'availableBalance': 12.0, 'currency': 'USD'}),
        ),
      );

      final balance = await repo.fetchBalance();
      expect(balance.affordabilityState, WalletAffordability.enough);
      expect(balance.availableBalance, 12.0);
    });
  });

  group('DioWalletLedgerRepository — the sign is derived, never defaulted', () {
    Future<WalletLedgerPage> page(List<Object?> items) {
      final repo = DioWalletLedgerRepository(
        _dio(_ScriptedAdapter({'items': items, 'page': 1, 'totalPages': 1})),
      );
      return repo.fetchLedger();
    }

    test('reserve / feeWon / penalty are debits', () async {
      final result = await page(const <Object?>[
        {'id': 'a', 'type': 'reserve', 'amount': 1.0},
        {'id': 'b', 'type': 'fee_won', 'amount': 2.0},
        {'id': 'c', 'type': 'penalty', 'amount': 3.0},
      ]);

      expect(result.entries.map((e) => e.sign), <int>[-1, -1, -1]);
      expect(result.unrenderableCount, 0);
    });

    test('released / refund / topup / gift are credits', () async {
      final result = await page(const <Object?>[
        {'id': 'a', 'type': 'released', 'amount': 1.0},
        {'id': 'b', 'type': 'refund', 'amount': 2.0},
        {'id': 'c', 'type': 'topup', 'amount': 3.0},
        {'id': 'd', 'type': 'gift', 'amount': 4.0},
      ]);

      expect(result.entries.map((e) => e.sign), <int>[1, 1, 1, 1]);
    });

    test('a row with neither sign nor a known type is DROPPED and counted, '
        'never rendered as a credit', () async {
      final result = await page(const <Object?>[
        {'id': 'a', 'type': 'reserve', 'amount': 1.0},
        {'id': 'b', 'type': 'something-new', 'amount': 2.0},
        'not-a-map',
      ]);

      expect(result.entries.length, 1);
      expect(result.entries.single.id, 'a');
      expect(result.unrenderableCount, 2);
    });

    test('a row with no numeric amount is DROPPED and counted, never a \$0.00 '
        'row', () async {
      final result = await page(const <Object?>[
        {'id': 'a', 'type': 'reserve', 'amount': 1.0},
        {'id': 'b', 'type': 'topup'},
        {'id': 'c', 'type': 'topup', 'amount': 'lots'},
      ]);

      expect(result.entries.single.id, 'a');
      expect(result.unrenderableCount, 2);
    });

    test(
      'a body with NO `items` list throws — it is not an empty ledger',
      () async {
        final repo = DioWalletLedgerRepository(
          _dio(_ScriptedAdapter(const {'page': 1, 'totalPages': 1})),
        );

        await expectLater(
          repo.fetchLedger(),
          throwsA(
            isA<WalletLedgerRepositoryException>().having(
              (e) => e.failure,
              'failure',
              WalletLedgerFailure.unknown,
            ),
          ),
        );
      },
    );

    test('a non-map body throws rather than reporting an empty page', () async {
      final repo = DioWalletLedgerRepository(
        _dio(_ScriptedAdapter(const <Object?>['garbage'])),
      );

      await expectLater(
        repo.fetchLedger(),
        throwsA(isA<WalletLedgerRepositoryException>()),
      );
    });

    test('an explicit sign still wins', () async {
      final result = await page(const <Object?>[
        {'id': 'a', 'type': 'unknown-kind', 'amount': 1.0, 'sign': -1},
      ]);

      expect(result.entries.single.sign, -1);
    });
  });

  group('DioWalletTransactionRepository — one row cannot be dropped', () {
    Future<WalletTransaction> fetch(Map<String, Object?> body) {
      final repo = DioWalletTransactionRepository(_dio(_ScriptedAdapter(body)));
      return repo.fetchTransaction('t-1');
    }

    test('an unknowable sign throws (UX-17)', () async {
      await expectLater(
        fetch(const {'id': 't-1', 'type': 'brand-new', 'currency': 'USD'}),
        throwsA(
          isA<WalletTransactionRepositoryException>().having(
            (e) => e.failure,
            'failure',
            WalletTransactionFailure.unknown,
          ),
        ),
      );
    });

    test('an absent currency throws (UX-22)', () async {
      await expectLater(
        fetch(const {'id': 't-1', 'type': 'reserve', 'amount': 1.0}),
        throwsA(isA<WalletTransactionRepositoryException>()),
      );
    });

    test(
      'an absent amount throws — the one row never renders \$0.00',
      () async {
        await expectLater(
          fetch(const {'id': 't-1', 'type': 'topup', 'currency': 'USD'}),
          throwsA(
            isA<WalletTransactionRepositoryException>().having(
              (e) => e.failure,
              'failure',
              WalletTransactionFailure.unknown,
            ),
          ),
        );
      },
    );

    test('a non-numeric amount throws', () async {
      await expectLater(
        fetch(const {
          'id': 't-1',
          'type': 'topup',
          'amount': '5',
          'currency': 'USD',
        }),
        throwsA(isA<WalletTransactionRepositoryException>()),
      );
    });

    test('a well-formed row derives its sign from the type', () async {
      final txn = await fetch(const {
        'id': 't-1',
        'type': 'topup',
        'amount': 5.0,
        'currency': 'USD',
      });

      expect(txn.sign, 1);
      expect(txn.currency, 'USD');
    });
  });

  test('GEN-01: the release-path ledger stand-in THROWS rather than render a '
      'fabricated empty ledger as real data', () async {
    await expectLater(
      const UnavailableWalletLedgerRepository().fetchLedger(),
      throwsA(isA<WalletLedgerRepositoryException>()),
    );
  });
}
