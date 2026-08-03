enum UserRole {
  client,
  jeeber;

  String get storageKey => name;

  static UserRole fromStorage(String? value) =>
      UserRole.values.firstWhere(
        (r) => r.storageKey == value,
        orElse: () => UserRole.client,
      );
}
