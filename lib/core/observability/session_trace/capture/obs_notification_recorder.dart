import '../../../notifications/domain/notification_message.dart';
import '../../../diagnostics/diag_redaction.dart';
import '../observability.dart';
import '../secret_redactor.dart';

abstract final class ObsNotificationRecorder {
  static void recordReceived(
    NotificationMessage message, {
    required String mode,
    String channel = 'fcm',
  }) {
    _emit(message, mode: mode, channel: channel, deepLink: null);
  }

  static void recordShown(
    NotificationMessage message, {
    String channel = 'local',
  }) {
    _emit(message, mode: 'foreground', channel: channel, deepLink: null);
  }

  static void recordOpened(
    NotificationMessage message, {
    String? deepLink,
    String channel = 'fcm',
  }) {
    _emit(message, mode: 'opened', channel: channel, deepLink: deepLink);
  }

  static void _emit(
    NotificationMessage message, {
    required String mode,
    required String channel,
    required String? deepLink,
  }) {
    if (!Observability.instance.recording) return;
    Observability.instance.recordNotification(
      channel: channel,
      mode: mode,
      messageId: message.id,
      category: message.category.name,
      title: SecretRedactor.redactLabel(message.title),
      body: SecretRedactor.redactLabel(message.body),
      deepLink: deepLink == null
          ? null
          : SecretRedactor.redactNetworkPath(DiagRedaction.scrubPath(deepLink)),
      data: _redactData(message.data),
    );
  }

  static Map<String, Object?> _redactData(Map<String, String> data) {
    final redacted = SecretRedactor.redactBody(data);
    return redacted is Map<String, Object?>
        ? redacted
        : const <String, Object?>{};
  }
}
