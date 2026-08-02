library;

typedef ChatThreadIdsReader = Set<String> Function();

/// session, a foreground push for that same thread must not buzz the shade.
class ActiveChatThread {
  ActiveChatThread._();

  static final ActiveChatThread instance = ActiveChatThread._();

  Object? _owner;
  ChatThreadIdsReader? _reader;

  Set<String> get openIds {
    final reader = _reader;
    if (reader == null) return const <String>{};
    try {
      return _clean(reader());
    } catch (_) {
      return const <String>{};
    }
  }

  void enter(Object owner, ChatThreadIdsReader reader) {
    _owner = owner;
    _reader = reader;
  }

  void leave(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _reader = null;
  }

  bool isOpen(Iterable<String> candidateIds) {
    final ids = openIds;
    if (ids.isEmpty) return false;
    for (final id in candidateIds) {
      if (id.isNotEmpty && ids.contains(id)) return true;
    }
    return false;
  }

  void resetForTest() {
    _owner = null;
    _reader = null;
  }

  static Set<String> _clean(Iterable<String> ids) {
    final out = <String>{};
    for (final id in ids) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty) out.add(trimmed);
    }
    return out;
  }
}
