import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';

/// b02 wave C — N6. The jeeber's active-delivery screen ran a 5s
/// `GET /v1/deliveries/{id}` poll whose OWN rationale (the pre-change comment at
const _deliveryId = 'DLV-N6';
const _dropOff = DropOffAddress(label: 'Verdun', lat: 33.88, lng: 35.49);

JeeberDelivery _delivery(JeeberDeliveryStatus status) =>
    JeeberDelivery(id: _deliveryId, status: status, dropOff: _dropOff);

class _CountingRepository implements ActiveDeliveryRepository {
  _CountingRepository({required List<JeeberDeliveryStatus> statuses})
      : _statuses = statuses;

  final List<JeeberDeliveryStatus> _statuses;
  int fetchCalls = 0;

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) {
    final index =
        fetchCalls < _statuses.length ? fetchCalls : _statuses.length - 1;
    fetchCalls++;
    return Future<JeeberDelivery>.value(_delivery(_statuses[index]));
  }

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) =>
      Future<JeeberDeliveryStatus>.value(to);

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) =>
      Future<JeeberDeliveryStatus>.value(JeeberDeliveryStatus.done);

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) =>
      Future<String>.value('proof://$_deliveryId');
}

void main() {
  test('N6 — a delivery push re-reads the row exactly once', () async {
    final repo = _CountingRepository(statuses: [
      JeeberDeliveryStatus.ordered,
      JeeberDeliveryStatus.inTransit,
    ]);
    final bus = StreamController<void>.broadcast();
    addTearDown(bus.close);

    final cubit = ActiveDeliveryCubit(
      repository: repo,
      deliveryId: _deliveryId,
      refreshSignals: bus.stream,
    );
    addTearDown(cubit.close);

    await cubit.loadDelivery();
    expect(repo.fetchCalls, 1);
    expect(cubit.debugPushRefreshWired, isTrue);

    bus.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(repo.fetchCalls, 2, reason: 'one push → exactly one re-read');
    expect(cubit.state.delivery?.status, JeeberDeliveryStatus.inTransit,
        reason: 'the backend-driven transition surfaced without a poll');
  });

  test('N6 — no push ⇒ no read after 60 virtual seconds', () {
    fakeAsync((async) {
      final repo = _CountingRepository(
          statuses: const [JeeberDeliveryStatus.ordered]);
      final cubit = ActiveDeliveryCubit(
        repository: repo,
        deliveryId: _deliveryId,
        refreshSignals: const Stream<void>.empty(),
      );
      cubit.loadDelivery();
      async.flushMicrotasks();
      expect(repo.fetchCalls, 1);

      async.elapse(const Duration(seconds: 60));
      async.flushMicrotasks();

      expect(repo.fetchCalls, 1,
          reason: 'the 5s LifecyclePoller must be GONE — 60s of wall clock '
              'with no push and no user action is zero extra reads');
      cubit.close();
    });
  });

  test('N6 — a poll-terminal row retires the subscription', () async {
    final repo = _CountingRepository(statuses: [
      JeeberDeliveryStatus.ordered,
      JeeberDeliveryStatus.done,
    ]);
    final bus = StreamController<void>.broadcast();
    addTearDown(bus.close);

    final cubit = ActiveDeliveryCubit(
      repository: repo,
      deliveryId: _deliveryId,
      refreshSignals: bus.stream,
    );
    addTearDown(cubit.close);

    await cubit.loadDelivery();
    bus.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(repo.fetchCalls, 2);
    expect(cubit.state.delivery?.status, JeeberDeliveryStatus.done);
    expect(cubit.debugPushRefreshWired, isFalse,
        reason: 'a Done row never changes again — stop listening');

    bus.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(repo.fetchCalls, 2);
  });

  test('N6 — a DISPUTED row keeps listening (P6/A2: an admin can still resolve '
      'it)', () async {
    final repo = _CountingRepository(statuses: [
      JeeberDeliveryStatus.ordered,
      JeeberDeliveryStatus.disputed,
    ]);
    final bus = StreamController<void>.broadcast();
    addTearDown(bus.close);

    final cubit = ActiveDeliveryCubit(
      repository: repo,
      deliveryId: _deliveryId,
      refreshSignals: bus.stream,
    );
    addTearDown(cubit.close);

    await cubit.loadDelivery();
    bus.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.delivery?.status, JeeberDeliveryStatus.disputed);
    expect(cubit.debugPushRefreshWired, isTrue,
        reason: 'isPollTerminal excludes disputed — SM edges 12/13 can still '
            'move it, so the screen must keep watching');
  });
}
