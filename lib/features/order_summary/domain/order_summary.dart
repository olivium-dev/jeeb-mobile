import 'package:equatable/equatable.dart';

class OrderSummary extends Equatable {
  const OrderSummary({
    required this.deliveryId,
    required this.requestId,
    required this.conversationId,
    required this.price,
    required this.currency,
    required this.jeeberName,
    required this.tier,
    this.jeeberRating,
    this.jeeberRatingCount,
    this.etaMinutes,
    this.itemSummary,
    this.jeeberAvatarUrl,
  });

  final String deliveryId;

  final String requestId;

  final String conversationId;

  final double price;

  final String currency;

  final String jeeberName;

  final String tier;

  final double? jeeberRating;

  final int? jeeberRatingCount;

  final int? etaMinutes;

  final String? itemSummary;

  final String? jeeberAvatarUrl;

  bool get hasRating => jeeberRating != null && (jeeberRatingCount ?? 0) > 0;

  @override
  List<Object?> get props => [
        deliveryId,
        requestId,
        conversationId,
        price,
        currency,
        jeeberName,
        tier,
        jeeberRating,
        jeeberRatingCount,
        etaMinutes,
        itemSummary,
        jeeberAvatarUrl,
      ];
}
