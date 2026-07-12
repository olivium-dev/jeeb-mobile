import 'package:dio/dio.dart';

import '../domain/wallet_repository.dart';

/// Dio-backed [WalletRepository] (JM-053) — W1m `GET /v1/jeeb/wallet`.
///
/// NOT the DI default yet: the wallet endpoint (W1m) is backend-owned and not
/// live on `:4010` (CTO-D2), so `injection_container.dart` binds the
/// [StubWalletRepository] INTEGRATOR-STUB until W1m lands. This impl is the
/// swap target — the JM-053 engineer (or the integrator at the W1m hand-off)
/// repoints the DI registration here without touching the screen.
///
/// Gateway-contract path: `/v1/jeeb/wallet`. `MockGatewayClient` rewrites the
/// prefix to `/wallet-service/v1/jeeb/wallet` on `:4010` (a `/v1/jeeb/wallet`
/// rewrite-map key must be added by the W2.5 mock/foundation hand-off — it is a
/// sibling of the existing `/v1/jeeb/earnings` key). DO NOT hardcode the
/// service prefix here (40_GUARDRAILS_ARCH §4 / DO-NOT).
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

  // Defensive parse (40_GUARDRAILS_ARCH §4): null-coalesce every field, accept
  // snake_case + camelCase, tolerate an unknown affordability string.
  WalletBalance _parse(Map<String, dynamic> json) {
    return WalletBalance(
      availableBalance:
          _num(json['availableBalance'] ?? json['available_balance']),
      affordabilityState: _affordability(
        json['affordabilityState'] ?? json['affordability_state'],
      ),
      reservedNow: _num(json['reservedNow'] ?? json['reserved_now']),
      giftCredit: _num(json['giftCredit'] ?? json['gift_credit']),
      // Currency is gateway-verbatim (40_GUARDRAILS_ARCH §5). The client-side
      // fallback is `USD` — the settlement currency ($100 goods → $10 fee) and
      // the same default every other wallet/order/offer data source uses. A
      // prior `'SAR'` fallback here leaked "SAR" onto the offer composer's
      // fee/net/reserve lines (it reads `_wallet?.currency`) while the money is
      // USD (JEBV4 currency-consistency fix). TODO(backender): the wallet
      // balance response should ALWAYS include an explicit `currency` so the
      // client never has to default at all.
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
