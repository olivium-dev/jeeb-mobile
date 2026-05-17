import 'package:equatable/equatable.dart';

/// Read model for the profile-and-settings screen (T-mobile-031).
///
/// `phoneE164` is the canonical Lebanese number captured during registration.
/// It is rendered read-only in the profile-edit screen — the only way to
/// change the phone is to re-run phone-OTP registration, which is a separate
/// flow (T-mobile-002). The `name` and `photoUrl` are the only mutable
/// fields; both are optional during onboarding and may be `null`.
class UserProfile extends Equatable {
  const UserProfile({
    required this.phoneE164,
    this.name,
    this.photoUrl,
  });

  /// Empty profile to seed the cubit before the first repository read
  /// resolves. Useful in widget tests that don't want to plumb a real repo.
  const UserProfile.empty()
      : phoneE164 = '',
        name = null,
        photoUrl = null;

  /// Read-only E.164 phone (e.g. `+96170123456`).
  final String phoneE164;

  /// Display name. `null` means the user has not set one yet — the UI shows
  /// the localized "Add your name" placeholder.
  final String? name;

  /// Avatar URL (or any URI the OMDS image widget can resolve). `null`
  /// renders an initials avatar.
  final String? photoUrl;

  UserProfile copyWith({
    String? phoneE164,
    Object? name = _sentinel,
    Object? photoUrl = _sentinel,
  }) {
    return UserProfile(
      phoneE164: phoneE164 ?? this.phoneE164,
      name: identical(name, _sentinel) ? this.name : name as String?,
      photoUrl:
          identical(photoUrl, _sentinel) ? this.photoUrl : photoUrl as String?,
    );
  }

  @override
  List<Object?> get props => [phoneE164, name, photoUrl];
}

const Object _sentinel = Object();
