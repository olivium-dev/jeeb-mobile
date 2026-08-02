import 'package:dio/dio.dart';

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
    } on DioException catch (e) {
      throw WalletTransactionRepositoryException(_map(e), e.message);
    }
  }

  WalletTransaction _parse(Map<String, dynamic> json, String fallbackId) {
    return WalletTransaction(
      id: _str(json['id']) ?? fallbackId,
      type: _type(json['category'] ?? json['type']),
      amount: _num(json['amount']),
      sign: _int(json['sign']) ?? 1,
      currency: _str(json['currency']) ?? 'USD',
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

  double _num(Object? v) => (v is num) ? v.toDouble() : 0.0;
  double? _numOrNull(Object? v) => (v is num) ? v.toDouble() : null;
  int? _int(Object? v) => (v is num) ? v.toInt() : null;

  String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  WalletTransactionFailure _map(DioException e) {
    final code = e.response?.statusCode;
    if (code == 404) return WalletTransactionFailure.notFound;
    if (code == 401 || code == 403) {
      return WalletTransactionFailure.unauthorized;
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return WalletTransactionFailure.network;
      default:
        return WalletTransactionFailure.unknown;
    }
  }
}
