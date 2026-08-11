import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

class SharedPrefsProfileRepository implements ProfileRepository {
  const SharedPrefsProfileRepository({required SharedPreferences prefs})
      : _prefs = prefs;

  /// Public so sign-out can drop the cache with the rest of the session —
  /// a surviving record leaks the previous account's name into Edit Profile.
  static const String profilePrefsKey = 'settings.profile.v1';

  final SharedPreferences _prefs;

  @override
  Future<UserProfile?> load() async {
    final raw = _prefs.getString(profilePrefsKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    final phone = decoded['phoneE164'];
    if (phone is! String) return null;
    return UserProfile(
      phoneE164: phone,
      name: decoded['name'] as String?,
      photoUrl: decoded['photoUrl'] as String?,
    );
  }

  @override
  Future<void> save(UserProfile profile) async {
    final encoded = jsonEncode(<String, Object?>{
      'phoneE164': profile.phoneE164,
      'name': profile.name,
      'photoUrl': profile.photoUrl,
    });
    await _prefs.setString(profilePrefsKey, encoded);
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(profilePrefsKey);
  }
}
