import 'package:flutter/foundation.dart';

import '../../core/dev_seam/dev_seam.dart';
import '../chat/data/dev_chat_fixture_gateway.dart';
import '../chat/domain/chat_gateway.dart';
import '../chat/domain/delivery_chat_message.dart';

class DevChatDetailFixtures {
  const DevChatDetailFixtures._();

  static const Set<String> _seededChatIds = <String>{
    'pen-1',
    'pen-2',
    'pen-3',
    'ip-1',
    'ip-2',
    'ip-3',
    'conv-rep-1',
    // The failure rungs the dev seam could not otherwise reach.
    'fail-1',
    'partial-1',
  };

  static ChatGateway? resolveGateway(String chatId) {
    if (!kDebugMode) return null;
    if (!DevSeam.current.hasHomeTab) return null;
    if (!_seededChatIds.contains(chatId)) return null;
    if (chatId == 'fail-1') return FailingChatGateway();
    return DevChatFixtureGateway(phase: ConversationPhase.accepted);
  }
}
