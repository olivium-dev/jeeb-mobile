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

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async {
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
      'network failure emits error mode',
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
              s.mode == OfferFormMode.error && s.errorMessage != null,
          'error with message',
        ),
      ],
    );
  });
}
