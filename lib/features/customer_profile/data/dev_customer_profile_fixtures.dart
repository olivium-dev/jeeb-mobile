import '../domain/customer_profile_view_data.dart';

abstract final class DevCustomerProfileFixtures {
  static const CustomerProfileViewData sample = CustomerProfileViewData(
    name: 'Sami Fawaz',
    email: 'kamalhaaj@gmail.com',
    avatarUrl: 'https://i.pravatar.cc/150?img=12',
    isVerified: true,
    isJeeber: false,
    rating: 4.8,
    ratingCount: 27,
  );
}
