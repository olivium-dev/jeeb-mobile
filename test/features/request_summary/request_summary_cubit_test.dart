import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/request_summary/application/request_summary_cubit.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';

import '../../support/fake_request_submission_service.dart';

const _draft = RequestDraft(description: 'A package to Verdun', tierId: 'flash');

/// Raises something that is NOT a [RequestSubmissionException] — the parser
/// TypeError that used to escape the cubit and pin `isSubmitting`.
class _ThrowingSubmissionService implements RequestSubmissionService {
  const _ThrowingSubmissionService();

  @override
  Future<String> submit(RequestDraft draft) async => throw TypeError();
}

void main() {
  group('RequestSummaryCubit.submit — T-MOB-REQSUBMIT', () {
    test('does nothing when there is no draft', () async {
      final service = FakeRequestSubmissionService();
      final cubit = RequestSummaryCubit(service);

      await cubit.submit();

      expect(service.submitCount, 0);
      expect(cubit.state.isSubmitting, isFalse);
      expect(cubit.state.isSubmitted, isFalse);
      await cubit.close();
    });

    blocTest<RequestSummaryCubit, RequestSummaryState>(
      'emits isSubmitting then isSubmitted with the server request id on success',
      build: () => RequestSummaryCubit(
        FakeRequestSubmissionService(requestId: 'req-server-99'),
      )..setDraft(_draft),
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<RequestSummaryState>()
            .having((s) => s.isSubmitting, 'isSubmitting', isTrue)
            .having((s) => s.isSubmitted, 'isSubmitted', isFalse)
            .having((s) => s.error, 'error', isNull),
        isA<RequestSummaryState>()
            .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
            .having((s) => s.isSubmitted, 'isSubmitted', isTrue)
            .having((s) => s.requestId, 'requestId', 'req-server-99')
            .having((s) => s.error, 'error', isNull),
      ],
    );

    test('forwards the assembled draft to the service', () async {
      final service = FakeRequestSubmissionService();
      final cubit = RequestSummaryCubit(service)..setDraft(_draft);

      await cubit.submit();

      expect(service.submitCount, 1);
      expect(service.lastDraft?.description, _draft.description);
      expect(service.lastDraft?.tierId, 'flash');
      await cubit.close();
    });

    blocTest<RequestSummaryCubit, RequestSummaryState>(
      'emits isSubmitting then a user-facing error on network failure '
      '(not isSubmitted)',
      build: () => RequestSummaryCubit(
        FakeRequestSubmissionService(
          error: const RequestSubmissionException(
            RequestSubmissionFailure.network,
          ),
        ),
      )..setDraft(_draft),
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<RequestSummaryState>()
            .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
        isA<RequestSummaryState>()
            .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
            .having((s) => s.isSubmitted, 'isSubmitted', isFalse)
            .having((s) => s.error, 'error', isA<NetworkFailure>()),
      ],
    );

    // EP-06: the cubit carries the CLASSIFIED failure, never prose — the copy
    // is chosen by `failureCopy` at the widget, in the user's locale.
    blocTest<RequestSummaryCubit, RequestSummaryState>(
      'carries a distinct AppFailure kind for a server failure',
      build: () => RequestSummaryCubit(
        FakeRequestSubmissionService(
          error: const RequestSubmissionException.classified(
            RequestSubmissionFailure.server,
            appFailure: ServerFailure(status: 503),
          ),
        ),
      )..setDraft(_draft),
      act: (cubit) => cubit.submit(),
      skip: 1,
      expect: () => [
        isA<RequestSummaryState>()
            .having((s) => s.isSubmitted, 'isSubmitted', isFalse)
            .having(
              (s) => s.error,
              'error',
              const ServerFailure(status: 503),
            ),
      ],
    );

    // EP-23: a TypeError out of the response parser used to escape the cubit
    // and pin `isSubmitting` forever.
    blocTest<RequestSummaryCubit, RequestSummaryState>(
      'classifies a non-RequestSubmissionException and clears isSubmitting',
      build: () => RequestSummaryCubit(
        const _ThrowingSubmissionService(),
      )..setDraft(_draft),
      act: (cubit) => cubit.submit(),
      skip: 1,
      expect: () => [
        isA<RequestSummaryState>()
            .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
            .having((s) => s.error, 'error', isA<UnknownFailure>()),
      ],
    );

    // AE-01: a 409 requires-ack is its own branch, not a generic failure.
    blocTest<RequestSummaryCubit, RequestSummaryState>(
      'a moderation 409 carries the flagged keywords, not a blocked flag',
      build: () => RequestSummaryCubit(
        FakeRequestSubmissionService(
          error: const RequestModerationRequired(
            matches: <String>['knife'],
            appFailure: ConflictFailure(),
          ),
        ),
      )..setDraft(_draft),
      act: (cubit) => cubit.submit(),
      skip: 1,
      expect: () => [
        isA<RequestSummaryState>()
            .having((s) => s.moderationMatches, 'matches', <String>['knife'])
            .having((s) => s.moderationBlocked, 'blocked', isFalse)
            .having((s) => s.isSubmitted, 'isSubmitted', isFalse),
      ],
    );

    blocTest<RequestSummaryCubit, RequestSummaryState>(
      'a moderation 409 BLOCKED is terminal',
      build: () => RequestSummaryCubit(
        FakeRequestSubmissionService(
          error: const RequestModerationRequired(
            matches: <String>['firearm'],
            blocked: true,
            appFailure: ConflictFailure(),
          ),
        ),
      )..setDraft(_draft),
      act: (cubit) => cubit.submit(),
      skip: 1,
      expect: () => [
        isA<RequestSummaryState>()
            .having((s) => s.moderationBlocked, 'blocked', isTrue),
      ],
    );

    // AE-04: a 422's per-field messages must survive onto the state.
    blocTest<RequestSummaryCubit, RequestSummaryState>(
      'a ValidationFailure carries its fieldErrors onto the state',
      build: () => RequestSummaryCubit(
        FakeRequestSubmissionService(
          error: const RequestSubmissionException.classified(
            RequestSubmissionFailure.invalidInput,
            appFailure: ValidationFailure(
              fieldErrors: <String, List<String>>{
                'description': <String>['Too short'],
              },
            ),
          ),
        ),
      )..setDraft(_draft),
      act: (cubit) => cubit.submit(),
      skip: 1,
      expect: () => [
        isA<RequestSummaryState>().having(
          (s) => s.fieldErrors['description'],
          'fieldErrors[description]',
          <String>['Too short'],
        ),
      ],
    );

    test('ignores a second submit while one is already in flight', () async {
      final service = FakeRequestSubmissionService();
      final cubit = RequestSummaryCubit(service)..setDraft(_draft);

      final first = cubit.submit();
      // Second call observes isSubmitting == true synchronously and bails.
      await cubit.submit();
      await first;

      expect(service.submitCount, 1);
      await cubit.close();
    });
  });
}
