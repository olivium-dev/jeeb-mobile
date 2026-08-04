import '../domain/customer_profile_view_data.dart';

abstract final class DevCustomerProfileFixtures {
  /// No `avatarUrl`: the old `i.pravatar.cc` value reached the network from
  /// every harness that mounted it (`CachedNetworkImage` → `path_provider`,
  /// which throws `MissingPluginException` under `flutter test`). The disc
  /// draws the designed initial instead — nothing is faked.
  static const CustomerProfileViewData sample = CustomerProfileViewData(
    name: 'Sami Fawaz',
    email: 'kamalhaaj@gmail.com',
    isVerified: true,
    isJeeber: false,
    rating: 4.8,
    ratingCount: 27,
  );
}
