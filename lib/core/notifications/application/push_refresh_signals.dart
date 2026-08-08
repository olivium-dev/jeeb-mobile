import 'dart:async';

enum RefreshTopic {
  order,

  chat,

  feed,

  offers,

  /// F1 — wallet-affecting pushes (currently: guard-2 auto-withdraw only, no
  /// top-up producer exists server-side).
  wallet,
}

class PushRefreshSignals {
  final StreamController<Set<RefreshTopic>> _controller =
      StreamController<Set<RefreshTopic>>.broadcast();

  Stream<void> get stream => _controller.stream;

  Stream<void> streamFor(Set<RefreshTopic> topics) {
    if (topics.isEmpty) return stream;
    return _controller.stream.where((published) => published.any(topics.contains));
  }

  void signal(Set<RefreshTopic> topics) {
    if (_controller.isClosed || topics.isEmpty) return;
    _controller.add(Set<RefreshTopic>.unmodifiable(topics));
  }

  void signalStatusChange() => signal(RefreshTopic.values.toSet());

  Future<void> dispose() => _controller.close();
}
