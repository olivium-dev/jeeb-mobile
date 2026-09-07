/// Device-local display time, optionally supplied by a scoped preview or test.
class ClientHomeDisplayClock {
  ClientHomeDisplayClock({DateTime Function()? now})
    : now = now ?? DateTime.now;

  final DateTime Function() now;
}
