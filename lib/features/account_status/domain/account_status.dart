enum AccountStatusValue {
  suspended,

  locked;

  static AccountStatusValue fromWire(String? status) {
    switch (status?.trim().toLowerCase()) {
      case 'locked':
        return AccountStatusValue.locked;
      case 'suspended':
        return AccountStatusValue.suspended;
      default:
        return AccountStatusValue.suspended;
    }
  }
}

class AccountStatusInfo {
  const AccountStatusInfo({required this.value, this.reason});

  final AccountStatusValue value;

  final String? reason;
}
