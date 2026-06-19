import 'package:dio/dio.dart';

import '../domain/wallet_ledger_repository.dart' show WalletLedgerType;
import '../domain/wallet_transaction_repository.dart';

/// Dio-backed [WalletTransactionRepository] (JM-056) — W3m
/// `GET /v1/jeeb/wallet/ledger/:id` (LIVE on :4010, 42_GUARDRAILS_MOCK "FINAL
/// WAVE (W3+W4) mock closeout"). The resolved jeeber comes from the bearer token
/// (no `?jeeberId=` needed — `resolveJeeberId` server-side), same precedence as
/// W1m/W2m.
///
/// Gateway path `/v1/jeeb/wallet/ledger/:id` rewrites under the same
/// `/v1/jeeb/wallet` rewrite-map key as the W2m ledger list
/// (`mock_gateway_client.dart`).
///
/// NOT the DI default yet: `injection_container.dart` still binds the
/// [StubWalletTransactionRepository] INTEGRATOR-STUB (CTO-D2). This impl is the
/// swap target — repoint the DI registration here (REQUESTED in
/// 50_ROUTE_REQUESTS.md, "JM-056 DI SWAP") without touching the screen.
///
/// Wire (42_GUARDRAILS_MOCK §4):
///   { id, type, category, title, amount, sign, ref, ts, currency,
///     feeRate?, pinnedPrice?, offerId?, orderId?, disputeId? }
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
      // The mock sends both `type` and the stable machine key `category`;
      // tolerate either (and snake/camel for fee_won).
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
