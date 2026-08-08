import 'dart:typed_data';

import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_repository.dart';
import 'package:jeeb_mobile/features/customer_profile/domain/customer_profile_view_data.dart';
import 'package:jeeb_mobile/features/settings/domain/account_service.dart';
import 'package:jeeb_mobile/features/settings/domain/avatar_cache_evictor.dart';
import 'package:jeeb_mobile/features/settings/domain/avatar_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/jeeber_unregister_service.dart';
import 'package:jeeb_mobile/features/settings/domain/profile_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/user_profile.dart';

/// Test-only seams for the settings surface (T-mobile-031).
/// These were previously shipped under `lib/` and wired as the DI default,
/// which let release builds bypass the real persistence + gateway seams. They

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

/// F5 test double for [AvatarRepository]. Scripted outcome per call so a
/// single instance can cover both the happy path and a failure/rollback
/// scenario across separate tests.
class FakeAvatarRepository implements AvatarRepository {
  FakeAvatarRepository({this.uploadFailure, this.removeFailure});

  AvatarRepositoryException? uploadFailure;
  AvatarRepositoryException? removeFailure;
  int uploadCalls = 0;
  int removeCalls = 0;
  Uint8List? lastUploadedBytes;
  String uploadedUrl = 'https://gw.test/api/users/u-1/avatar?v=1';

  @override
  Future<String> uploadAvatar(Uint8List bytes) async {
    uploadCalls++;
    lastUploadedBytes = bytes;
    if (uploadFailure != null) throw uploadFailure!;
    return uploadedUrl;
  }

  @override
  Future<void> removeAvatar() async {
    removeCalls++;
    if (removeFailure != null) throw removeFailure!;
  }
}

/// F5 test double for [AvatarCacheEvictor] — records what was evicted
/// instead of touching a real image cache.
class FakeAvatarCacheEvictor implements AvatarCacheEvictor {
  final List<String> evicted = <String>[];

  @override
  Future<void> evict(String url) async {
    evicted.add(url);
  }
}

/// F5 test double for [CustomerProfileRepository] — backs
/// `SettingsCubit.load()`'s cross-device staleness fix.
class FakeCustomerProfileRepository implements CustomerProfileRepository {
  FakeCustomerProfileRepository({this.profile, this.throws = false});

  CustomerProfileViewData? profile;
  bool throws;

  @override
  Future<CustomerProfileViewData> fetchProfile() async {
    if (throws) {
      throw const CustomerProfileRepositoryException(
        CustomerProfileFailure.network,
      );
    }
    return profile ?? const CustomerProfileViewData();
  }
}

/// F3 test double for [JeeberUnregisterService] — scripted outcome + a call
/// counter so tests can assert the double-submit guard.
class FakeJeeberUnregisterService implements JeeberUnregisterService {
  FakeJeeberUnregisterService({
    this.outcome = JeeberUnregisterOutcome.success,
  });

  JeeberUnregisterOutcome outcome;
  int calls = 0;

  @override
  Future<JeeberUnregisterOutcome> unregister() async {
    calls++;
    return outcome;
  }
}
