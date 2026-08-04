import 'user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile?> load();

  Future<void> save(UserProfile profile);

  Future<void> clear();
}
