import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/request_summary/application/request_summary_cubit.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';

import '../../support/fake_request_submission_service.dart';

const _draft = RequestDraft(description: 'A package to Verdun', tierId: 'flash');

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
            .having((s) => s.error, 'error', isNotNull)
            .having((s) => s.error, 'error', contains('connection')),
      ],
    );

    blocTest<RequestSummaryCubit, RequestSummaryState>(
      'surfaces a distinct message for a server failure',
      build: () => RequestSummaryCubit(
        FakeRequestSubmissionService(
          error: const RequestSubmissionException(
            RequestSubmissionFailure.server,
          ),
        ),
      )..setDraft(_draft),
      act: (cubit) => cubit.submit(),
      skip: 1,
      expect: () => [
        isA<RequestSummaryState>()
            .having((s) => s.isSubmitted, 'isSubmitted', isFalse)
            .having((s) => s.error, 'error', 'Something went wrong. '
                'Please try again.'),
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
