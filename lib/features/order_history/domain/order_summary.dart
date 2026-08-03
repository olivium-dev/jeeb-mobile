import 'package:equatable/equatable.dart';

enum OrderHistoryTab { active, completed, cancelled }

enum OrderRequestStatus {
  pending,
  matched,
  pickedUp,
  enRoute,
  delivered,
  cancelled,
  disputed,
  unknown;

  static OrderRequestStatus parse(String? raw) {
    final normalized = (raw ?? '').trim().toLowerCase().replaceAll('_', '');
    switch (normalized) {
      case 'pending':
      case 'searching':
      case 'offered':
        return OrderRequestStatus.pending;
      case 'accepted':
      case 'assigned':
      case 'matched':
      case 'ordered':
        return OrderRequestStatus.matched;
      case 'picked':
      case 'pickedup':
        return OrderRequestStatus.pickedUp;
      case 'intransit':
      case 'enroute':
      case 'atdoor':
      case 'headingoff':
        return OrderRequestStatus.enRoute;
      case 'done':
      case 'delivered':
      case 'completed':
      case 'rated':
        return OrderRequestStatus.delivered;
      case 'cancelled':
      case 'canceled':
      case 'expired':
        return OrderRequestStatus.cancelled;
      case 'disputed':
        return OrderRequestStatus.disputed;
      default:
        return OrderRequestStatus.unknown;
    }
  }

  OrderHistoryTab get tab {
    switch (this) {
      case OrderRequestStatus.delivered:
        return OrderHistoryTab.completed;
      case OrderRequestStatus.cancelled:
      case OrderRequestStatus.disputed:
        return OrderHistoryTab.cancelled;
      case OrderRequestStatus.pending:
      case OrderRequestStatus.matched:
      case OrderRequestStatus.pickedUp:
      case OrderRequestStatus.enRoute:
      case OrderRequestStatus.unknown:
        return OrderHistoryTab.active;
    }
  }

  bool get isOnHold => this == OrderRequestStatus.pending;
}

enum OrderTier {
  flash,
  express,
  standard,
  onTheWay,
  eco;

  static OrderTier parse(String? raw) {
    switch (raw) {
      case 'flash':
        return OrderTier.flash;
      case 'express':
        return OrderTier.express;
      case 'standard':
        return OrderTier.standard;
      case 'on_the_way':
      case 'onTheWay':
        return OrderTier.onTheWay;
      case 'eco':
        return OrderTier.eco;
      default:
        return OrderTier.standard;
    }
  }
}

class OrderSummary extends Equatable {
  const OrderSummary({
    required this.id,
    required this.createdAt,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.status,
    required this.tier,
    required this.amountMinor,
    required this.currency,
  });

  final String id;

  final DateTime createdAt;

  final String pickupAddress;
  final String dropoffAddress;
  final OrderRequestStatus status;
  final OrderTier tier;

  final int? amountMinor;

  bool get hasKnownAmount => (amountMinor ?? 0) > 0;

  final String currency;

  @override
  List<Object?> get props => [
    id,
    createdAt,
    pickupAddress,
    dropoffAddress,
    status,
    tier,
    amountMinor,
    currency,
  ];
}

class OrderPage extends Equatable {
  const OrderPage({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  final List<OrderSummary> items;
  final int page;
  final bool hasMore;

  @override
  List<Object?> get props => [items, page, hasMore];
}

class OrderDateRange extends Equatable {
  const OrderDateRange({this.from, this.to});

  factory OrderDateRange.forInclusiveDays({DateTime? from, DateTime? to}) {
    return OrderDateRange(
      from: from == null ? null : _localMidnight(from),
      to: to == null ? null : _nextLocalMidnight(to),
    );
  }

  final DateTime? from;

  final DateTime? to;

  DateTime? get inclusiveToDay {
    final exclusiveEnd = to;
    if (exclusiveEnd == null) return null;
    return DateTime(
      exclusiveEnd.year,
      exclusiveEnd.month,
      exclusiveEnd.day - 1,
    );
  }

  bool get isEmpty => from == null && to == null;

  static DateTime _localMidnight(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _nextLocalMidnight(DateTime value) =>
      DateTime(value.year, value.month, value.day + 1);

  @override
  List<Object?> get props => [from, to];
}
