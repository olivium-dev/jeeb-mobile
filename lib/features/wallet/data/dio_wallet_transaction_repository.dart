import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../domain/wallet_ledger_repository.dart' show WalletLedgerType;
import '../domain/wallet_transaction_repository.dart';

class DioWalletTransactionRepository implements WalletTransactionRepository {
  const DioWalletTransactionRepository(this._dio);

  final Dio _dio;

  @override
  Future<WalletTransaction> fetchTransaction(String id) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/jeeb/wallet/ledger/$id',
      );
      return _parse(res.data ?? const <String, dynamic>{}, id);
    } on WalletTransactionRepositoryException {
      rethrow;
    } on DioException catch (e) {
      throw WalletTransactionRepositoryException(
        _map(AppFailure.of(e)),
        cause: AppFailure.of(e),
      );
    } catch (e) {
      throw WalletTransactionRepositoryException(
        WalletTransactionFailure.unknown,
        cause: AppFailure.of(e),
      );
    }
  }

  /// A detail screen shows ONE row, so it cannot drop an unreadable one: a
  /// guessed sign, currency or amount would misstate money (UX-17/UX-22).
  WalletTransaction _parse(Map<String, dynamic> json, String fallbackId) {
    final type = _type(json['category'] ?? json['type']);
    final sign = _int(json['sign']) ?? _signFor(type);
    final currency = _str(json['currency']);
    final amount = _numOrNull(json['amount']);
    if (sign == null || currency == null || amount == null) {
      throw const WalletTransactionRepositoryException(
        WalletTransactionFailure.unknown,
        cause: UnknownFailure(parse: true),
      );
    }
    return WalletTransaction(
      id: _str(json['id']) ?? fallbackId,
      type: type,
      amount: amount,
      sign: sign,
      currency: currency,
      timestamp: _str(json['ts'] ?? json['timestamp']) ?? '',
      title: _str(json['title']),
      ref: _str(json['ref']),
      offerId: _str(json['offerId'] ?? json['offer_id']),
      orderId: _str(json['orderId'] ?? json['order_id']),
      disputeId: _str(json['disputeId'] ?? json['dispute_id']),
      pinnedPrice: _numOrNull(json['pinnedPrice'] ?? json['pinned_price']),
      feeRate: _numOrNull(json['feeRate'] ?? json['fee_rate']),
    );
  }

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

  double? _numOrNull(Object? v) => (v is num) ? v.toDouble() : null;
  int? _int(Object? v) => (v is num) ? v.toInt() : null;

  String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  WalletTransactionFailure _map(AppFailure f) => switch (f) {
    NetworkFailure() || TimeoutFailure() => WalletTransactionFailure.network,
    NotFoundFailure() || GoneFailure() => WalletTransactionFailure.notFound,
    UnauthorizedFailure() ||
    ForbiddenFailure() => WalletTransactionFailure.unauthorized,
    _ => WalletTransactionFailure.unknown,
  };
}
