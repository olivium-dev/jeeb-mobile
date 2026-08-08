import 'dart:typed_data';

/// Port for the F5 remote avatar write path: CDN upload + committing the
/// resulting URL onto the profile. Deliberately NOT [DisplayNameRepository]
/// — a dedicated method makes the historical `profilePic: ''` clobber
/// (dio_display_name_repository.dart) structurally impossible to reintroduce
/// here, since this repository never constructs a name-bearing PUT body.
abstract class AvatarRepository {
  /// Uploads [bytes] to the CDN broker, commits the resulting public avatar
  /// URL onto the profile, and returns that (already versioned) URL.
  Future<String> uploadAvatar(Uint8List bytes);

  /// Clears the remote avatar. Best-effort from the caller's perspective —
  /// see [SettingsCubit.removePhoto] for how a remote failure here is
  /// handled without blocking the local removal the user asked for.
  Future<void> removeAvatar();
}

enum AvatarUploadFailure { tooLarge, network, unauthorized, serverError, unknown }

class AvatarRepositoryException implements Exception {
  const AvatarRepositoryException(this.failure, [this.message]);

  final AvatarUploadFailure failure;
  final String? message;

  @override
  String toString() =>
      'AvatarRepositoryException(${failure.name}${message == null ? '' : ': $message'})';
}
