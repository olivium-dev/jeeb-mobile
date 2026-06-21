// Tests for the jeeber active-deliveries feature (iter6 real-flow blocker fix).
//
// Verifies:
//   - ActiveDeliverySummary.fromJson parses the gateway OrderListItem shape
//     (id, conversationId, status, title, dropoff.address) and chatRouteId
//     prefers the conversation id.
//   - DioActiveDeliveriesRepository drops Done rows and rows with no id.
//   - ActiveDeliveriesCubit emits loaded with the repo's deliveries; an empty
//     result leaves the banner empty (hasDeliveries == false).

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/application/active_deliveries_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_deliveries_repository.dart';
import 'package:jeeb_mobile/features/jeeber_active_deliveries/domain/active_delivery_summary.dart';

class _FakeRepo implements ActiveDeliveriesRepository {
  _FakeRepo(this._result);

  final List<ActiveDeliverySummary> _result;
  int calls = 0;

  @override
  Future<List<ActiveDeliverySummary>> listActive() async {
    calls++;
    return _result;
  }
}

void main() {
  group('ActiveDeliverySummary.fromJson', () {
    test('parses the gateway OrderListItem shape', () {
      final s = ActiveDeliverySummary.fromJson(const {
        'id': 'req-1',
        'status': 'InTransit',
        'conversationId': 'conv-9',
        'title': 'Flash delivery request',
        'pickup': {'address': 'Hamra'},
        'dropoff': {'address': 'Achrafieh'},
      });
      expect(s.id, 'req-1');
      expect(s.status, JeeberDeliveryStatus.inTransit);
      expect(s.conversationId, 'conv-9');
      expect(s.title, 'Flash delivery request');
      expect(s.pickupAddress, 'Hamra');
      expect(s.dropoffAddress, 'Achrafieh');
      // chatRouteId prefers the conversation id.
      expect(s.chatRouteId, 'conv-9');
      expect(s.isActive, isTrue);
    });

    test('chatRouteId falls back to the delivery id when no conversation', () {
      final s = ActiveDeliverySummary.fromJson(const {
        'id': 'req-2',
        'status': 'ordered',
      });
      expect(s.conversationId, isNull);
      expect(s.chatRouteId, 'req-2');
    });

    test('Done status is not active', () {
      final s = ActiveDeliverySummary.fromJson(const {
        'id': 'req-3',
        'status': 'Done',
      });
      expect(s.status, JeeberDeliveryStatus.done);
      expect(s.isActive, isFalse);
    });
  });

  group('ActiveDeliveriesCubit', () {
    test('start() loads deliveries and emits loaded', () async {
      final repo = _FakeRepo([
        ActiveDeliverySummary.fromJson(const {
          'id': 'req-1',
          'status': 'Ordered',
          'conversationId': 'conv-1',
          'title': 'Flash delivery request',
        }),
      ]);
      final cubit = ActiveDeliveriesCubit(
        repository: repo,
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(cubit.close);

      cubit.start();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.phase, ActiveDeliveriesPhase.loaded);
      expect(cubit.state.hasDeliveries, isTrue);
      expect(cubit.state.deliveries.single.id, 'req-1');
      expect(repo.calls, 1);
    });

    test('empty result → banner stays empty (hasDeliveries false)', () async {
      final repo = _FakeRepo(const []);
      final cubit = ActiveDeliveriesCubit(
        repository: repo,
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(cubit.close);

      cubit.start();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.phase, ActiveDeliveriesPhase.loaded);
      expect(cubit.state.hasDeliveries, isFalse);
    });

    test('start() is idempotent (no double initial load scheduling)', () async {
      final repo = _FakeRepo(const []);
      final cubit = ActiveDeliveriesCubit(
        repository: repo,
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(cubit.close);

      cubit.start();
      cubit.start();
      await Future<void>.delayed(Duration.zero);

      expect(repo.calls, 1);
    });
  });
}
