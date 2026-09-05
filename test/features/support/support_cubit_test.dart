// Unit tests for SupportCubit (JM-063).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/idempotency/operation_id.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/support/application/support_cubit.dart';
import 'package:jeeb_mobile/features/support/application/support_state.dart';
import 'package:jeeb_mobile/features/support/domain/support_repository.dart';

class _RecordingRepo implements SupportRepository {
  _RecordingRepo({this.failWith, this.appFailure});
  SupportFailure? failWith;
  AppFailure? appFailure;
  SupportTicketDraft? lastDraft;
  final List<SupportTicketDraft> drafts = <SupportTicketDraft>[];

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async {
    lastDraft = draft;
    drafts.add(draft);
    if (failWith != null) {
      throw SupportRepositoryException.classified(
        failWith!,
        appFailure: appFailure,
      );
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
      expect(
        repo.lastDraft!.body,
        'driver never arrived',
        reason: 'body is trimmed',
      );
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

    test(
      'typed failure → error phase, then retry actually re-submits',
      () async {
        final repo = _RecordingRepo(failWith: SupportFailure.network);
        final cubit = SupportCubit(repo);
        cubit.setCategory(SupportCategory.payment);
        cubit.setBody('charge issue');

        await cubit.submit();
        expect(cubit.state.phase, SupportPhase.error);
        expect(cubit.state.failure, SupportFailure.network);
        // The classified failure rides alongside the feature enum.
        expect(cubit.state.appFailure, isNotNull);

        repo.failWith = null;
        await cubit.retryFromError();
        expect(cubit.state.phase, SupportPhase.success);
        expect(cubit.state.failure, isNull);
        expect(cubit.state.appFailure, isNull);
        expect(repo.drafts, hasLength(2));
        // The form fields survive the retry.
        expect(cubit.state.category, SupportCategory.payment);
        expect(cubit.state.body, 'charge issue');
        cubit.close();
      },
    );

    test(
      'a terminal failure returns to the form WITHOUT re-submitting',
      () async {
        final repo = _RecordingRepo(
          failWith: SupportFailure.unauthorized,
          appFailure: const UnauthorizedFailure(),
        );
        final cubit = SupportCubit(repo);
        cubit.setCategory(SupportCategory.payment);
        cubit.setBody('charge issue');

        await cubit.submit();
        expect(cubit.state.phase, SupportPhase.error);

        await cubit.retryFromError();
        expect(cubit.state.phase, SupportPhase.inputting);
        expect(
          repo.drafts,
          hasLength(1),
          reason: 'a 401 is never re-POSTed by the Retry CTA',
        );
        cubit.close();
      },
    );

    test('operation id survives submit → error → retry → submit', () async {
      final repo = _RecordingRepo(failWith: SupportFailure.network);
      final cubit = SupportCubit(repo);
      cubit.setCategory(SupportCategory.payment);
      cubit.setBody('charged twice for one delivery');
      final operationId = cubit.state.operationId;
      expect(isOperationId(operationId), isTrue);

      await cubit.submit();
      expect(cubit.state.phase, SupportPhase.error);

      repo.failWith = null;
      await cubit.retryFromError();
      expect(cubit.state.phase, SupportPhase.success);

      expect(cubit.state.operationId, operationId);
      expect(repo.drafts, hasLength(2));
      expect(
        repo.drafts.map((draft) => draft.operationId),
        everyElement(operationId),
        reason: 'the retry must reuse the first attempt Idempotency-Key',
      );
      cubit.close();
    });

    test(
      'submit ignores reentrant taps and does not emit after close',
      () async {
        final repo = _PendingRepo();
        final cubit = SupportCubit(repo);
        cubit.setCategory(SupportCategory.account);
        cubit.setBody('Please help.');

        final first = cubit.submit();
        final second = cubit.submit();
        expect(repo.calls, 1);
        await cubit.close();
        repo.complete();
        await Future.wait(<Future<void>>[first, second]);

        expect(repo.calls, 1);
      },
    );
  });
}

class _PendingRepo implements SupportRepository {
  final Completer<SupportTicket> _result = Completer<SupportTicket>();
  int calls = 0;

  void complete() {
    _result.complete(const SupportTicket(id: 'ticket-1', status: 'pending'));
  }

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) {
    calls++;
    return _result.future;
  }
}
