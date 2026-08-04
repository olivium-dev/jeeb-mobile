/// "Something can tell me whether my polling surface is on screen."
/// Implemented by [LifecyclePoller] directly, and by any cubit/repository that
abstract interface class PollingVisibility {
  /// Level-triggered and idempotent. Must never fetch, never dispose, and
  /// never re-arm a poller whose owner called `stop()`.
  void setPollingVisible(bool visible);
}
