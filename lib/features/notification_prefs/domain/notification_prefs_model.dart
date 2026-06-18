import 'package:equatable/equatable.dart';

/// Per-topic notification preference — one per semantic topic the gateway
/// exposes. Each topic maps to a single boolean (enabled/disabled).
///
/// Matches the gateway `NotificationPreferencesResponse.preferences` shape:
///   { "offers": bool, "chat": bool, "statusChanges": bool, "ratingReminders": bool }
class NotificationTopicPrefs extends Equatable {
  const NotificationTopicPrefs({
    this.offers = true,
    this.chat = true,
    this.statusChanges = true,
    this.ratingReminders = true,
  });

  factory NotificationTopicPrefs.fromJson(Map<String, dynamic> json) {
    return NotificationTopicPrefs(
      offers: (json['offers'] as bool?) ?? true,
      chat: (json['chat'] as bool?) ?? true,
      statusChanges: (json['statusChanges'] as bool?) ?? true,
      ratingReminders: (json['ratingReminders'] as bool?) ?? true,
    );
  }

  final bool offers;
  final bool chat;
  final bool statusChanges;
  final bool ratingReminders;

  NotificationTopicPrefs copyWith({
    bool? offers,
    bool? chat,
    bool? statusChanges,
    bool? ratingReminders,
  }) {
    return NotificationTopicPrefs(
      offers: offers ?? this.offers,
      chat: chat ?? this.chat,
      statusChanges: statusChanges ?? this.statusChanges,
      ratingReminders: ratingReminders ?? this.ratingReminders,
    );
  }

  Map<String, dynamic> toJson() => {
    'offers': offers,
    'chat': chat,
    'statusChanges': statusChanges,
    'ratingReminders': ratingReminders,
  };

  @override
  List<Object?> get props => [offers, chat, statusChanges, ratingReminders];
}

/// Full preferences snapshot returned by GET/PATCH `/users/me/notification-preferences`.
///
/// `alwaysOn` lists topics that cannot be disabled (e.g. "otp", "system_critical").
/// The gateway returns 400 if the client attempts to disable one of these.
class NotificationPrefs extends Equatable {
  const NotificationPrefs({
    this.preferences = const NotificationTopicPrefs(),
    this.alwaysOn = const [],
  });

  final NotificationTopicPrefs preferences;

  /// Topics that are always enabled and cannot be toggled off.
  final List<String> alwaysOn;

  bool get isOtpAlwaysOn => alwaysOn.contains('otp');
  bool get isSystemCriticalAlwaysOn => alwaysOn.contains('system_critical');

  NotificationPrefs copyWith({
    NotificationTopicPrefs? preferences,
    List<String>? alwaysOn,
  }) {
    return NotificationPrefs(
      preferences: preferences ?? this.preferences,
      alwaysOn: alwaysOn ?? this.alwaysOn,
    );
  }

  @override
  List<Object?> get props => [preferences, alwaysOn];
}
