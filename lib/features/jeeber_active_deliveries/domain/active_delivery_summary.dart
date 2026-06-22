import 'package:equatable/equatable.dart';

import '../../active_delivery_jeeber/domain/jeeber_delivery_status.dart';

/// A single row in the jeeber's "active deliveries" list (the accepted/assigned
/// jobs the jeeber is driving). Sourced from `GET /v1/deliveries?role=jeeber`
/// (the gateway `JeebOrdersListController.ListDeliveries`, paged envelope).
///
/// REAL-FLOW BLOCKER (iter6): once a client accepts a jeeber's offer the request
/// flips to `accepted`, a delivery is minted with `jeeberId` assigned and a
/// conversation is created (`correlation_key == requestId`). Until this list
/// existed the jeeber had NO real-UI surface to reach that delivery — the
/// pending feed dropped it and the submitted-offers list filtered it out. This
/// summary carries exactly what the row needs to (a) open the order chat and
/// (b) drive the delivery: the delivery/request [id], the server-minted
/// [conversationId] (when present), the [status], and a human label.
class ActiveDeliverySummary extends Equatable {
  const ActiveDeliverySummary({
    required this.id,
    required this.status,
    this.conversationId,
    this.title,
    this.dropoffAddress,
    this.pickupAddress,
  });

  /// Parse one row of the gateway `OrderListItem` shape:
  ///   { id, displayId, status, title, tier, conversationId, jeeberId,
  ///     pickup:{address,...}, dropoff:{address,...}, createdAt }
  /// Tolerant of absent/odd fields (40_GUARDRAILS_ARCH §4 defensive parse).
  factory ActiveDeliverySummary.fromJson(Map<String, dynamic> json) {
    final id =
        json['id'] as String? ?? json['deliveryId'] as String? ?? json['requestId'] as String? ?? '';
    return ActiveDeliverySummary(
      id: id,
      status: JeeberDeliveryStatusX.fromApi(json['status'] as String? ?? 'ordered'),
      conversationId: _normalize(json['conversationId'] as String? ??
          json['conversation_id'] as String?),
      title: _normalize(json['title'] as String?),
      pickupAddress: _address(json['pickup']),
      dropoffAddress: _address(json['dropoff'] ?? json['dropOff']),
    );
  }

  /// Delivery id (== accepted request id in this codebase). Drives the
  /// active-delivery route param and, when no [conversationId] is known, the
  /// `/chat/:id` `by-request` resolution.
  final String id;

  /// Forward-machine status (Ordered→Picked→InTransit→AtDoor→Done) so the row
  /// can show where the delivery is.
  final JeeberDeliveryStatus status;

  /// Server-minted conversation id (the canonical chat key). When present the
  /// row opens the chat directly by conversation id; when absent the chat
  /// screen resolves it from [id] via the `by-request` lookup.
  final String? conversationId;

  /// Human-readable request title (e.g. "Flash delivery request"), shown as the
  /// row's primary line. Falls back to the id when absent.
  final String? title;

  final String? pickupAddress;
  final String? dropoffAddress;

  /// True while the delivery is still in flight (anything before `Done`). Done
  /// deliveries are dropped from the active list by the repository, but this
  /// keeps the surface honest if one slips through.
  bool get isActive => status != JeeberDeliveryStatus.done;

  /// The id the chat surface should open with — prefer the conversation id,
  /// fall back to the delivery/request id (`/chat/:id` resolves either).
  String get chatRouteId =>
      (conversationId != null && conversationId!.isNotEmpty) ? conversationId! : id;

  static String? _normalize(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v;

  static String? _address(Object? raw) {
    if (raw is Map) {
      final addr = raw['address'] as String? ?? raw['label'] as String?;
      return _normalize(addr);
    }
    return null;
  }

  @override
  List<Object?> get props =>
      [id, status, conversationId, title, pickupAddress, dropoffAddress];
}
