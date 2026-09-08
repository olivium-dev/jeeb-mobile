import 'package:equatable/equatable.dart';

class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.offers = true,
    this.chat = true,
    this.status = true,
    this.ratingReminders = true,
  });

  final bool offers;
  final bool chat;
  final bool status;
  final bool ratingReminders;

  NotificationPreferences copyWith({
    bool? offers,
    bool? chat,
    bool? status,
    bool? ratingReminders,
  }) {
    return NotificationPreferences(
      offers: offers ?? this.offers,
      chat: chat ?? this.chat,
      status: status ?? this.status,
      ratingReminders: ratingReminders ?? this.ratingReminders,
    );
  }

  @override
  List<Object?> get props => [offers, chat, status, ratingReminders];
}

/// F11: the device-local home for the four settings-vocabulary toggles. The
/// account-wide preferences live behind `NotificationPrefsRepository`.
abstract class SettingsNotificationPrefsStore {
  Future<NotificationPreferences?> read();

  Future<void> write(NotificationPreferences preferences);
}
