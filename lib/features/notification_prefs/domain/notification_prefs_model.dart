import 'package:equatable/equatable.dart';

enum NotificationCategory {
  offers,

  orderStatus,

  wallet,

  marketing,
}

extension NotificationCategoryWire on NotificationCategory {
  String get wireKey {
    switch (this) {
      case NotificationCategory.offers:
        return 'offers';
      case NotificationCategory.orderStatus:
        return 'order_status';
      case NotificationCategory.wallet:
        return 'wallet';
      case NotificationCategory.marketing:
        return 'marketing';
    }
  }

  static NotificationCategory? fromWire(String key) {
    switch (key) {
      case 'offers':
        return NotificationCategory.offers;
      case 'order_status':
      case 'orderStatus':
      case 'statusChanges':
        return NotificationCategory.orderStatus;
      case 'wallet':
        return NotificationCategory.wallet;
      case 'marketing':
        return NotificationCategory.marketing;
      default:
        return null;
    }
  }
}

class NotificationCategoryPrefs extends Equatable {
  const NotificationCategoryPrefs({
    this.offers = true,
    this.orderStatus = true,
    this.wallet = true,
    this.marketing = false,
  });

  factory NotificationCategoryPrefs.fromTopicsJson(Map<String, dynamic> json) {
    bool read(NotificationCategory c, bool fallback) {
      final v = json[c.wireKey];
      return v is bool ? v : fallback;
    }

    return NotificationCategoryPrefs(
      offers: read(NotificationCategory.offers, true),
      orderStatus: read(NotificationCategory.orderStatus, true),
      wallet: read(NotificationCategory.wallet, true),
      marketing: read(NotificationCategory.marketing, false),
    );
  }

  final bool offers;
  final bool orderStatus;
  final bool wallet;
  final bool marketing;

  bool valueOf(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.offers:
        return offers;
      case NotificationCategory.orderStatus:
        return orderStatus;
      case NotificationCategory.wallet:
        return wallet;
      case NotificationCategory.marketing:
        return marketing;
    }
  }

  NotificationCategoryPrefs withValue(
    NotificationCategory category,
    bool value,
  ) {
    switch (category) {
      case NotificationCategory.offers:
        return copyWith(offers: value);
      case NotificationCategory.orderStatus:
        return copyWith(orderStatus: value);
      case NotificationCategory.wallet:
        return copyWith(wallet: value);
      case NotificationCategory.marketing:
        return copyWith(marketing: value);
    }
  }

  NotificationCategoryPrefs copyWith({
    bool? offers,
    bool? orderStatus,
    bool? wallet,
    bool? marketing,
  }) {
    return NotificationCategoryPrefs(
      offers: offers ?? this.offers,
      orderStatus: orderStatus ?? this.orderStatus,
      wallet: wallet ?? this.wallet,
      marketing: marketing ?? this.marketing,
    );
  }

  Map<String, bool> toTopicsJson() => {
        NotificationCategory.offers.wireKey: offers,
        NotificationCategory.orderStatus.wireKey: orderStatus,
        NotificationCategory.wallet.wireKey: wallet,
        NotificationCategory.marketing.wireKey: marketing,
      };

  @override
  List<Object?> get props => [offers, orderStatus, wallet, marketing];
}

class NotificationPrefs extends Equatable {
  const NotificationPrefs({
    this.categories = const NotificationCategoryPrefs(),
    this.pushEnabled = true,
    this.transactionalLocked = true,
  });

  final NotificationCategoryPrefs categories;
  final bool pushEnabled;
  final bool transactionalLocked;

  NotificationPrefs copyWith({
    NotificationCategoryPrefs? categories,
    bool? pushEnabled,
    bool? transactionalLocked,
  }) {
    return NotificationPrefs(
      categories: categories ?? this.categories,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      transactionalLocked: transactionalLocked ?? this.transactionalLocked,
    );
  }

  @override
  List<Object?> get props => [categories, pushEnabled, transactionalLocked];
}
