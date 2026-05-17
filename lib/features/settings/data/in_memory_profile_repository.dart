import '../domain/profile_repository.dart';
import '../domain/user_profile.dart';

/// In-memory [ProfileRepository] used by the default `SettingsScreen()`
/// constructor and by widget tests that don't care about persistence.
///
/// Production wires [SharedPrefsProfileRepository] via the DI graph; this
/// type keeps the route mountable without it.
class InMemoryProfileRepository implements ProfileRepository {
  UserProfile? _profile;

  @override
  Future<UserProfile?> load() async => _profile;

  @override
  Future<void> save(UserProfile profile) async {
    _profile = profile;
  }

  @override
  Future<void> clear() async {
    _profile = null;
  }
}
