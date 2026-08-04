import 'package:dio/dio.dart';

import '../domain/wallet_repository.dart';

class DioWalletRepository implements WalletRepository {
  const DioWalletRepository(this._dio);

  final Dio _dio;

  static const String _path = '/v1/jeeb/wallet';

  @override
  Future<WalletBalance> fetchBalance() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(_path);
      return _parse(res.data ?? const <String, dynamic>{});
    } on DioException catch (e) {
      throw WalletRepositoryException(_map(e), e.message);
    }
  }

  WalletBalance _parse(Map<String, dynamic> json) {
    return WalletBalance(
      availableBalance:
          _num(json['availableBalance'] ?? json['available_balance']),
      affordabilityState: _affordability(
        json['affordabilityState'] ?? json['affordability_state'],
      ),
      reservedNow: _num(json['reservedNow'] ?? json['reserved_now']),
      giftCredit: _num(json['giftCredit'] ?? json['gift_credit']),
      currency: _str(json['currency']) ?? 'USD',
    );
  }

  double _num(Object? v) => (v is num) ? v.toDouble() : 0.0;

  String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  WalletAffordability _affordability(Object? v) {
    switch (v) {
      case 'enough':
        return WalletAffordability.enough;
      case 'low':
        return WalletAffordability.low;
      case 'empty':
        return WalletAffordability.empty;
      case 'all_reserved':
      case 'allReserved':
        return WalletAffordability.allReserved;
      default:
        return WalletAffordability.empty;
    }
  }

  WalletFailure _map(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return WalletFailure.unauthorized;
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return WalletFailure.network;
      default:
        return WalletFailure.unknown;
    }
  }
}
