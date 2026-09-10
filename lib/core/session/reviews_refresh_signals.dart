import 'dart:async';

/// Invalidation only: never carries a score or increments a received count.
class ReviewsRefreshEvent {
  const ReviewsRefreshEvent({required this.rateeId, this.source});

  final String rateeId;
  final Object? source;
}

class ReviewsRefreshSignals {
  static final instance = ReviewsRefreshSignals();

  final _controller = StreamController<ReviewsRefreshEvent>.broadcast();

  Stream<ReviewsRefreshEvent> get stream => _controller.stream;

  void signalChanged({required String rateeId, Object? source}) {
    if (_controller.isClosed || rateeId.trim().isEmpty) return;
    _controller.add(ReviewsRefreshEvent(rateeId: rateeId, source: source));
  }

  Future<void> dispose() => _controller.close();
}
