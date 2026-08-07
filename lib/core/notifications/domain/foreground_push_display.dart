library;

import 'notification_message.dart';
import 'push_audience.dart';

const String kSilentPushKey = 'silent';

const Set<String> kSilentFalseStrings = <String>{
  '',
  'false',
  '0',
  'no',
  'off',
  'null',
  'none',
};

bool isSilentPush(Map<String, String> data) {
  final raw = data[kSilentPushKey];
  if (raw == null) return false;
  return !kSilentFalseStrings.contains(raw.trim().toLowerCase());
}

/// must be able to recognise that same thread, or a push would route to a
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

bool shouldShowForegroundPush({
  required NotificationCategory category,
  required Map<String, String> data,
  required Set<String> openChatThreadIds,
  // null = no roles resolver wired: skip the audience gate (fail open).
  Set<String>? localRoles,
}) {
  if (isSilentPush(data)) return false;
  if (localRoles != null && !isPushAudienceMatch(data, localRoles)) {
    return false;
  }
  if (category != NotificationCategory.chat) return true;
  if (openChatThreadIds.isEmpty) return true;
  for (final id in chatThreadIdsFromPush(data)) {
    if (openChatThreadIds.contains(id)) return false;
  }
  return true;
}
