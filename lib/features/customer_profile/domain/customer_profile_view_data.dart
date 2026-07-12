import 'package:equatable/equatable.dart';

/// Read model for the Customer Profile screen (Figma 56581:1910, screen 18).
///
/// The screen is a parity surface over the existing profile/settings data
/// (user-management + remote-user-preferences via the gateway). It carries
/// only what the header renders; the Account/Support rows are static
/// navigation affordances and need no per-user data beyond [isJeeber] (which
/// hides the "Register as a delivery" row once the customer is a Jeeber).
class CustomerProfileViewData extends Equatable {
  const CustomerProfileViewData({
    this.name,
    this.email,
    this.avatarUrl,
    this.isVerified = false,
    this.isJeeber = false,
    this.rating,
    this.ratingCount = 0,
    this.activeRole,
    this.availableRoles = const <String>[],
  });

  /// Display name (dynamic data). `null` renders the initials avatar fallback
  /// with an empty name line — the caller is expected to supply a real name.
  final String? name;

  /// Account email (dynamic data); rendered LTR-in-RTL via [AutoDirectionText].
  final String? email;

  /// Avatar URL (cdn-service). `null` falls back to an initials avatar.
  final String? avatarUrl;

  /// Whether the account is verified (drives the SealCheck badge).
  final bool isVerified;

  /// Whether the customer is already a Jeeber. When `true` the
  /// "Register as a delivery" row is hidden (design §8.2).
  final bool isJeeber;

  /// Per-role rating average (JM-035 AC1 `customer_profile_rating`, D6). Sourced
  /// from `GET /user-management/users/me` (`rating`). `null` when the account has
  /// no rating yet (the seeded customer carries no rating) — the header then
  /// renders a deterministic "no ratings yet" state with the SAME identifier so
  /// the Maestro assertion stays valid (the id is presence-only, not value).
  final double? rating;

  /// Number of ratings backing [rating] (`ratingCount` on getMe). `0` when the
  /// account has not been rated yet (drives the cold-start copy, D59-consistent).
  final int ratingCount;

  /// True when the account has at least one rating to display.
  bool get hasRating => rating != null && ratingCount > 0;

  /// The server-side ACTIVE role for this user from getMe (`activeRole`),
  /// e.g. `'client'` or `'jeeber'`. `null` when getMe did not surface it (the
  /// role state then keeps its persisted value). DEFECT-C: the app syncs the
  /// [RoleCubit] to this on login/resume so a returning dual-role user lands on
  /// the surface the server says they were last on.
  final String? activeRole;

  /// All role identifiers this user MAY act as from getMe (`availableRoles`),
  /// e.g. `['client', 'jeeber']` for a dual-role user. Drives whether the
  /// additive jeeber surfaces render live bodies (dual-role) vs empty states
  /// (single-role client). The manual in-app role toggle was removed in
  /// JEBV4-204 (the additive 5-tab shell + auto-activation supersede it).
  final List<String> availableRoles;

  /// True when the user can act as BOTH client and jeeber — i.e. the additive
  /// jeeber tab bodies render live rather than as become-a-jeeber empty states.
  bool get isDualRole =>
      availableRoles.contains('client') && availableRoles.contains('jeeber');

  CustomerProfileViewData copyWith({
    String? name,
    String? email,
    String? avatarUrl,
    bool? isVerified,
    bool? isJeeber,
    double? rating,
    int? ratingCount,
    String? activeRole,
    List<String>? availableRoles,
    bool clearRating = false,
  }) {
    return CustomerProfileViewData(
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
      isJeeber: isJeeber ?? this.isJeeber,
      rating: clearRating ? null : (rating ?? this.rating),
      ratingCount: ratingCount ?? this.ratingCount,
      activeRole: activeRole ?? this.activeRole,
      availableRoles: availableRoles ?? this.availableRoles,
    );
  }

  @override
  List<Object?> get props => [
        name,
        email,
        avatarUrl,
        isVerified,
        isJeeber,
        rating,
        ratingCount,
        activeRole,
        availableRoles,
      ];
}
