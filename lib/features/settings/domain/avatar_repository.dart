import 'dart:typed_data';

/// Port for the F5 remote avatar write path: CDN upload + committing the URL.
/// Separate from [DisplayNameRepository] so it never constructs a name PUT body.
abstract class AvatarRepository {
  /// Uploads [bytes], commits the resulting public avatar URL, returns that URL.
  Future<String> uploadAvatar(Uint8List bytes);

  /// Clears the remote avatar; best-effort (see [SettingsCubit.removePhoto]).
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
