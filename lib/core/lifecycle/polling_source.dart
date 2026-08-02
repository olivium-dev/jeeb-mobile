/// Shared periodic poll: multiple consumers may declare/withdraw INTEREST.
/// Interest is a Set keyed by owner identity (not a counter), so double-add or
/// remove-nonexistent are no-ops. Poll runs iff interest set is non-empty AND
/// app is foreground. Consumer must subscribe before declaring interest.
abstract interface class PollingSource {
  void addPollInterest(Object owner);
  void removePollInterest(Object owner);
}
