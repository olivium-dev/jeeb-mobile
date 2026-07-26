import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/lifecycle/app_lifecycle_gate.dart';
import 'package:jeeb_mobile/features/home_client/application/client_home_cubit.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';

const _pollInterval = Duration(seconds: 10);
const _backgroundWindow = Duration(seconds: 30);

class _CountingClientHomeRepository implements ClientHomeRepository {
  int fetchCount = 0;

  @override
  Future<ClientHomeSnapshot> loadSnapshot() async {
    fetchCount++;
    return const ClientHomeSnapshot();
  }
}

void main() {
  tearDown(AppLifecycleGate.debugReset);

  test('AC1: ClientHomeCubit adopts LifecyclePoller lifecycle gating', () {
    FakeAsync().run((async) {
      final repository = _CountingClientHomeRepository();
      final gate = ManualAppLifecycleGate();
      AppLifecycleGate.install(gate);
      final cubit = ClientHomeCubit(
        repository: repository,
        greetingNameProvider: () => 'Sami',
        pollInterval: _pollInterval,
      );

      cubit.startPolling();
      async.elapse(_pollInterval);
      async.flushMicrotasks();
      expect(
        repository.fetchCount,
        1,
        reason: 'the foreground control proves the cubit poll is active',
      );

      gate.setForeground(false);
      final backgroundBaseline = repository.fetchCount;
      async.elapse(_backgroundWindow);
      async.flushMicrotasks();
      expect(
        repository.fetchCount,
        backgroundBaseline,
        reason: 'the injected gate must stop ClientHomeCubit polling',
      );

      gate.setForeground(true);
      expect(
        repository.fetchCount,
        backgroundBaseline,
        reason: 'foregrounding only re-arms a fresh polling interval',
      );
      async.elapse(_pollInterval);
      async.flushMicrotasks();
      expect(
        repository.fetchCount,
        backgroundBaseline + 1,
        reason: 'the cubit poll must resume through LifecyclePoller',
      );

      unawaited(cubit.close());
      async.flushMicrotasks();
    });
  });
}
