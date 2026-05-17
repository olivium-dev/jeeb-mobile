import 'user_profile.dart';

/// Storage seam for the user profile (T-mobile-031).
///
/// The settings screen has no opinion about whether the profile lives in
/// SharedPreferences, a Hive box, or a future jeeb-gateway round trip — it
/// only knows it can `load`, `save`, and `clear` (used by sign-out).
abstract class ProfileRepository {
  /// Returns the cached profile or `null` if the user has never edited it.
  Future<UserProfile?> load();

  /// Persists [profile]. Implementations must replace the entire record so a
  /// `null` field (e.g. user cleared the photo) survives the round trip.
  Future<void> save(UserProfile profile);

  /// Drops the cached profile. Called from the sign-out path.
  Future<void> clear();
}
