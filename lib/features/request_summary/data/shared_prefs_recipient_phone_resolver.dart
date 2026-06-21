import 'package:shared_preferences/shared_preferences.dart';

import '../../settings/data/shared_prefs_profile_repository.dart';
import '../../settings/domain/profile_repository.dart';
import '../domain/recipient_phone_resolver.dart';

/// [RecipientPhoneResolver] that defaults the recipient phone to the phone the
/// CLIENT authenticated/registered with, read from the LOCALLY-persisted user
/// profile ([SharedPrefsProfileRepository], key `settings.profile.v1`).
///
/// WHY THIS EXISTS (iter6 OTP-phone v2): the prior #67 default source —
/// `GET /v1/users/me` `phone` — does NOT exist in the LIVE gateway
/// `UsersMeResponse` contract (it exposes only `{userId, active_role,
/// available_roles, name, email, avatarUrl}`), so that resolver always returned
/// null and the at-door OTP `verify {code:"1234"}` kept 400-ing
/// `recipient-phone-missing`. This resolver instead reads the phone the client
/// actually holds locally — `UserProfile.phoneE164`, captured during phone-OTP
/// registration (and editable in profile-edit) — which the live `/me` does not
/// surface. It is the PRIORITY-A local-phone default for the create body.
///
/// Best-effort: any miss (no saved profile, empty phone, storage fault) returns
/// `null` so the create still proceeds (the gateway `recipientPhone` is
/// optional); the explicit compose-form recipient phone — when the user enters
/// one — always wins over this default in the submission service.
class SharedPrefsRecipientPhoneResolver implements RecipientPhoneResolver {
  SharedPrefsRecipientPhoneResolver({ProfileRepository? profileRepository})
      : _profileRepository = profileRepository;

  /// Optional injected repo (tests). When null, the resolver lazily opens
  /// [SharedPreferences] and reads the same `settings.profile.v1` blob the
  /// [SharedPrefsProfileRepository] writes.
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
      // A default-phone lookup must NEVER fail the order create.
      return null;
    }
  }
}
