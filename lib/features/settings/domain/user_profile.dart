import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  const UserProfile({
    required this.phoneE164,
    this.name,
    this.photoUrl,
  });

  const UserProfile.empty()
      : phoneE164 = '',
        name = null,
        photoUrl = null;

/// Read-only E.164 phone (e.g. `+96170123456`).
  final String phoneE164;

  final String? name;

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
