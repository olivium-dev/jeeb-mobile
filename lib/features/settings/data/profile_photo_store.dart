import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Persists a picked avatar to app-local storage and returns the stored
/// path/URI the profile's `photoUrl` field can carry (JEBV4-13 — the
/// profile-edit "Change avatar" flow needs somewhere durable for the picked
/// bytes; no avatar-upload backend endpoint exists yet, so the avatar is
/// device-local, matching the local-first SharedPrefsProfileRepository the
/// rest of the profile already uses).
abstract class ProfilePhotoStore {
  /// Writes [bytes] and returns an absolute path suitable for
  /// `UserProfile.photoUrl`.
  Future<String> persist(Uint8List bytes);
}

/// Production store: writes into the application documents directory. The
/// filename is timestamped so a changed avatar is a NEW path — image caches
/// keyed on the path can never show the stale photo.
class AppDirProfilePhotoStore implements ProfilePhotoStore {
  const AppDirProfilePhotoStore();

  @override
  Future<String> persist(Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/profile_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

/// In-memory store for widget tests: records the persisted bytes and returns
/// a deterministic fake path without touching path_provider's platform
/// channel.
class FakeProfilePhotoStore implements ProfilePhotoStore {
  FakeProfilePhotoStore({this.path = '/tmp/fake_profile_avatar.jpg'});

  final String path;
  Uint8List? lastBytes;
  int persistCalls = 0;

  @override
  Future<String> persist(Uint8List bytes) async {
    persistCalls++;
    lastBytes = bytes;
    return path;
  }
}
