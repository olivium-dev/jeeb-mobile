import 'package:equatable/equatable.dart';

enum ClientRequestStatus {
  searching,

  offersReceived,

  accepted,

  atPickup,

  enRoute,

  delivered,

  cancelled,
}

enum ClientRequestTier { flash, express, standard, unknown;

  static ClientRequestTier parse(String? raw) {
    switch (raw) {
      case 'flash':
        return ClientRequestTier.flash;
      case 'express':
        return ClientRequestTier.express;
      case 'standard':
        return ClientRequestTier.standard;
      default:
        return ClientRequestTier.unknown;
    }
  }
}

class ClientHomeRequest extends Equatable {
  const ClientHomeRequest({
    required this.id,
    required this.title,
    required this.status,
    required this.destinationLabel,
    this.itemsSummary,
    this.etaMinutes,
    this.jeeberName,
    this.tier = ClientRequestTier.unknown,
    this.progressStep = 0,
    this.offerCount = 0,
    this.offerAvatarUrls = const <String>[],
    this.conversationId,
    this.displayId,
    this.ttlSeconds,
    this.deliveryId,
    this.chatCorrelationId,
    this.createdAt,
    this.hasNewOffers = false,
  });

  final String id;

  final String? deliveryId;

  String get trackingId =>
      (deliveryId != null && deliveryId!.isNotEmpty) ? deliveryId! : id;

  final String? chatCorrelationId;

  String get chatThreadId =>
      (chatCorrelationId != null && chatCorrelationId!.isNotEmpty)
          ? chatCorrelationId!
          : id;

  final String? displayId;

  final String title;

  final String destinationLabel;

  final String? itemsSummary;

  String get summaryLine {
    final items = itemsSummary;
    if (items != null && items.isNotEmpty) {
      final header = displayId ?? title;
      if (items != header) return items;
    }
    return destinationLabel;
  }

  final ClientRequestStatus status;

  final ClientRequestTier tier;

  final int progressStep;

  final int? etaMinutes;

  final String? jeeberName;

  final int? ttlSeconds;

  final int offerCount;

  final List<String> offerAvatarUrls;

  final String? conversationId;

  final DateTime? createdAt;

  final bool hasNewOffers;

  ClientHomeRequest copyWith({
    String? id,
    String? title,
    ClientRequestStatus? status,
    String? destinationLabel,
    Object? itemsSummary = _sentinel,
    Object? etaMinutes = _sentinel,
    Object? jeeberName = _sentinel,
    ClientRequestTier? tier,
    int? progressStep,
    int? offerCount,
    List<String>? offerAvatarUrls,
    Object? conversationId = _sentinel,
    Object? displayId = _sentinel,
    Object? ttlSeconds = _sentinel,
    Object? deliveryId = _sentinel,
    Object? chatCorrelationId = _sentinel,
    Object? createdAt = _sentinel,
    bool? hasNewOffers,
  }) {
    return ClientHomeRequest(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      destinationLabel: destinationLabel ?? this.destinationLabel,
      itemsSummary: identical(itemsSummary, _sentinel)
          ? this.itemsSummary
          : itemsSummary as String?,
      etaMinutes: identical(etaMinutes, _sentinel)
          ? this.etaMinutes
          : etaMinutes as int?,
      jeeberName: identical(jeeberName, _sentinel)
          ? this.jeeberName
          : jeeberName as String?,
      tier: tier ?? this.tier,
      progressStep: progressStep ?? this.progressStep,
      offerCount: offerCount ?? this.offerCount,
      offerAvatarUrls: offerAvatarUrls ?? this.offerAvatarUrls,
      conversationId: identical(conversationId, _sentinel)
          ? this.conversationId
          : conversationId as String?,
      displayId: identical(displayId, _sentinel)
          ? this.displayId
          : displayId as String?,
      ttlSeconds: identical(ttlSeconds, _sentinel)
          ? this.ttlSeconds
          : ttlSeconds as int?,
      deliveryId: identical(deliveryId, _sentinel)
          ? this.deliveryId
          : deliveryId as String?,
      chatCorrelationId: identical(chatCorrelationId, _sentinel)
          ? this.chatCorrelationId
          : chatCorrelationId as String?,
      createdAt: identical(createdAt, _sentinel)
          ? this.createdAt
          : createdAt as DateTime?,
      hasNewOffers: hasNewOffers ?? this.hasNewOffers,
    );
  }

  @override
  List<Object?> get props => [
        id,
        displayId,
        title,
        destinationLabel,
        itemsSummary,
        status,
        tier,
        progressStep,
        etaMinutes,
        jeeberName,
        offerCount,
        offerAvatarUrls,
        conversationId,
        ttlSeconds,
        deliveryId,
        chatCorrelationId,
        createdAt,
        hasNewOffers,
      ];
}

const Object _sentinel = Object();
