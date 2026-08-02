// G4 (sprint-009 P0) — handover-code local persistence.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/features/otp_handover/data/shared_prefs_handover_code_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPrefsHandoverCodeStore> freshStore() async =>
      SharedPrefsHandoverCodeStore(
        prefs: await SharedPreferences.getInstance(),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
  });

  test('save → read round-trip', () async {
    final store = await freshStore();
    await store.save(deliveryId: 'DLV-1', code: '1234');

    expect(await store.read(deliveryId: 'DLV-1'), '1234');
  });

  test('G4 restart resilience: a NEW store instance over the same prefs '
      'still reads the code (cold-start analogue)', () async {
    final first = await freshStore();
    await first.save(deliveryId: 'DLV-1', code: '1234');

    // Simulated app restart: a brand-new store object, same backing storage.
    final second = await freshStore();
    expect(await second.read(deliveryId: 'DLV-1'), '1234');
  });

  test('codes are keyed per delivery', () async {
    final store = await freshStore();
    await store.save(deliveryId: 'DLV-1', code: '1111');
    await store.save(deliveryId: 'DLV-2', code: '2222');

    expect(await store.read(deliveryId: 'DLV-1'), '1111');
    expect(await store.read(deliveryId: 'DLV-2'), '2222');
  });

  test('save overwrites a previous code (gateway re-mint)', () async {
    final store = await freshStore();
    await store.save(deliveryId: 'DLV-1', code: '1111');
    await store.save(deliveryId: 'DLV-1', code: '9999');

    expect(await store.read(deliveryId: 'DLV-1'), '9999');
  });

  test('clear removes the row (post-handover hygiene)', () async {
    final store = await freshStore();
    await store.save(deliveryId: 'DLV-1', code: '1234');
    await store.clear(deliveryId: 'DLV-1');

    expect(await store.read(deliveryId: 'DLV-1'), isNull);
  });

  test('unknown delivery reads null (reinstall mid-delivery)', () async {
    final store = await freshStore();
    expect(await store.read(deliveryId: 'DLV-unknown'), isNull);
  });

  test('blank code / blank delivery id are never stored', () async {
    final store = await freshStore();
    await store.save(deliveryId: 'DLV-1', code: '   ');
    await store.save(deliveryId: '', code: '1234');

    expect(await store.read(deliveryId: 'DLV-1'), isNull);
    expect(await store.read(deliveryId: ''), isNull);
  });

  test('stored value is trimmed', () async {
    final store = await freshStore();
    await store.save(deliveryId: 'DLV-1', code: ' 1234 ');
    expect(await store.read(deliveryId: 'DLV-1'), '1234');
  });
}
