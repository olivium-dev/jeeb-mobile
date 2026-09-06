import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/auth_token_store.dart';
import '../domain/submitted_offer.dart';
import '../domain/submitted_offers_repository.dart';

class DioSubmittedOffersRepository implements SubmittedOffersRepository {
  const DioSubmittedOffersRepository({
    required Dio dio,
    String? jeeberId,
    AuthTokenStore? tokenStore,
  }) : _dio = dio,
       _jeeberId = jeeberId,
       _tokenStore = tokenStore;

  final Dio _dio;
  final String? _jeeberId;
  final AuthTokenStore? _tokenStore;

  static const String _path = '/v1/offers';

  @override
  Future<List<SubmittedOffer>> listSubmitted() async {
    try {

      final jeeberId = _jeeberId ?? await _tokenStore?.userId;
      final response = await _dio.get<Map<String, dynamic>>(
        _path,
        queryParameters: {
          if (jeeberId != null && jeeberId.isNotEmpty) 'jeeberId': jeeberId,
        },
      );
      return _parse(response.data ?? const {});
    } on DioException catch (e) {
      throw AppFailure.of(e);
    }
  }

  @override
  Future<bool> withdraw(String offerId) async {

    try {
      await _dio.delete<void>('$_path/$offerId');
      return true;
    } on DioException catch (e) {
      // Already gone == withdrawn; anything else is a real failure.
      if (e.response?.statusCode == 404) return true;
      throw AppFailure.of(e);
    }
  }

  List<SubmittedOffer> _parse(Map<String, dynamic> data) {

    final items = data['items'] as List? ?? const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(_parseOffer)
        .whereType<SubmittedOffer>()
        .toList(growable: false);
  }

  SubmittedOffer? _parseOffer(Map<String, dynamic> json) {

    final id = (json['id'] as String?) ?? (json['offerId'] as String?);
    if (id == null) return null;
    final requestId =
        (json['requestId'] as String?) ?? (json['request_id'] as String?) ?? '';

    final price = _amount(json['price']) ??
        _amount(json['amount']) ??
        _amount(json['fee']);
    // An unparseable price would render as a real $0.00 offer — drop the row.
    if (price == null) return null;
    final currency = _currency(json['price']) ?? _currency(json['amount']);
    return SubmittedOffer(
      id: id,
      requestId: requestId,
      price: price,
      currency: currency ?? 'USD',
      currencyKnown: currency != null,
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      note: json['note'] as String?,
      status: OfferStatus.fromWire(json['status'] as String?),
    );
  }

  double? _amount(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is Map && raw['value'] is num) {
      return (raw['value'] as num).toDouble();
    }
    return null;
  }

  String? _currency(Object? raw) {
    if (raw is Map && raw['currency'] is String) {
      return raw['currency'] as String;
    }
    return null;
  }
}
