// Tests for EscalateCubit (T-MOB-022).
//
// Verifies:
//   - submit transitions inputting → submitting → success with caseId.
//   - submit without reason is a no-op.
//   - network error emits error phase with network kind.
//   - 409 already-open emits error with alreadyOpen kind.
//   - retryFromError restores inputting phase.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/escalate/application/escalate_cubit.dart';
import 'package:jeeb_mobile/features/escalate/application/escalate_state.dart';
import 'package:jeeb_mobile/features/escalate/domain/escalate_repository.dart';

class _FakeEscalateRepo implements EscalateRepository {
  const _FakeEscalateRepo({this.failWith});

  final EscalateErrorKind? failWith;

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const [],
  }) async {
    if (failWith != null) throw EscalateException(failWith!);
    return const EscalateResult(caseId: 'case-001', status: 'open');
  }
}

void main() {
  group('EscalateCubit — submit', () {
    blocTest<EscalateCubit, EscalateState>(
      'no-op when reason is null',
      build: () => EscalateCubit(
        repository: const _FakeEscalateRepo(),
        deliveryId: 'dlv-1',
      ),
      act: (c) => c.submit(),
      expect: () => [],
    );

    blocTest<EscalateCubit, EscalateState>(
      'emits submitting → success with caseId',
      build: () {
        final c = EscalateCubit(
          repository: const _FakeEscalateRepo(),
          deliveryId: 'dlv-1',
        );
        c.setReason(EscalateReason.damaged);
        return c;
      },
      act: (c) => c.submit(),
      expect: () => [
        predicate<EscalateState>(
          (s) => s.phase == EscalatePhase.submitting,
          'submitting',
        ),
        predicate<EscalateState>(
          (s) => s.phase == EscalatePhase.success && s.caseId == 'case-001',
          'success with caseId',
        ),
      ],
    );

    blocTest<EscalateCubit, EscalateState>(
      'emits error with network kind on network failure',
      build: () {
        final c = EscalateCubit(
          repository: const _FakeEscalateRepo(failWith: EscalateErrorKind.network),
          deliveryId: 'dlv-1',
        );
        c.setReason(EscalateReason.fraud);
        return c;
      },
      act: (c) => c.submit(),
      expect: () => [
        predicate<EscalateState>((s) => s.phase == EscalatePhase.submitting),
        predicate<EscalateState>(
          (s) =>
              s.phase == EscalatePhase.error &&
              s.errorKind == EscalateErrorKind.network,
          'network error',
        ),
      ],
    );

    blocTest<EscalateCubit, EscalateState>(
      'emits alreadyOpen error kind on 409',
      build: () {
        final c = EscalateCubit(
          repository: const _FakeEscalateRepo(
            failWith: EscalateErrorKind.alreadyOpen,
          ),
          deliveryId: 'dlv-1',
        );
        c.setReason(EscalateReason.abuse);
        return c;
      },
      act: (c) => c.submit(),
      expect: () => [
        predicate<EscalateState>((s) => s.phase == EscalatePhase.submitting),
        predicate<EscalateState>(
          (s) =>
              s.phase == EscalatePhase.error &&
              s.errorKind == EscalateErrorKind.alreadyOpen,
          'alreadyOpen error',
        ),
      ],
    );
  });

  group('EscalateCubit — retryFromError', () {
    blocTest<EscalateCubit, EscalateState>(
      'restores inputting phase',
      build: () {
        final c = EscalateCubit(
          repository: const _FakeEscalateRepo(failWith: EscalateErrorKind.server),
          deliveryId: 'dlv-1',
        );
        c.setReason(EscalateReason.other);
        return c;
      },
      act: (c) async {
        await c.submit();
        c.retryFromError();
      },
      expect: () => [
        predicate<EscalateState>((s) => s.phase == EscalatePhase.submitting),
        predicate<EscalateState>((s) => s.phase == EscalatePhase.error),
        predicate<EscalateState>(
          (s) => s.phase == EscalatePhase.inputting,
          'back to inputting',
        ),
      ],
    );
  });

  group('EscalateCubit — photo management', () {
    test('addPhoto appends path up to limit', () {
      final c = EscalateCubit(
        repository: const _FakeEscalateRepo(),
        deliveryId: 'dlv-1',
      );
      for (var i = 0; i < 6; i++) {
        c.addPhoto('photo_$i.jpg');
      }
      expect(c.state.photoPaths.length, 5);
      c.close();
    });

    test('removePhoto removes path', () {
      final c = EscalateCubit(
        repository: const _FakeEscalateRepo(),
        deliveryId: 'dlv-1',
      );
      c.addPhoto('p1.jpg');
      c.removePhoto('p1.jpg');
      expect(c.state.photoPaths, isEmpty);
      c.close();
    });
  });
}
