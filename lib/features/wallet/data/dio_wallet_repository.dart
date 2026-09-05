import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
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
    } on WalletRepositoryException {
      rethrow;
    } on DioException catch (e) {
      throw WalletRepositoryException(
        _map(AppFailure.of(e)),
        cause: AppFailure.of(e),
      );
    } catch (e) {
      throw WalletRepositoryException(
        WalletFailure.unknown,
        cause: AppFailure.of(e),
      );
    }
  }

  /// UX-16: a missing balance or currency is a FAILURE, never a fabricated
  /// broke wallet — a $0.00 render disables the offer CTA on real money.
  WalletBalance _parse(Map<String, dynamic> json) {
    final available = _num(
      json['availableBalance'] ?? json['available_balance'],
    );
    final currency = _str(json['currency']);
    if (available == null || currency == null) {
      throw const WalletRepositoryException(
        WalletFailure.unknown,
        cause: UnknownFailure(parse: true),
      );
    }
    return WalletBalance(
      availableBalance: available,
      affordabilityState: _affordability(
        json['affordabilityState'] ?? json['affordability_state'],
        available,
      ),
      reservedNow: _num(json['reservedNow'] ?? json['reserved_now']) ?? 0.0,
      giftCredit: _num(json['giftCredit'] ?? json['gift_credit']) ?? 0.0,
      currency: currency,
    );
  }

  double? _num(Object? v) => v is num ? v.toDouble() : null;

  String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  /// An absent field is derived from the balance; an UNRECOGNISED one is a
  /// failure — mapping it onto `empty` claimed the worst state on a guess.
  WalletAffordability _affordability(Object? v, double available) {
    switch (v) {
      case null:
        return available > 0
            ? WalletAffordability.enough
            : WalletAffordability.empty;
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
        throw const WalletRepositoryException(
          WalletFailure.unknown,
          cause: UnknownFailure(parse: true),
        );
    }
  }

  WalletFailure _map(AppFailure f) => switch (f) {
    NetworkFailure() || TimeoutFailure() => WalletFailure.network,
    UnauthorizedFailure() || ForbiddenFailure() => WalletFailure.unauthorized,
    _ => WalletFailure.unknown,
  };
}
