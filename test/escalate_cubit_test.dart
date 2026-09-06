// Tests for EscalateCubit (JM-060 dispute-open-evidence; ex T-MOB-022).

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/escalate/application/escalate_cubit.dart';
import 'package:jeeb_mobile/features/escalate/application/escalate_state.dart';
import 'package:jeeb_mobile/features/escalate/domain/escalate_repository.dart';

class _FakeEscalateRepo implements EscalateRepository {
  const _FakeEscalateRepo({this.failWith});

  final EscalateErrorKind? failWith;

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) async =>
      EscalateEvidence.empty;

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const [],
    String? voicePath,
    EscalateEvidence evidence = EscalateEvidence.empty,
  }) async {
    if (failWith != null) throw EscalateException(failWith!);
    return const EscalateResult(caseId: 'dispute-001', status: 'open');
  }
}

/// A repository that DOES serve an evidence preview (the ES-15 gate).
class _PreviewEscalateRepo extends _FakeEscalateRepo
    implements EscalateEvidencePreviewRepository {
  const _PreviewEscalateRepo({this.evidence, this.previewThrows = false});

  final EscalateEvidence? evidence;
  final bool previewThrows;

  @override
  Future<EscalateEvidence> previewEvidence({
    required String deliveryId,
  }) async {
    if (previewThrows) throw Exception('boom');
    return evidence ?? EscalateEvidence.empty;
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
      'emits submitting → success with dispute id as caseId',
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
          (s) => s.phase == EscalatePhase.success && s.caseId == 'dispute-001',
          'success with dispute id',
        ),
      ],
    );

    blocTest<EscalateCubit, EscalateState>(
      'emits error with network kind on network failure',
      build: () {
        final c = EscalateCubit(
          repository: const _FakeEscalateRepo(
            failWith: EscalateErrorKind.network,
          ),
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

    test('ignores reentrant submit and does not emit after close', () async {
      final repository = _PendingEscalateRepo();
      final cubit = EscalateCubit(repository: repository, deliveryId: 'dlv-1')
        ..setReason(EscalateReason.damaged);

      final first = cubit.submit();
      final second = cubit.submit();
      expect(repository.calls, 1);
      await cubit.close();
      repository.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(repository.calls, 1);
    });
  });

  group('EscalateCubit — retryFromError', () {
    blocTest<EscalateCubit, EscalateState>(
      'restores inputting phase',
      build: () {
        final c = EscalateCubit(
          repository: const _FakeEscalateRepo(
            failWith: EscalateErrorKind.server,
          ),
          deliveryId: 'dlv-1',
        );
        c.setReason(EscalateReason.other);
        return c;
      },
      act: (c) async {
        await c.submit();
        await c.retryFromError();
      },
      // A retryable failure re-submits with the SAME operationId (ESC-06), so
      // the retry replays submitting → error rather than stopping at the form.
      expect: () => [
        predicate<EscalateState>((s) => s.phase == EscalatePhase.submitting),
        predicate<EscalateState>((s) => s.phase == EscalatePhase.error),
        predicate<EscalateState>(
          (s) => s.phase == EscalatePhase.inputting,
          'back to inputting',
        ),
        predicate<EscalateState>((s) => s.phase == EscalatePhase.submitting),
        predicate<EscalateState>((s) => s.phase == EscalatePhase.error),
      ],
    );

    blocTest<EscalateCubit, EscalateState>(
      'a terminal failure returns to the form without re-submitting',
      build: () {
        final c = EscalateCubit(
          repository: const _FakeEscalateRepo(
            failWith: EscalateErrorKind.notFound,
          ),
          deliveryId: 'dlv-1',
        );
        c.setReason(EscalateReason.other);
        return c;
      },
      act: (c) async {
        await c.submit();
        // A NotFound failure is not retryable, so this must not fire again.
        c.emit(
          c.state.copyWith(failure: const NotFoundFailure()),
        );
        await c.retryFromError();
      },
      expect: () => [
        predicate<EscalateState>((s) => s.phase == EscalatePhase.submitting),
        predicate<EscalateState>((s) => s.phase == EscalatePhase.error),
        predicate<EscalateState>((s) => s.failure is NotFoundFailure),
        predicate<EscalateState>(
          (s) => s.phase == EscalatePhase.inputting,
          'back to inputting, no re-submit',
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

  group('EscalateCubit — voice evidence (D53)', () {
    test('setVoice attaches a clip path; clearVoice removes it', () {
      final c = EscalateCubit(
        repository: const _FakeEscalateRepo(),
        deliveryId: 'dlv-1',
      );
      c.setVoice('voice.m4a');
      expect(c.state.hasVoice, isTrue);
      c.clearVoice();
      expect(c.state.hasVoice, isFalse);
      c.close();
    });

    test('setVoice ignores an empty path', () {
      final c = EscalateCubit(
        repository: const _FakeEscalateRepo(),
        deliveryId: 'dlv-1',
      );
      c.setVoice('');
      expect(c.state.hasVoice, isFalse);
      c.close();
    });
  });

  group('EscalateCubit — auto-attached evidence (D53)', () {
    blocTest<EscalateCubit, EscalateState>(
      'loadEvidence resolves the snapshot + timeline',
      build: () => EscalateCubit(
        repository: const _PreviewEscalateRepo(
          evidence: EscalateEvidence(
            chatSnapshotUrl: 'https://cdn.jeeb.app/snapshots/conv-1.html',
            chatMessageCount: 4,
            timeline: [
              EscalateTimelineEntry(status: 'Ordered'),
              EscalateTimelineEntry(status: 'InTransit'),
            ],
          ),
        ),
        deliveryId: 'dlv-1',
      ),
      act: (c) => c.loadEvidence(),
      expect: () => [
        predicate<EscalateState>(
          (s) => s.evidenceLoading && !s.evidenceLoaded,
          'preview in flight',
        ),
        predicate<EscalateState>(
          (s) =>
              s.evidenceLoaded &&
              !s.evidenceLoading &&
              !s.evidenceLoadFailed &&
              s.evidence.hasChatSnapshot &&
              s.evidence.timeline.length == 2,
          'evidence loaded with snapshot + timeline',
        ),
      ],
    );

    blocTest<EscalateCubit, EscalateState>(
      'a failed preview is evidenceLoadFailed, never a fake empty (ESC-08)',
      build: () => EscalateCubit(
        repository: const _PreviewEscalateRepo(previewThrows: true),
        deliveryId: 'dlv-1',
      ),
      act: (c) => c.loadEvidence(),
      expect: () => [
        predicate<EscalateState>((s) => s.evidenceLoading, 'preview in flight'),
        predicate<EscalateState>(
          (s) =>
              s.evidenceLoadFailed && !s.evidenceLoaded && s.failure != null,
          'failed, and NOT reported as loaded-empty',
        ),
      ],
    );

    blocTest<EscalateCubit, EscalateState>(
      'a repository with no preview endpoint emits nothing at all',
      build: () => EscalateCubit(
        repository: const _FakeEscalateRepo(),
        deliveryId: 'dlv-1',
      ),
      act: (c) => c.loadEvidence(),
      expect: () => <EscalateState>[],
    );
  });
}

class _PendingEscalateRepo implements EscalateRepository {
  final Completer<EscalateResult> _result = Completer<EscalateResult>();
  int calls = 0;

  void complete() {
    _result.complete(
      const EscalateResult(caseId: 'dispute-1', status: 'pending'),
    );
  }

  @override
  Future<EscalateEvidence> fetchEvidence({required String deliveryId}) async {
    return EscalateEvidence.empty;
  }

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const <String>[],
    String? voicePath,
    EscalateEvidence evidence = EscalateEvidence.empty,
  }) {
    calls++;
    return _result.future;
  }
}
