import 'dart:async';

/// WHAT KIND of change a refresh signal announces.
///
/// b02 wave D. Until this enum existed the bus was payload-less AND
/// category-less: every push that reached [PushRefreshSignals] woke EVERY
/// subscriber, and by wave C there were twelve subscription sites. One inbound
/// chat message fanned out into the open thread's re-pull (wanted) plus
/// `ChatDetailScreen._refreshSummary` (three gateway reads), the customer home
/// summary, the jeeber active-deliveries card, the jeeber request feed and the
/// delivery-detail hub — none of which a chat message can change.
///
/// That was tolerable while a clock drove those surfaces, because the clock
/// bounded the rate. It stopped being tolerable the moment the trigger became
/// the MESSAGE rate: a busy conversation publishes faster than the 10 s poll it
/// replaced, so "convert the last polls to push" would have made the wire
/// BUSIER on exactly the surface the owner named.
///
/// Routing is by what the receiving surface RENDERS, not by who sent the push.
/// A subscriber that declares no topics still receives everything, so any call
/// site not listed in this batch behaves exactly as it did before.
enum RefreshTopic {
  /// A delivery/order advanced its own lifecycle state (accepted, picked up,
  /// in transit, delivered, cancelled). Read by every surface that paints an
  /// order status: the customer home summary, the delivery-detail hub, the
  /// chat status chip, live tracking, the jeeber's active-deliveries card.
  order,

  /// A chat message landed. Read by the OPEN THREAD and by nothing else — a
  /// message changes no order state, no offer set and no feed row.
  chat,

  /// The jeeber-visible request feed changed — a new auction opened. Read by
  /// `RequestFeedCubit` only.
  feed,

  /// The offer/auction set for a request changed (a bid arrived, an offer was
  /// accepted or lost, the request expired). Read by the customer's offer
  /// review list, the waiting/no-coverage screen, and the home summary's
  /// Replies count.
  offers,
}

/// App-wide broadcast bus for "a push says something this device renders has
/// changed — refetch".
///
/// Decouples the push stack (app layer — [PushNotificationHandler]) from the
/// surfaces that must re-pull, which live in the feature layer and must never
/// import the push stack. The handler is the sole publisher; interested cubits
/// and screens subscribe.
///
/// Registered as a lazy singleton in the DI container so both sides resolve the
/// SAME instance without a widget-tree provider dependency. There is exactly
/// ONE bus: a parallel, differently-shaped bus is how one subscriber silently
/// keeps polling while its twin goes push-driven. The [RefreshTopic] dimension
/// is how this bus stays one bus while still not waking six surfaces for a
/// message that concerns one of them.
class PushRefreshSignals {
  /// Carries the topic SET of one push, as one event.
  ///
  /// Deliberately not one event per topic: a subscriber interested in
  /// `{order, offers}` would then be woken TWICE by a single `offer` push and
  /// fire two overlapping reads — re-creating, inside the fix, the duplicate
  /// fan-out the fix exists to remove.
  final StreamController<Set<RefreshTopic>> _controller =
      StreamController<Set<RefreshTopic>>.broadcast();

  /// EVERY signal, unfiltered — the pre-wave-D behaviour.
  ///
  /// Kept as the default so a subscription site that has not declared its
  /// topics is over-woken (wasteful) rather than under-woken (silently stale,
  /// which is invisible on the device, in the journal and in a screenshot).
  Stream<void> get stream => _controller.stream;

  /// Only the signals whose published topic set intersects [topics].
  ///
  /// Empty [topics] would match nothing, which is the silent-staleness failure
  /// above, so it is treated as "no filter" and returns [stream].
  Stream<void> streamFor(Set<RefreshTopic> topics) {
    if (topics.isEmpty) return stream;
    return _controller.stream.where((published) => published.any(topics.contains));
  }

  /// Publish one signal carrying [topics]. No-op after [dispose], and a no-op
  /// for an empty set (a push that concerns nothing must wake nothing).
  void signal(Set<RefreshTopic> topics) {
    if (_controller.isClosed || topics.isEmpty) return;
    _controller.add(Set<RefreshTopic>.unmodifiable(topics));
  }

  /// Publish on EVERY topic — the pre-wave-D publish.
  ///
  /// Retained for callers that genuinely cannot classify what changed (and for
  /// the cancel-request flow, which invalidates order, offer and feed state at
  /// once). [PushNotificationHandler] no longer uses it: it classifies by
  /// [NotificationCategory].
  void signalStatusChange() => signal(RefreshTopic.values.toSet());

  Future<void> dispose() => _controller.close();
}
