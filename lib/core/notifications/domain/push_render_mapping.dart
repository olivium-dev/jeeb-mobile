import 'notification_deep_link.dart';
import 'notification_message.dart';

class PushRenderFields {
  const PushRenderFields({
    required this.category,
    required this.title,
    required this.body,
    required this.dedupTag,
    required this.deepLinkPath,
  });

  factory PushRenderFields.fromData(
    Map<String, String> data, {
    String? messageId,
    String? notificationTitle,
    String? notificationBody,
  }) {
    final message = NotificationMessage(
      id: messageId ?? data['messageId'] ?? '',
      category: NotificationCategory.fromData(data),
      title: notificationTitle ?? data['title'] ?? '',
      body: notificationBody ?? data['body'] ?? '',
      receivedAt: DateTime.fromMillisecondsSinceEpoch(0),
      data: data,
    );
    return PushRenderFields.fromMessage(message, messageId: messageId);
  }

  factory PushRenderFields.fromMessage(
    NotificationMessage message, {
    String? messageId,
  }) {
    final tag = messageId ?? message.data['messageId'] ?? message.id;
    return PushRenderFields(
      category: message.category,
      title: message.title.isEmpty ? genericTitle : message.title,
      body: message.body,
      dedupTag: tag.isEmpty ? null : tag,
      deepLinkPath: deepLinkForMessage(message),
    );
  }

  final NotificationCategory category;

  final String title;

  final String body;

  final String? dedupTag;

  /// actionable target (renders the heads-up, no-ops on tap — never crashes).
  final String? deepLinkPath;

  static const String genericTitle = 'New notification';
}
