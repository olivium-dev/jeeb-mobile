abstract class ChatFirebaseIdentity {
  Future<String?> ensureSignedIn();

  static const ChatFirebaseIdentity absent = _AbsentChatFirebaseIdentity();
}

class _AbsentChatFirebaseIdentity implements ChatFirebaseIdentity {
  const _AbsentChatFirebaseIdentity();

  @override
  Future<String?> ensureSignedIn() async => null;
}

abstract class ChatFirebaseTokenMinter {
  Future<String?> mintCustomToken();
}
