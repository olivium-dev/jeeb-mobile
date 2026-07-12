// Tests for OfferFormCubit (T-MOB-030).
//
// Verifies:
//   - AC2: Successful submit emits success with conversationId.
//   - AC3: Price ≤ 0 blocks submit and sets inline priceError.
//   - AC4: Server 409 emits requestGone mode.
//   - Network failure emits error mode.

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
      'offer-cap (409 offer-cap-reached) emits a DISTINCT error message and '
      'KEEPS the composer (not requestGone)',
      build: () => OfferFormCubit(
        repository: _FakeOfferRepo(
          throws: const OfferSubmissionException(
            OfferSubmissionFailure.offerCapReached,
          ),
        ),
      ),
      act: (c) => c.submit(
        requestId: 'req-capped',
        priceUsd: 5.0,
        etaMinutes: 10,
      ),
      expect: () => [
        predicate<OfferFormState>((s) => s.isSubmitting, 'submitting'),
        predicate<OfferFormState>(
          (s) =>
              s.mode == OfferFormMode.error &&
              s.errorMessage != null &&
              s.errorMessage!.contains('20'),
          'error mode with the offer-cap message (mentions the 20 limit), '
              'composer preserved',
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
              s.errorReason == OfferSubmissionFailure.network &&
              s.errorMessage == null,
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
              s.errorReason == OfferSubmissionFailure.server &&
              s.errorMessage == null,
          'error carrying the server reason, no hardcoded message',
        ),
      ],
    );
  });
}
