/// Shared periodic poll: multiple consumers may declare/withdraw INTEREST.
/// Interest is a Set keyed by owner identity (not a counter), so double-add or
abstract interface class PollingSource {
  void addPollInterest(Object owner);
  void removePollInterest(Object owner);
}
