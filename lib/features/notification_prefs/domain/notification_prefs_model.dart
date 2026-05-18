import 'package:equatable/equatable.dart';

class NotificationPrefs extends Equatable {
  const NotificationPrefs({
    this.pushEnabled = true,
    this.smsEnabled = true,
    this.emailEnabled = true,
    this.deliveryUpdates = true,
    this.offers = true,
    this.promotions = false,
  });

  final bool pushEnabled;
  final bool smsEnabled;
  final bool emailEnabled;
  final bool deliveryUpdates;
  final bool offers;
  final bool promotions;

  NotificationPrefs copyWith({
    bool? pushEnabled,
    bool? smsEnabled,
    bool? emailEnabled,
    bool? deliveryUpdates,
    bool? offers,
    bool? promotions,
  }) {
    return NotificationPrefs(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      deliveryUpdates: deliveryUpdates ?? this.deliveryUpdates,
      offers: offers ?? this.offers,
      promotions: promotions ?? this.promotions,
    );
  }

  @override
  List<Object?> get props => [
        pushEnabled,
        smsEnabled,
        emailEnabled,
        deliveryUpdates,
        offers,
        promotions,
      ];
}
