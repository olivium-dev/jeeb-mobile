import 'package:jeeb_mobile/features/settings/domain/account_service.dart';
import 'package:jeeb_mobile/features/settings/domain/profile_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/user_profile.dart';

/// Test-only seams for the settings surface (T-mobile-031).
///
/// These were previously shipped under `lib/` and wired as the DI default,
/// which let release builds bypass the real persistence + gateway seams. They
/// now live under `test/` so production resolves the real
/// `SharedPrefsProfileRepository` + `DioAccountService` from GetIt, while widget
/// and cubit tests keep a zero-network, in-memory double.

/// In-memory [ProfileRepository] for widget/cubit tests that don't care about
/// persistence. Production wires [SharedPrefsProfileRepository] via DI.
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

/// No-network [AccountService] that always succeeds. Production wires
/// [DioAccountService] via DI; this double lets tests exercise the settings
/// cubit's destructive-action state machine without a gateway.
class FakeAccountService implements AccountService {
  const FakeAccountService();

  @override
  Future<AccountActionOutcome> requestAccountDeletion() async {
    return AccountActionOutcome.success;
  }

  @override
  Future<AccountActionOutcome> signOut() async {
    return AccountActionOutcome.success;
  }
}
