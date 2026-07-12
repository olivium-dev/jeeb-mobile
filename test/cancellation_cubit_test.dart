import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/cancellation/domain/cancellation_repository.dart';
import 'package:jeeb_mobile/features/cancellation/domain/cancellation_result.dart';
import 'package:jeeb_mobile/features/cancellation/presentation/cubit/cancellation_cubit.dart';
import 'package:jeeb_mobile/features/cancellation/presentation/cubit/cancellation_state.dart';

/// Fake repository for test injection.
class _FakeCancellationRepository implements CancellationRepository {
  _FakeCancellationRepository({required this.behavior});

  final Future<CancellationResult> Function() behavior;

  @override
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) =>
      behavior();
}

CancellationResult _fakeResult() => const CancellationResult(
      deliveryId: 'DLV-770013',
      weeklyCount: 4,
    );

Future<CancellationResult> _succeed() async => _fakeResult();

Future<CancellationResult> _tooLate() async {
  throw const CancellationTooLateException();
}

Future<CancellationResult> _networkError() async {
  throw const CancellationException('network error');
}

void main() {
  const kId = 'DLV-770013';

  group('CancellationCubit — T-MOB-024', () {
    test('initial state is CancellationIdle', () {
      final cubit = CancellationCubit(
        _FakeCancellationRepository(behavior: _succeed),
      );
      expect(cubit.state, isA<CancellationIdle>());
    });

    test('submit transitions through Loading → Success on 200', () async {
      final cubit = CancellationCubit(
        _FakeCancellationRepository(behavior: _succeed),
      );
      // Verify final state is Success after await completes.
      await cubit.submit(deliveryId: kId, reason: 'changed_mind');
      expect(cubit.state, isA<CancellationSuccess>());
    });

    test('Success result carries the server payload (JEBV4-183: fee-free)',
        () async {
      final cubit = CancellationCubit(
        _FakeCancellationRepository(behavior: _succeed),
      );
      await cubit.submit(deliveryId: kId, reason: 'changed_mind');
      final state = cubit.state as CancellationSuccess;
      expect(state.result.deliveryId, 'DLV-770013');
      expect(state.result.weeklyCount, 4);
    });

    test('submit emits TooLate on 409', () async {
      final cubit = CancellationCubit(
        _FakeCancellationRepository(behavior: _tooLate),
      );
      await cubit.submit(deliveryId: kId, reason: 'changed_mind');
      expect(cubit.state, isA<CancellationTooLate>());
    });

    test('submit emits Error on network failure', () async {
      final cubit = CancellationCubit(
        _FakeCancellationRepository(behavior: _networkError),
      );
      await cubit.submit(deliveryId: kId, reason: 'changed_mind');
      expect(cubit.state, isA<CancellationError>());
    });

    test('reset returns to Idle', () async {
      final cubit = CancellationCubit(
        _FakeCancellationRepository(behavior: _networkError),
      );
      await cubit.submit(deliveryId: kId, reason: 'changed_mind');
      cubit.reset();
      expect(cubit.state, isA<CancellationIdle>());
    });

    test('second submit while Loading is a no-op', () async {
      var callCount = 0;
      final cubit = CancellationCubit(
        _FakeCancellationRepository(
          behavior: () async {
            callCount++;
            return _fakeResult();
          },
        ),
      );

      // ignore: unawaited_futures — intentional concurrent submit race
      cubit.submit(deliveryId: kId, reason: 'x');
      await cubit.submit(deliveryId: kId, reason: 'x');

      expect(callCount, 1);
    });
  });
}
