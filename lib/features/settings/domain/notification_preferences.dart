import 'package:equatable/equatable.dart';

/// User-facing notification toggles backing the settings list (T-mobile-031).
///
/// OTP/security notifications are intentionally not represented here — they
/// are always-on and surfaced as an informational row in the UI.
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
