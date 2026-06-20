// Tests for MaskedCallCubit (orders-masked-call).
//
// Verifies the call flow: request a masked-call session from the gateway, then
// dial the returned proxy number via the native dialer. Covers success, a
// gateway failure, a network failure, and a dialer-unavailable outcome.

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/masked_call/application/masked_call_cubit.dart';
import 'package:jeeb_mobile/features/masked_call/domain/masked_call_repository.dart';
import 'package:jeeb_mobile/features/masked_call/domain/phone_dialer.dart';

class _FakeRepo implements MaskedCallRepository {
  _FakeRepo({this.session, this.failure});

  final MaskedCallSession? session;
  final MaskedCallFailure? failure;
  String? requestedOrderId;

  @override
  Future<MaskedCallSession> requestSession({required String orderId}) async {
    requestedOrderId = orderId;
    final f = failure;
    if (f != null) throw MaskedCallException(f);
    return session ??
        const MaskedCallSession(
          sessionId: 'sess-1',
          proxyNumber: '+96170000000',
        );
  }
}

class _FakeDialer implements PhoneDialer {
  _FakeDialer({this.result = true});

  final bool result;
  String? dialed;

  @override
  Future<bool> dial(String phoneNumber) async {
    dialed = phoneNumber;
    return result;
  }
}

void main() {
  test('success: requests session then dials the proxy number', () async {
    final repo = _FakeRepo(
      session: const MaskedCallSession(
        sessionId: 's1',
        proxyNumber: '+9613111222',
      ),
    );
    final dialer = _FakeDialer();
    final cubit = MaskedCallCubit(repository: repo, dialer: dialer);

    await cubit.initiateCall('order-9');

    expect(repo.requestedOrderId, 'order-9');
    expect(dialer.dialed, '+9613111222');
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.error, isNull);
    expect(cubit.state.session?.sessionId, 's1');
    await cubit.close();
  });

  test('gateway unavailable: emits unavailable error, no dial', () async {
    final repo = _FakeRepo(failure: MaskedCallFailure.unavailable);
    final dialer = _FakeDialer();
    final cubit = MaskedCallCubit(repository: repo, dialer: dialer);

    await cubit.initiateCall('order-1');

    expect(dialer.dialed, isNull);
    expect(cubit.state.error, 'maskedCallErrorUnavailable');
    expect(cubit.state.isLoading, isFalse);
    await cubit.close();
  });

  test('network failure: emits network error', () async {
    final repo = _FakeRepo(failure: MaskedCallFailure.network);
    final cubit = MaskedCallCubit(repository: repo, dialer: _FakeDialer());

    await cubit.initiateCall('order-1');

    expect(cubit.state.error, 'maskedCallErrorNetwork');
    await cubit.close();
  });

  test('dialer unavailable: session kept but dialer error surfaced', () async {
    final repo = _FakeRepo();
    final dialer = _FakeDialer(result: false);
    final cubit = MaskedCallCubit(repository: repo, dialer: dialer);

    await cubit.initiateCall('order-1');

    expect(cubit.state.error, 'maskedCallErrorDialer');
    expect(cubit.state.session, isNotNull);
    await cubit.close();
  });
}
