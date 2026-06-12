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

  @override
  List<Object?> get props => [name, email, avatarUrl, isVerified, isJeeber];
}
