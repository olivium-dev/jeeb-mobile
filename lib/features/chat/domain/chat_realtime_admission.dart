import 'delivery_chat_message.dart';

const String kRealtimeRefusedAuctionPhase = 'auction_phase';

enum ChatRosterVerdict {
  settled,

  contested,

  unknown,
}

bool realtimeChatAdmitted({
  required ConversationPhase phase,
  required ChatRosterVerdict roster,
}) {
  if (roster == ChatRosterVerdict.contested) return false;
  return roster == ChatRosterVerdict.settled ||
      phase == ConversationPhase.accepted;
}
