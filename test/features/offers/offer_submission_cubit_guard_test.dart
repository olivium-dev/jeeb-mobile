// LR-03/UX-14/EP-09: the composer cubit cannot double-post, cannot hang, and
// carries no English sentence out of the application layer.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/offers/application/offer_submission_cubit.dart';
import 'package:jeeb_mobile/features/offers/domain/offer_submission_repository.dart';

/// Counts calls; never answers.
class _StallingRepo implements OfferSubmissionRepository {
  int callCount = 0;

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) {
    callCount++;
    return Completer<OfferSubmissionResult>().future;
  }
}

/// Throws the untyped error `_parseResult` raises on a wrong-typed body.
class _RawThrowRepo implements OfferSubmissionRepository {
  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async =>
      throw TypeError();
}

/// Records the idempotency key it was handed.
class _IdempotentRepo
    implements OfferSubmissionRepository, IdempotentOfferSubmission {
  String? seenKey;
  int callCount = 0;

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async {
    callCount++;
    return const OfferSubmissionResult(offerId: 'o', conversationId: 'c');
  }

  @override
  Future<OfferSubmissionResult> submitOfferIdempotent({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    required String idempotencyKey,
    String? note,
  }) async {
    callCount++;
    seenKey = idempotencyKey;
    return const OfferSubmissionResult(offerId: 'o', conversationId: 'c');
  }
}

void main() {
  test('a second submit while one is in flight performs ZERO extra repository '
      'calls', () async {
    final repo = _StallingRepo();
    final cubit = OfferFormCubit(repository: repo);

    unawaited(cubit.submit(requestId: 'r', priceUsd: 5, etaMinutes: 10));
    await cubit.submit(requestId: 'r', priceUsd: 5, etaMinutes: 10);
    await cubit.submit(requestId: 'r', priceUsd: 5, etaMinutes: 10);

    expect(repo.callCount, 1);
    expect(cubit.state.mode, OfferFormMode.submitting);
    await cubit.close();
  });

  test('a raw TypeError lands the error rung with a classified failure, never '
      'a hung submitting', () async {
    final cubit = OfferFormCubit(repository: _RawThrowRepo());

    await cubit.submit(requestId: 'r', priceUsd: 5, etaMinutes: 10);

    expect(cubit.state.mode, OfferFormMode.error);
    expect(cubit.state.failure, isNotNull);
    expect(cubit.state.isSubmitting, isFalse);
    await cubit.close();
  });

  test('EP-09: the state carries NO String error field', () {
    const state = OfferFormState();
    // priceError/etaError/noteError are REASON CODES, not sentences.
    expect(state.props.whereType<String>(), isEmpty);
    expect(state.failure, isNull);
    expect(state.errorReason, isNull);
  });

  test('NET-12: the draft key reaches an idempotent repository verbatim',
      () async {
    final repo = _IdempotentRepo();
    final cubit = OfferFormCubit(repository: repo);

    await cubit.submit(
      requestId: 'r',
      priceUsd: 5,
      etaMinutes: 10,
      idempotencyKey: 'draft-key-7',
    );

    expect(repo.seenKey, 'draft-key-7');
    expect(repo.callCount, 1);
    await cubit.close();
  });

  test('a repository without the idempotent capability still submits',
      () async {
    final repo = _StallingRepo();
    final cubit = OfferFormCubit(repository: repo);

    unawaited(cubit.submit(
      requestId: 'r',
      priceUsd: 5,
      etaMinutes: 10,
      idempotencyKey: 'draft-key-7',
    ));
    await Future<void>.delayed(Duration.zero);

    expect(repo.callCount, 1);
    await cubit.close();
  });

  test('acknowledgeError clears both the mode and every field reason',
      () async {
    final cubit = OfferFormCubit(
      repository: _ThrowingRepo(OfferSubmissionFailure.feeTooLow),
    );

    await cubit.submit(requestId: 'r', priceUsd: 5, etaMinutes: 10);
    expect(cubit.state.priceError, OfferFormState.priceErrorTooLow);

    cubit.acknowledgeError();
    expect(cubit.state.mode, OfferFormMode.idle);
    expect(cubit.state.priceError, isNull);
    expect(cubit.state.failure, isNull);
    await cubit.close();
  });
}

class _ThrowingRepo implements OfferSubmissionRepository {
  _ThrowingRepo(this.failure);

  final OfferSubmissionFailure failure;

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async =>
      throw OfferSubmissionException(failure);
}
