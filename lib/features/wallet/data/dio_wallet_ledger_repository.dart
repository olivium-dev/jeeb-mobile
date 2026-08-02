import 'package:dio/dio.dart';

import '../domain/wallet_ledger_repository.dart';

class DioWalletLedgerRepository implements WalletLedgerRepository {
  const DioWalletLedgerRepository(this._dio);

  final Dio _dio;

  static const String _path = '/v1/jeeb/wallet/ledger';

  @override
  Future<WalletLedgerPage> fetchLedger({int page = 1, int pageSize = 20}) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        _path,
        queryParameters: <String, Object>{'page': page, 'pageSize': pageSize},
      );
      return _parse(res.data ?? const <String, dynamic>{}, page);
    } on DioException catch (e) {
      throw WalletLedgerRepositoryException(_map(e), e.message);
    }
  }

  WalletLedgerPage _parse(Map<String, dynamic> json, int requestedPage) {
    final rawItems = json['items'];
    final list = rawItems is List ? rawItems : const <dynamic>[];
    final entries = <WalletLedgerEntry>[];
    for (final item in list) {
      if (item is Map) {
        entries.add(_entry(item.cast<String, dynamic>()));
      }
    }
    return WalletLedgerPage(
      entries: entries,
      page: _int(json['page']) ?? requestedPage,
      totalPages: _int(json['totalPages'] ?? json['total_pages']) ?? 1,
    );
  }

  WalletLedgerEntry _entry(Map<String, dynamic> json) {
    return WalletLedgerEntry(
      id: _str(json['id']) ?? '',
      type: _type(json['type']),
      amount: _num(json['amount']),
      sign: _int(json['sign']) ?? 1,
      ref: _str(json['ref']) ?? '',
      timestamp: _str(json['ts'] ?? json['timestamp']) ?? '',
      currency: _str(json['currency']),
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
  int? _int(Object? v) => (v is num) ? v.toInt() : null;

  String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  WalletLedgerFailure _map(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return WalletLedgerFailure.unauthorized;
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return WalletLedgerFailure.network;
      default:
        return WalletLedgerFailure.unknown;
    }
  }
}
