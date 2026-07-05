// Isolated native UI test — jeeber-active-delivery (ActiveDeliveryJeeberScreen,
// JM-051). The screen takes a `cubit` seam, so we seed an ActiveDeliveryCubit
// over an in-memory ActiveDeliveryRepository and drive it to the AtDoor stage —
// where the mark-delivered panel (proof capture + cash-receipt copy + CTA) is
// surfaced alongside the address card, status stepper, and action buttons. The
// cubit runs no timers; loadDelivery() is awaited before the pump.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';

import '../support/screen_harness.dart';

const String _deliveryId = 'DLV-770001';

const _dropOff = DropOffAddress(
  label: 'Verdun, Beirut',
  lat: 33.88,
  lng: 35.49,
  detail: 'Building 12, 3rd floor',
);

JeeberDelivery _delivery(JeeberDeliveryStatus status) => JeeberDelivery(
      id: _deliveryId,
      status: status,
      dropOff: _dropOff,
      clientName: 'Sami Fawaz',
      amountText: '10.00 USD',
    );

/// In-memory repository — echoes the requested transition and mints a stable
/// evidence URL, so no network/plugin is touched.
class _StaticActiveDeliveryRepository implements ActiveDeliveryRepository {
  _StaticActiveDeliveryRepository(this._snapshot);

  final JeeberDelivery _snapshot;

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async => _snapshot;

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) async =>
      to;

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async =>
      JeeberDeliveryStatus.done;

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required String filename,
  }) async =>
      'https://cdn.jeeb.app/proof/$deliveryId.jpg';
}

Future<ActiveDeliveryCubit> _seededCubit() async {
  final cubit = ActiveDeliveryCubit(
    repository:
        _StaticActiveDeliveryRepository(_delivery(JeeberDeliveryStatus.atDoor)),
    deliveryId: _deliveryId,
  );
  await cubit.loadDelivery();
  return cubit;
}

Widget _screen(ActiveDeliveryCubit cubit) => ActiveDeliveryJeeberScreen(
      deliveryId: _deliveryId,
      onOpenChat: () {},
      cubit: cubit,
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('jeeber-active-delivery: at-door mark-delivered (en)',
      (tester) async {
    final cubit = await _seededCubit();
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _screen(cubit),
      'jeeber-active-delivery__at-door',
    );
  });

  testWidgets('jeeber-active-delivery: at-door mark-delivered (ar)',
      (tester) async {
    final cubit = await _seededCubit();
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _screen(cubit),
      'jeeber-active-delivery__at-door-ar',
      locale: const Locale('ar'),
    );
  });
}
