import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/location/data/fake_address_form_repository.dart';
import 'package:jeeb_mobile/features/location/data/location_repository.dart';
import 'package:jeeb_mobile/features/location/data/map_picker_launcher.dart';
import 'package:jeeb_mobile/features/location/presentation/screens/address_detail_form_screen.dart';

import '../../support/sync_app_localizations.dart';

/// Records each pickOnMap call and returns a scripted point.
class _FakeLauncher implements MapPickerLauncher {
  _FakeLauncher(this._result);

  final LocationPoint? _result;
  int calls = 0;
  LocationPoint? lastInitial;

  @override
  Future<LocationPoint?> pickOnMap({LocationPoint? initial}) async {
    calls++;
    lastInitial = initial;
    return _result;
  }
}

void main() {
  testWidgets(
    'Edit pin drives the map picker (not a no-op) and adopts the returned '
    'point (JEBV4-110)',
    (tester) async {
      final launcher = _FakeLauncher(
        const LocationPoint(latitude: 1.5, longitude: 2.5),
      );

      await tester.pumpWidget(
        wrapForTest(
          AddressDetailFormScreen(
            userId: 'u1',
            repository: const FakeAddressFormRepository(),
            mapPickerLauncher: launcher,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First tap: the dead no-op is gone — the button opens the picker. On the
      await tester.tap(find.text('Edit pin'));
      await tester.pumpAndSettle();
      expect(launcher.calls, 1);
      expect(launcher.lastInitial, isNull);

      // Second tap: now seeded with the point the first pick returned — proving
      await tester.tap(find.text('Edit pin'));
      await tester.pumpAndSettle();
      expect(launcher.calls, 2);
      expect(launcher.lastInitial?.latitude, 1.5);
      expect(launcher.lastInitial?.longitude, 2.5);
    },
  );
}
