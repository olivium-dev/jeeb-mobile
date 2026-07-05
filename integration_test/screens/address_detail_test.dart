// Isolated native UI test — AddressDetailFormScreen (address-detail, JM-050).
// The screen self-provides its AddressFormCubit; injecting `userId` skips the
// AuthTokenStore FutureBuilder and `repository` supplies the in-memory
// FakeAddressFormRepository, so the form mounts with no Dio/session. The add
// path opens on empty fields (neutral map pin); the edit path opens pre-filled
// from an `existing` SavedLocation. Covers add (en), edit pre-filled (en), and
// Arabic.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/location/data/fake_address_form_repository.dart';
import 'package:jeeb_mobile/features/location/domain/saved_location.dart';
import 'package:jeeb_mobile/features/location/presentation/screens/address_detail_form_screen.dart';

import '../support/screen_harness.dart';

const _existing = SavedLocation(
  id: 'addr-client-001-home',
  label: 'Home',
  latitude: 33.8869,
  longitude: 35.5131,
  category: SavedLocationCategory.home,
  address: 'Sassine Square, Ashrafieh',
  isDefault: true,
  building: 'Cedar Tower',
  floorApt: '4th floor, Apt 7',
  deliveryNotes: 'Ring the bell twice',
  codPhone: '+96170100200',
);

AddressDetailFormScreen _addScreen() => const AddressDetailFormScreen(
      userId: 'user-test',
      repository: FakeAddressFormRepository(),
    );

AddressDetailFormScreen _editScreen() => const AddressDetailFormScreen(
      userId: 'user-test',
      addressId: 'addr-client-001-home',
      existing: _existing,
      repository: FakeAddressFormRepository(),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('address-detail: add mode, empty form (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _addScreen(),
      'address-detail__add',
    );
  });

  testWidgets('address-detail: edit mode, pre-filled (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _editScreen(),
      'address-detail__edit',
    );
  });

  testWidgets('address-detail: add mode (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _addScreen(),
      'address-detail__ar',
      locale: const Locale('ar'),
    );
  });
}
