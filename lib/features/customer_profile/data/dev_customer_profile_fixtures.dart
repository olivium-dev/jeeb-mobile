import '../domain/customer_profile_view_data.dart';

/// Deterministic fixture for the Customer Profile dev-seam capture path
/// (`jeeb.route=/profile/customer`). Mirrors the Figma comp (Sami Fawaz, a
/// verified, not-yet-Jeeber customer) so a single dev APK renders screen 18
/// without a rebuild. Debug-only; never referenced from a release path.
abstract final class DevCustomerProfileFixtures {
  static const CustomerProfileViewData sample = CustomerProfileViewData(
    name: 'Sami Fawaz',
    email: 'kamalhaaj@gmail.com',
    avatarUrl: 'https://i.pravatar.cc/150?img=12',
    isVerified: true,
    isJeeber: false,
  );
}
