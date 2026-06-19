import 'package:equatable/equatable.dart';

/// The four toggleable notification categories (JM-058, D64).
///
/// `transactional` is intentionally NOT in this enum: it is the locked, always-on
/// class (order receipts, money movements you must see) — the gateway never lets
/// the client disable it, so it is rendered as a disabled row, not a toggle.
enum NotificationCategory {
  /// New offers on your requests (and offer-accepted nudges).
  offers,

  /// Pickup / hand-off / delivery status changes (D84 `status`).
  orderStatus,

  /// Wallet movements you opt into seeing (low balance, fee won, top-up, gift).
  wallet,

  /// Promotions, news, seasonal campaigns.
  marketing,
}

/// The wire key each category serialises to inside the gateway `topics` map.
///
/// The mock `GET/PUT /v1/notifications/preferences` echoes an opaque
/// `topics: { <key>: bool }` map (`notification-service.ts`), so the app owns
/// these keys. Kept snake_case to match the rest of the notification contract
/// (D84 dispatch classes are snake_case).
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
      // Tolerate the legacy camelCase the older screen used.
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

/// Per-category enabled flags. Defaults are opt-in for the three operational
/// categories and opt-out for marketing (least-surprising; CTO-D R-F — D64 does
/// not fix a default, marketing-off is the conservative, consent-friendly choice).
class NotificationCategoryPrefs extends Equatable {
  const NotificationCategoryPrefs({
    this.offers = true,
    this.orderStatus = true,
    this.wallet = true,
    this.marketing = false,
  });

  /// Parses the gateway `topics` map; absent keys fall back to the constructor
  /// defaults so a partial / empty `topics: {}` (the mock's seed) degrades
  /// gracefully rather than crashing.
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

  /// Serialises to the gateway `topics` map (the wire keys, not enum names).
  Map<String, bool> toTopicsJson() => {
        NotificationCategory.offers.wireKey: offers,
        NotificationCategory.orderStatus.wireKey: orderStatus,
        NotificationCategory.wallet.wireKey: wallet,
        NotificationCategory.marketing.wireKey: marketing,
      };

  @override
  List<Object?> get props => [offers, orderStatus, wallet, marketing];
}

/// Full preferences snapshot from `GET/PUT /v1/notifications/preferences`.
///
/// `pushEnabled` reflects the gateway `push` channel flag; the screen surfaces a
/// push-only note (R2) so the user understands every category here is a *push*
/// channel preference (SMS/email are not surfaced — push is the only channel the
/// app controls). `transactionalLocked` is always true: the transactional class
/// (D64) cannot be disabled and renders as a locked row.
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
