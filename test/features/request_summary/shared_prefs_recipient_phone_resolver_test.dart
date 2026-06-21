import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/request_summary/data/shared_prefs_recipient_phone_resolver.dart';
import 'package:jeeb_mobile/features/settings/domain/profile_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/user_profile.dart';

class _FakeProfileRepo implements ProfileRepository {
  _FakeProfileRepo(this._profile, {this.throws = false});
  final UserProfile? _profile;
  final bool throws;

  @override
  Future<UserProfile?> load() async {
    if (throws) throw Exception('storage fault');
    return _profile;
  }

  @override
  Future<void> save(UserProfile profile) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  group('SharedPrefsRecipientPhoneResolver', () {
    test('returns the locally-persisted profile phone', () async {
      final resolver = SharedPrefsRecipientPhoneResolver(
        profileRepository:
            _FakeProfileRepo(const UserProfile(phoneE164: '+9613000001')),
      );
      expect(await resolver.resolve(), '+9613000001');
    });

    test('null when no profile is persisted', () async {
      final resolver = SharedPrefsRecipientPhoneResolver(
        profileRepository: _FakeProfileRepo(null),
      );
      expect(await resolver.resolve(), isNull);
    });

    test('null when the persisted phone is empty', () async {
      final resolver = SharedPrefsRecipientPhoneResolver(
        profileRepository: _FakeProfileRepo(const UserProfile(phoneE164: '')),
      );
      expect(await resolver.resolve(), isNull);
    });

    test('a storage fault degrades to null (never throws)', () async {
      final resolver = SharedPrefsRecipientPhoneResolver(
        profileRepository: _FakeProfileRepo(null, throws: true),
      );
      expect(await resolver.resolve(), isNull);
    });
  });
}
