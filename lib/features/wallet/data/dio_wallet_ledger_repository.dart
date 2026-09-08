import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../domain/wallet_ledger_repository.dart';

class DioWalletLedgerRepository implements WalletLedgerRepository {
  const DioWalletLedgerRepository(this._dio);

  final Dio _dio;

  static const String _path = '/v1/jeeb/wallet/ledger';

  @override
  Future<WalletLedgerPage> fetchLedger({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        _path,
        queryParameters: <String, Object>{'page': page, 'pageSize': pageSize},
      );
      return _parse(res.data ?? const <String, dynamic>{}, page);
    } on WalletLedgerRepositoryException {
      rethrow;
    } on DioException catch (e) {
      throw WalletLedgerRepositoryException(
        _map(AppFailure.of(e)),
        cause: AppFailure.of(e),
      );
    } catch (e) {
      throw WalletLedgerRepositoryException(
        WalletLedgerFailure.unknown,
        cause: AppFailure.of(e),
      );
    }
  }

  /// A body with no `items` list is not an empty ledger — reporting it as one
  /// would render "no activity yet" over a garbage 200 (GEN-01 class).
  WalletLedgerPage _parse(Map<String, dynamic> json, int requestedPage) {
    final list = json['items'];
    if (list is! List) {
      throw const WalletLedgerRepositoryException(
        WalletLedgerFailure.unknown,
        cause: UnknownFailure(parse: true),
      );
    }
    final entries = <WalletLedgerEntry>[];
    var unrenderable = 0;
    for (final item in list) {
      if (item is! Map) {
        unrenderable++;
        continue;
      }
      // One malformed row must not fail the whole page.
      try {
        final entry = _entry(item.cast<String, dynamic>());
        if (entry == null) {
          unrenderable++;
        } else {
          entries.add(entry);
        }
      } catch (_) {
        unrenderable++;
      }
    }
    return WalletLedgerPage(
      entries: entries,
      page: _int(json['page']) ?? requestedPage,
      totalPages: _int(json['totalPages'] ?? json['total_pages']) ?? 1,
      unrenderableCount: unrenderable,
    );
  }

  /// Null when the row's direction or amount cannot be known: a defaulted
  /// `sign: 1` or `0.0` misstates money (UX-17), so the row is dropped.
  WalletLedgerEntry? _entry(Map<String, dynamic> json) {
    final type = _type(json['type']);
    final sign = _int(json['sign']) ?? _signFor(type);
    final amount = _numOrNull(json['amount']);
    if (sign == null || amount == null) return null;
    return WalletLedgerEntry(
      id: _str(json['id']) ?? '',
      type: type,
      amount: amount,
      sign: sign,
      ref: _str(json['ref']) ?? '',
      timestamp: _str(json['ts'] ?? json['timestamp']) ?? '',
      currency: _str(json['currency']),
    );
  }

  /// The direction each ledger kind moves the balance.
  static int? _signFor(WalletLedgerType type) => switch (type) {
    WalletLedgerType.reserve ||
    WalletLedgerType.feeWon ||
    WalletLedgerType.penalty => -1,
    WalletLedgerType.released ||
    WalletLedgerType.refund ||
    WalletLedgerType.topup ||
    WalletLedgerType.gift => 1,
    WalletLedgerType.unknown => null,
  };

  WalletLedgerType _type(Object? v) {
    switch (v) {
      case 'reserve':
        return WalletLedgerType.reserve;
      case 'fee_won':
      case 'feeWon':
        return WalletLedgerType.feeWon;
      case 'released':
        return WalletLedgerType.released;
      case 'refund':
        return WalletLedgerType.refund;
      case 'penalty':
        return WalletLedgerType.penalty;
      case 'topup':
        return WalletLedgerType.topup;
      case 'gift':
        return WalletLedgerType.gift;
      default:
        return WalletLedgerType.unknown;
    }
  }

  double? _numOrNull(Object? v) => (v is num) ? v.toDouble() : null;
  int? _int(Object? v) => (v is num) ? v.toInt() : null;

  String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  WalletLedgerFailure _map(AppFailure f) => switch (f) {
    NetworkFailure() || TimeoutFailure() => WalletLedgerFailure.network,
    UnauthorizedFailure() ||
    ForbiddenFailure() => WalletLedgerFailure.unauthorized,
    _ => WalletLedgerFailure.unknown,
  };
}
