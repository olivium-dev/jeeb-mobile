import 'package:flutter/foundation.dart';

import '../../core/dev_seam/dev_seam.dart';
import '../chat/data/dev_chat_fixture_gateway.dart';
import '../chat/domain/chat_gateway.dart';
import '../chat/domain/delivery_chat_message.dart';

/// Debug-only resolver that maps a seeded client-home id (the ids the
/// [DevClientHomeFixtures] expose on the Pending / In Progress / Replies tabs)
/// to an offline [DevChatFixtureGateway] so the `/chat/:id` deep-link target
/// mounts a POPULATED thread on the dev seam — no live chat-service required.
///
/// Why this exists: under the dev seam (`jeeb.home_tab=pending`, screen 13) a
/// pending row tap pushes `/chat/pen-1`. With a live gateway the mock returns
/// 404 for that id (no seeded conversation) and the chat screen renders its
/// empty state, so the Maestro flow's `chat_detail_message_list` assertion is
/// (correctly) false. Routing these seeded ids through the SAME in-memory
/// fixture mechanism flows 02–07 use ([DevChatFixtureGateway]) seeds a real
/// thread with a read receipt, so the message list mounts honestly offline.
///
/// Release-inert by construction: every consumer call site is `kDebugMode`-
/// gated and [resolveGateway] short-circuits to `null` outside debug, so this
/// is tree-shaken from production builds.
class DevChatDetailFixtures {
  const DevChatDetailFixtures._();

  /// Seeded client-home ids that map to an offline chat thread. These mirror
  /// the reachable `/chat/:id` targets that [DevClientHomeFixtures] +
  /// `HomeTab._openChat` produce: the Pending (`pen-*`) and In Progress
  /// (`ip-*`) row ids, plus the Replies card conversation id (`conv-rep-1`).
  static const Set<String> _seededChatIds = <String>{
    'pen-1',
    'pen-2',
    'pen-3',
    'ip-1',
    'ip-2',
    'ip-3',
    'conv-rep-1',
  };

  /// Returns an offline [DevChatFixtureGateway] for [chatId] when the dev seam
  /// is driving a seeded client-home tab and [chatId] is one of the seeded
  /// ids; otherwise `null` so the caller falls back to its normal (Dio /
  /// in-memory) gateway resolution. Always `null` in release.
  static ChatGateway? resolveGateway(String chatId) {
    if (!kDebugMode) return null;
    if (!DevSeam.current.hasHomeTab) return null;
    if (!_seededChatIds.contains(chatId)) return null;
    // The accepted (1:1) thread is the right "populated thread" for a pending /
    // in-progress / replies row: a few realistic messages including a read
    // receipt (MessageStatus.read), matching the client-side accepted state.
    return DevChatFixtureGateway(phase: ConversationPhase.accepted);
  }
}
