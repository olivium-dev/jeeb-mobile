// Unit tests for SupportCubit (JM-063).

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/support/application/support_cubit.dart';
import 'package:jeeb_mobile/features/support/application/support_state.dart';
import 'package:jeeb_mobile/features/support/domain/support_repository.dart';

class _RecordingRepo implements SupportRepository {
  _RecordingRepo({this.failWith});
  final SupportFailure? failWith;
  SupportTicketDraft? lastDraft;

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async {
    lastDraft = draft;
    if (failWith != null) {
      throw SupportRepositoryException(failWith!);
    }
    return const SupportTicket(id: 'ticket-001', status: 'open');
  }
}

void main() {
  group('SupportCubit', () {
    test('initial state is inputting with no category and cannot submit', () {
      final cubit = SupportCubit(_RecordingRepo());
      expect(cubit.state.phase, SupportPhase.inputting);
      expect(cubit.state.category, isNull);
      expect(cubit.state.canSubmit, isFalse);
      cubit.close();
    });

    test('initialOrderRef seeds the draft order ref', () {
      final cubit = SupportCubit(_RecordingRepo(), initialOrderRef: 'ORD-42');
      expect(cubit.state.orderRef, 'ORD-42');
      cubit.close();
    });

    test('canSubmit requires a category AND a non-empty body', () {
      final cubit = SupportCubit(_RecordingRepo());
      cubit.setBody('   ');
      expect(cubit.state.canSubmit, isFalse, reason: 'blank body');
      cubit.setBody('app keeps crashing');
      expect(cubit.state.canSubmit, isFalse, reason: 'no category yet');
      cubit.setCategory(SupportCategory.account);
      expect(cubit.state.canSubmit, isTrue);
      cubit.close();
    });

    test('attachments cap at 5 (canAttach gate)', () {
      final cubit = SupportCubit(_RecordingRepo());
      for (var i = 0; i < 7; i++) {
        cubit.addAttachment('a$i.jpg');
      }
      expect(cubit.state.attachmentPaths.length, 5);
      expect(cubit.state.canAttach, isFalse);
      cubit.removeAttachment('a0.jpg');
      expect(cubit.state.attachmentPaths.length, 4);
      expect(cubit.state.canAttach, isTrue);
      cubit.close();
    });

    test('setOrderRef trims and clears on empty', () {
      final cubit = SupportCubit(_RecordingRepo());
      cubit.setOrderRef('  ORD-9  ');
      expect(cubit.state.orderRef, 'ORD-9');
      cubit.setOrderRef('   ');
      expect(cubit.state.orderRef, isNull);
      cubit.close();
    });

    test('submit builds the draft and transitions to success', () async {
      final repo = _RecordingRepo();
      final cubit = SupportCubit(repo, initialOrderRef: 'ORD-7');
      cubit.setCategory(SupportCategory.dispute);
      cubit.setBody('  driver never arrived  ');
      cubit.addAttachment('evidence.jpg');

      await cubit.submit();

      expect(cubit.state.phase, SupportPhase.success);
      expect(cubit.state.ticketId, 'ticket-001');
      expect(repo.lastDraft, isNotNull);
      expect(repo.lastDraft!.category, SupportCategory.dispute);
      expect(repo.lastDraft!.body, 'driver never arrived',
          reason: 'body is trimmed');
      expect(repo.lastDraft!.orderRef, 'ORD-7');
      expect(repo.lastDraft!.attachmentPaths, <String>['evidence.jpg']);
      cubit.close();
    });

    test('submit is a no-op when canSubmit is false', () async {
      final repo = _RecordingRepo();
      final cubit = SupportCubit(repo);
      await cubit.submit();
      expect(cubit.state.phase, SupportPhase.inputting);
      expect(repo.lastDraft, isNull);
      cubit.close();
    });

    test('typed failure → error phase, then retry returns to inputting',
        () async {
      final cubit = SupportCubit(_RecordingRepo(failWith: SupportFailure.network));
      cubit.setCategory(SupportCategory.payment);
      cubit.setBody('charge issue');

      await cubit.submit();
      expect(cubit.state.phase, SupportPhase.error);
      expect(cubit.state.failure, SupportFailure.network);

      cubit.retryFromError();
      expect(cubit.state.phase, SupportPhase.inputting);
      expect(cubit.state.failure, isNull);
      // The form fields survive the retry.
      expect(cubit.state.category, SupportCategory.payment);
      expect(cubit.state.body, 'charge issue');
      cubit.close();
    });
  });
}
