import 'package:equatable/equatable.dart';

class OrderSummary extends Equatable {
  const OrderSummary({
    required this.deliveryId,
    required this.requestId,
    required this.conversationId,
    required this.price,
    required this.currency,
    this.partialSections = const <OrderSummarySection>{},
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

  /// Null when the wire carried none: the chat CTA is hidden rather than
  /// routed at a guessed id.
  final String? conversationId;

  final double? price;

  final String? currency;

  /// Sections whose secondary read failed, so the screen can say "partial"
  /// instead of rendering an absent field as an empty one.
  final Set<OrderSummarySection> partialSections;

  final String jeeberName;

  final String tier;

  final double? jeeberRating;

  final int? jeeberRatingCount;

  final int? etaMinutes;

  final String? itemSummary;

  final String? jeeberAvatarUrl;

  bool get hasRating => jeeberRating != null && (jeeberRatingCount ?? 0) > 0;

  bool get hasPrice => price != null && currency != null;

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
        partialSections,
      ];
}

/// The three reads `OrderSummary` is stitched from.
enum OrderSummarySection { request, offers, jeeber }
