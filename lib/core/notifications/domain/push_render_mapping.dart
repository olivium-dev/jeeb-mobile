import 'notification_deep_link.dart';
import 'notification_message.dart';

/// The exact set of fields used to RENDER a local heads-up notification from
/// an inbound FCM message.
///
/// This is the SINGLE source of truth shared by BOTH receive paths in
/// [FirebaseMessagingTransport] — the foreground listener (`onMessage`) and
/// the background/data-only isolate handler
/// (`firebaseMessagingBackgroundHandler`). Routing both through one pure
/// mapper is what makes foreground ≡ background for the frozen Sprint-3 chat
/// data-message (Sprint-3 Contract 9b/9c): same title, same body, same dedup
/// tag, same deep-link — so the two code paths can never silently drift.
///
/// Pure Dart (no `firebase_messaging`, no `flutter_local_notifications`,
/// no `BuildContext`) so it is exhaustively unit-testable on the VM without a
/// platform channel — which is the gap that let the receive side go
/// un-proven ("phantom") in earlier sprints.
class PushRenderFields {
  const PushRenderFields({
    required this.category,
    required this.title,
    required this.body,
    required this.dedupTag,
    required this.deepLinkPath,
  });

  /// Builds the render fields from a flattened FCM `data` map (Contract 9b
  /// byte-shape) plus the optional FCM `notification` block.
  ///
  /// For the frozen chat push the block is null (data-only, Contract 9a), so
  /// `title`/`body` come from `data['title']`/`data['body']`. When a server
  /// DOES send a notification block (e.g. a legacy/admin push) it wins, so
  /// this mapper renders correctly either way.
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

  /// Builds the render fields from an already-parsed [NotificationMessage]
  /// (the foreground path already has one via `_toDomain`). Applies the
  /// display-title fallback so a malformed push with no title still renders a
  /// visible heads-up instead of a blank banner.
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

  /// Routing discriminator (`type`/`category`) resolved from the payload.
  final NotificationCategory category;

  /// Heads-up title. Never empty — falls back to [genericTitle].
  final String title;

  /// Heads-up body. May be empty (Contract 9b allows an empty preview).
  final String body;

  /// Stable dedup id/tag (`messageId`). Two pushes with the same tag collapse
  /// to one banner. `null` only when the payload carried no usable id, in
  /// which case the caller synthesises a per-delivery tag.
  final String? dedupTag;

  /// go_router destination for a tap, or `null` when the payload has no
  /// actionable target (renders the heads-up, no-ops on tap — never crashes).
  final String? deepLinkPath;

  /// Generic display title used when the payload omits a title, matching the
  /// historical background-isolate fallback so fg ≡ bg.
  static const String genericTitle = 'New notification';
}
