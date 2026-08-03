import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/data/shared_prefs_profile_repository.dart';
import '../../settings/domain/profile_repository.dart';
import '../domain/recipient_phone_resolver.dart';

class SharedPrefsRecipientPhoneResolver implements RecipientPhoneResolver {
  SharedPrefsRecipientPhoneResolver({ProfileRepository? profileRepository})
      : _profileRepository = profileRepository;

  final ProfileRepository? _profileRepository;

  @override
  Future<String?> resolve() async {
    try {
      final repo = _profileRepository ??
          SharedPrefsProfileRepository(
            prefs: await SharedPreferences.getInstance(),
          );
      final profile = await repo.load();
      final raw = profile?.phoneE164.trim();
      if (raw == null || raw.isEmpty) return null;
      return raw;
    } catch (_) {
      return null;
    }
  }
}
