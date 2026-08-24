import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/analytics/clarity/data/shared_prefs_clarity_consent_store.dart';
import 'package:jeeb_mobile/core/analytics/clarity/domain/clarity_consent.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  Future<SharedPrefsClarityConsentStore> store() async =>
      SharedPrefsClarityConsentStore(await SharedPreferences.getInstance());

  test('missing and corrupt values are unknown and off', () async {
    expect(await (await store()).read(), ClarityConsent.unknown);
    SharedPreferences.setMockInitialValues(<String, Object>{
      SharedPrefsClarityConsentStore.consentPreferenceName: 'yes-please',
    });
    expect(await (await store()).read(), ClarityConsent.unknown);
  });

  test('grant expires on restart while denial persists', () async {
    final subject = await store();
    expect(await subject.write(ClarityConsent.granted), isTrue);
    expect(await subject.read(), ClarityConsent.unknown);
    expect(await subject.write(ClarityConsent.denied), isTrue);
    expect(await subject.read(), ClarityConsent.denied);
  });

  test('read and write failures fail closed', () async {
    final prefs = await SharedPreferences.getInstance();
    final subject = SharedPrefsClarityConsentStore(
      prefs,
      reader: (_) => throw StateError('corrupt'),
      writer: (_, _) async => throw StateError('disk full'),
      remover: (_) async => throw StateError('disk full'),
    );
    expect(await subject.read(), ClarityConsent.unknown);
    expect(await subject.write(ClarityConsent.granted), isFalse);
    expect(await subject.write(ClarityConsent.unknown), isFalse);
  });

  test('failed denial write cannot leave a prior grant behind', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SharedPrefsClarityConsentStore.consentPreferenceName,
      'granted',
    );
    final subject = SharedPrefsClarityConsentStore(
      prefs,
      writer: (_, _) async => false,
    );

    expect(await subject.write(ClarityConsent.denied), isFalse);
    expect(await subject.read(), ClarityConsent.unknown);
  });

  test('failed removal falls back to overwriting grant with denial', () async {
    final prefs = await SharedPreferences.getInstance();
    Object? persisted = 'granted';
    final subject = SharedPrefsClarityConsentStore(
      prefs,
      reader: (_) => persisted,
      writer: (_, value) async {
        persisted = value;
        return true;
      },
      remover: (_) async => false,
    );

    expect(await subject.write(ClarityConsent.denied), isTrue);
    final restarted = SharedPrefsClarityConsentStore(
      prefs,
      reader: (_) => persisted,
      writer: (_, _) async => false,
      remover: (_) async => false,
    );
    expect(await restarted.read(), ClarityConsent.denied);
  });

  test(
    'failed removal and write cannot rehydrate grant after restart',
    () async {
      final prefs = await SharedPreferences.getInstance();
      const persisted = 'granted';
      final subject = SharedPrefsClarityConsentStore(
        prefs,
        reader: (_) => persisted,
        writer: (_, _) async => false,
        remover: (_) async => false,
      );

      expect(await subject.write(ClarityConsent.denied), isFalse);
      final restarted = SharedPrefsClarityConsentStore(
        prefs,
        reader: (_) => persisted,
        writer: (_, _) async => false,
        remover: (_) async => false,
      );
      expect(await restarted.read(), ClarityConsent.unknown);
    },
  );
}
