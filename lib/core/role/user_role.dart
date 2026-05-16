/// Which side of the marketplace the user is currently acting as.
///
/// The bottom-nav shell shows a different tab-set per role:
/// - [client]: Home / Orders / Chat / Profile
/// - [jeeber]: Dashboard / Earnings / Chat / Profile
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
