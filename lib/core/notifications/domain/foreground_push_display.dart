// PURE Dart. No Flutter / Firebase imports (40_GUARDRAILS_ARCH §1 layer rules)
// — the transport (`data/firebase_messaging_transport.dart`) and the banner
// cubit (`application/push_notification_handler.dart`) both call into here so
// the "should this interrupt the user?" decision exists in exactly ONE place
// and is unit-testable on the VM without a platform channel.
library;

import 'notification_message.dart';

/// Wire key for the transport-level silent switch, as implemented on the push
/// microservice (`push-notification/app/endpoints/sent_payload.py`).
const String kSilentPushKey = 'silent';

/// Values of [kSilentPushKey] that mean "NOT silent".
///
/// This is a deliberate byte-for-byte mirror of `_SILENT_FALSE_STRINGS` in
/// `push-notification/app/endpoints/sent_payload.py`. The two MUST agree: the
/// service decides whether to attach the FCM `notification` block, this file
/// decides whether the app renders a local heads-up, and a disagreement
/// produces either a double banner or a swallowed one.
///
/// Note the service ships `data = {k: str(v) for k, v in payload.items()}`, so
/// a Python `True` arrives on the wire as the string `"True"` — hence the
/// case-insensitive compare rather than an `== 'true'`.
const Set<String> kSilentFalseStrings = <String>{
  '',
  'false',
  '0',
  'no',
  'off',
  'null',
  'none',
};

/// Whether this payload asked for a silent (data-only / refresh-only) delivery.
///
/// Fails CLOSED on absence: no `silent` key ⇒ NOT silent ⇒ the push renders.
/// Every push sent before the silent switch existed lands here, and none of
/// them may go quiet.
bool isSilentPush(Map<String, String> data) {
  final raw = data[kSilentPushKey];
  if (raw == null) return false;
  return !kSilentFalseStrings.contains(raw.trim().toLowerCase());
}

/// Every id in [data] that could identify the chat thread this push belongs to.
///
/// Same key set and same precedence as the chat branch of
/// [deepLinkForMessage] (`notification_deep_link.dart:62-67`) — kept identical
/// on purpose: if the router can resolve a thread from a key, the suppression
/// must be able to recognise that same thread, or a push would route to a
/// screen the suppression thought was closed.
List<String> chatThreadIdsFromPush(Map<String, String> data) {
  const keys = <String>[
    'requestId',
    'request_id',
    'chat_id',
    'conversation_id',
    'conversationId',
  ];
  final out = <String>[];
  for (final key in keys) {
    final value = data[key]?.trim();
    if (value != null && value.isNotEmpty) out.add(value);
  }
  return out;
}

/// Whether an inbound FOREGROUND push should interrupt the user — i.e. render
/// an OS heads-up/shade entry (Android local notification) and an in-app
/// banner.
///
/// Exactly two things suppress, and NOTHING else:
///
/// 1. **Silent / refresh-only** ([isSilentPush]). Owner: *"you can evaluate
///    when to use notificationcenter+visible notification or when to use
///    silent notification"*. A silent push exists to make a surface re-pull
///    without a poll; buzzing the shade for it would be strictly worse than
///    the polling it replaces.
///
/// 2. **A chat push for the thread already on screen** ([openChatThreadIds],
///    supplied by `ActiveChatThread`). The message is already being rendered
///    in the conversation the user is reading.
///
/// EVERYTHING else returns `true`. In particular a chat push for a thread the
/// user is NOT viewing returns `true` even in the foreground — the owner asked
/// for exactly that: *"in case the user is not on the right chat session, user
/// should see the notification whether the app is in forground or background
/// or even closed"*. That is why the predicate is not simply `!silent`.
bool shouldShowForegroundPush({
  required NotificationCategory category,
  required Map<String, String> data,
  required Set<String> openChatThreadIds,
}) {
  if (isSilentPush(data)) return false;
  if (category != NotificationCategory.chat) return true;
  if (openChatThreadIds.isEmpty) return true;
  for (final id in chatThreadIdsFromPush(data)) {
    if (openChatThreadIds.contains(id)) return false;
  }
  return true;
}
