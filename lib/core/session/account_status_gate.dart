abstract class AccountStatusGate {

  bool get isBlocked;
}

class AlwaysActiveAccountStatusGate implements AccountStatusGate {
  const AlwaysActiveAccountStatusGate();

  @override
  bool get isBlocked => false;
}
