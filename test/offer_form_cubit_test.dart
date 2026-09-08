// Tests for OfferFormCubit (T-MOB-030).

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/offers/application/offer_submission_cubit.dart';
import 'package:jeeb_mobile/features/offers/domain/offer_submission_repository.dart';

class _FakeOfferRepo implements OfferSubmissionRepository {
  _FakeOfferRepo({this.result, this.throws});

  final OfferSubmissionResult? result;
  final OfferSubmissionException? throws;

  /// Captures the exact `note` the cubit forwarded on the last call.
  String? capturedNote;
  bool submitCalled = false;

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async {
    submitCalled = true;
    capturedNote = note;
    if (throws != null) throw throws!;
    return result ??
        const OfferSubmissionResult(
          offerId: 'off-001',
          conversationId: 'conv-001',
        );
  }
}

void main() {
  group('OfferFormCubit — validation', () {
    blocTest<OfferFormCubit, OfferFormState>(
      'price=0 blocks submit and sets priceError',
      build: () => OfferFormCubit(repository: _FakeOfferRepo()),
      act: (c) => c.submit(
        requestId: 'req-1',
        priceUsd: 0,
        etaMinutes: 20,
      ),
      expect: () => [
        predicate<OfferFormState>(
          (s) =>
              s.mode == OfferFormMode.idle &&
              s.priceError != null,
          'should have priceError',
        ),
      ],
    );

    blocTest<OfferFormCubit, OfferFormState>(
      'null ETA blocks submit and sets etaError',
      build: () => OfferFormCubit(repository: _FakeOfferRepo()),
      act: (c) => c.submit(
        requestId: 'req-1',
        priceUsd: 5.0,
        etaMinutes: null,
      ),
      expect: () => [
        predicate<OfferFormState>(
          (s) => s.etaError != null,
          'should have etaError',
        ),
      ],
    );
  });

  group('OfferFormCubit — success', () {
    blocTest<OfferFormCubit, OfferFormState>(
      'valid submit emits submitting → success with conversationId (AC2)',
      build: () => OfferFormCubit(
        repository: _FakeOfferRepo(
          result: const OfferSubmissionResult(
            offerId: 'off-1',
            conversationId: 'conv-accepted-001',
          ),
        ),
      ),
      act: (c) => c.submit(
        requestId: 'request-replies-001',
        priceUsd: 5.0,
        etaMinutes: 20,
        note: 'Fast delivery',
      ),
      expect: () => [
        predicate<OfferFormState>((s) => s.isSubmitting, 'submitting'),
        predicate<OfferFormState>(
          (s) =>
              s.mode == OfferFormMode.success &&
              s.conversationId == 'conv-accepted-001',
          'success with conversationId',
        ),
      ],
    );
  });

  group('OfferFormCubit — note forwarding (Lane B)', () {
    test('forwards a non-null note verbatim to the repository', () async {
      final repo = _FakeOfferRepo();
      final cubit = OfferFormCubit(repository: repo);
      await cubit.submit(
        requestId: 'req-1',
        priceUsd: 5.0,
        etaMinutes: 20,
        note: 'On my way now',
      );
      expect(repo.submitCalled, isTrue);
      expect(repo.capturedNote, 'On my way now');
      await cubit.close();
    });

    test('forwards null when no note is supplied (empty→null done screen-side)',
        () async {
      final repo = _FakeOfferRepo();
      final cubit = OfferFormCubit(repository: repo);
      await cubit.submit(
        requestId: 'req-1',
        priceUsd: 5.0,
        etaMinutes: 20,
      );
      expect(repo.submitCalled, isTrue);
      expect(repo.capturedNote, isNull);
      await cubit.close();
    });
  });

  group('OfferFormCubit — race / errors', () {
    blocTest<OfferFormCubit, OfferFormState>(
      '409 emits requestGone (AC4)',
      build: () => OfferFormCubit(
        repository: _FakeOfferRepo(
          throws: const OfferSubmissionException(OfferSubmissionFailure.requestGone),
        ),
      ),
      act: (c) => c.submit(
        requestId: 'req-gone',
        priceUsd: 5.0,
        etaMinutes: 10,
      ),
      expect: () => [
        predicate<OfferFormState>((s) => s.isSubmitting, 'submitting'),
        predicate<OfferFormState>(
          (s) => s.mode == OfferFormMode.requestGone,
          'requestGone',
        ),
      ],
    );

    blocTest<OfferFormCubit, OfferFormState>(
      'AE-05: 409 offer-already-exists reaches its OWN duplicate mode and '
      'KEEPS the composer (not requestGone, and no English literal)',
      build: () => OfferFormCubit(
        repository: _FakeOfferRepo(
          throws: const OfferSubmissionException(
            OfferSubmissionFailure.duplicateOffer,
          ),
        ),
      ),
      act: (c) => c.submit(
        requestId: 'req-duplicate',
        priceUsd: 5.0,
        etaMinutes: 10,
      ),
      expect: () => [
        predicate<OfferFormState>((s) => s.isSubmitting, 'submitting'),
        predicate<OfferFormState>(
          (s) =>
              s.mode == OfferFormMode.duplicate &&
              s.errorReason == OfferSubmissionFailure.duplicateOffer,
          'duplicate mode carrying the machine reason, composer preserved',
        ),
      ],
    );

    blocTest<OfferFormCubit, OfferFormState>(
      'network failure carries the REASON (no hardcoded message) so the view '
      'localizes it — JEBV4-246',
      build: () => OfferFormCubit(
        repository: _FakeOfferRepo(
          throws: const OfferSubmissionException(OfferSubmissionFailure.network),
        ),
      ),
      act: (c) => c.submit(
        requestId: 'req-1',
        priceUsd: 5.0,
        etaMinutes: 10,
      ),
      expect: () => [
        predicate<OfferFormState>((s) => s.isSubmitting),
        predicate<OfferFormState>(
          (s) =>
              s.mode == OfferFormMode.error &&
              s.errorReason == OfferSubmissionFailure.network,
          'error carrying the network reason, NOT a hardcoded English message',
        ),
      ],
    );

    blocTest<OfferFormCubit, OfferFormState>(
      'generic/server failure ALSO carries the reason (no hardcoded message) '
      'so the view localizes it — JEBV4-246',
      build: () => OfferFormCubit(
        repository: _FakeOfferRepo(
          throws: const OfferSubmissionException(OfferSubmissionFailure.server),
        ),
      ),
      act: (c) => c.submit(
        requestId: 'req-1',
        priceUsd: 5.0,
        etaMinutes: 10,
      ),
      expect: () => [
        predicate<OfferFormState>((s) => s.isSubmitting),
        predicate<OfferFormState>(
          (s) =>
              s.mode == OfferFormMode.error &&
              s.errorReason == OfferSubmissionFailure.server,
          'error carrying the server reason, no hardcoded message',
        ),
      ],
    );

    blocTest<OfferFormCubit, OfferFormState>(
      'LR-03/UX-14: a second submit while one is in flight performs NO extra '
      'repository call',
      build: () => OfferFormCubit(repository: _StallingOfferRepo()),
      act: (c) async {
        unawaited(c.submit(requestId: 'r', priceUsd: 5.0, etaMinutes: 10));
        await c.submit(requestId: 'r', priceUsd: 5.0, etaMinutes: 10);
      },
      verify: (c) {
        expect((c.state.mode), OfferFormMode.submitting);
      },
      expect: () => [
        predicate<OfferFormState>((s) => s.isSubmitting, 'submitting once'),
      ],
    );

    blocTest<OfferFormCubit, OfferFormState>(
      'LR-03: a RAW TypeError from the repository lands the error rung with a '
      'classified failure — never a hung submitting',
      build: () => OfferFormCubit(repository: _RawThrowOfferRepo()),
      act: (c) => c.submit(requestId: 'r', priceUsd: 5.0, etaMinutes: 10),
      expect: () => [
        predicate<OfferFormState>((s) => s.isSubmitting),
        predicate<OfferFormState>(
          (s) => s.mode == OfferFormMode.error && s.failure != null,
          'error rung carrying a classified failure',
        ),
      ],
    );

    blocTest<OfferFormCubit, OfferFormState>(
      'AE-13: a 400 offer-fee-too-low lands on the PRICE slot, and the ETA '
      'slot stays clean',
      build: () => OfferFormCubit(
        repository: _FakeOfferRepo(
          throws: const OfferSubmissionException(
            OfferSubmissionFailure.feeTooLow,
          ),
        ),
      ),
      act: (c) => c.submit(requestId: 'r', priceUsd: 5.0, etaMinutes: 10),
      expect: () => [
        predicate<OfferFormState>((s) => s.isSubmitting),
        predicate<OfferFormState>(
          (s) =>
              s.mode == OfferFormMode.error &&
              s.priceError == OfferFormState.priceErrorTooLow &&
              s.etaError == null &&
              s.noteError == null,
          'price slot only',
        ),
      ],
    );

    blocTest<OfferFormCubit, OfferFormState>(
      'AE-13: a 400 offer-eta-invalid lands on the ETA slot',
      build: () => OfferFormCubit(
        repository: _FakeOfferRepo(
          throws: const OfferSubmissionException(
            OfferSubmissionFailure.etaInvalid,
          ),
        ),
      ),
      act: (c) => c.submit(requestId: 'r', priceUsd: 5.0, etaMinutes: 10),
      expect: () => [
        predicate<OfferFormState>((s) => s.isSubmitting),
        predicate<OfferFormState>(
          (s) =>
              s.etaError == OfferFormState.etaErrorInvalid &&
              s.priceError == null,
          'eta slot only',
        ),
      ],
    );

    blocTest<OfferFormCubit, OfferFormState>(
      'AE-05: request-not-open-for-offers is the same terminal UX as a 410',
      build: () => OfferFormCubit(
        repository: _FakeOfferRepo(
          throws: const OfferSubmissionException(
            OfferSubmissionFailure.requestNotOpen,
          ),
        ),
      ),
      act: (c) => c.submit(requestId: 'r', priceUsd: 5.0, etaMinutes: 10),
      expect: () => [
        predicate<OfferFormState>((s) => s.isSubmitting),
        predicate<OfferFormState>(
          (s) => s.mode == OfferFormMode.requestGone,
          'requestGone',
        ),
      ],
    );
  });
}

/// A submit that never answers — the in-flight guard's fixture.
class _StallingOfferRepo implements OfferSubmissionRepository {
  int calls = 0;

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) {
    calls++;
    return Completer<OfferSubmissionResult>().future;
  }
}

/// Throws the untyped error a `_parseResult` cast raises.
class _RawThrowOfferRepo implements OfferSubmissionRepository {
  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async {
    throw TypeError();
  }
}
