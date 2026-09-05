// Unit tests for DisputeStatusCubit (JM-065). Proves the 4-state machine:

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/dispute_status/application/dispute_status_cubit.dart';
import 'package:jeeb_mobile/features/dispute_status/application/dispute_status_state.dart';
import 'package:jeeb_mobile/features/dispute_status/domain/dispute_status_repository.dart';

class _ScriptedRepository implements DisputeStatusRepository {
  _ScriptedRepository({this.dispute, this.fetchThrows});

  DisputeStatus? dispute;
  DisputeStatusFailure? fetchThrows;
  int calls = 0;

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async {
    calls++;
    final f = fetchThrows;
    if (f != null) throw DisputeStatusRepositoryException(f);
    return dispute!;
  }
}

DisputeStatus _dispute(String id) =>
    DisputeStatus(id: id, state: DisputeState.open);

void main() {
  test('load emits loading → loaded on success', () async {
    final repo = _ScriptedRepository(dispute: _dispute('dsp-1'));
    final cubit = DisputeStatusCubit(repository: repo, disputeId: 'dsp-1');

    // Assert the emission ORDER via the canonical bloc-stream matcher. A bare
    final expectation = expectLater(
      cubit.stream.map((s) => s.status),
      emitsInOrder(<DisputeStatusViewStatus>[
        DisputeStatusViewStatus.loading,
        DisputeStatusViewStatus.loaded,
      ]),
    );

    await cubit.load();
    await expectation;

    expect(cubit.state.dispute?.id, 'dsp-1');
    await cubit.close();
  });

  test('load guards re-entry (no double fetch)', () async {
    final repo = _ScriptedRepository(dispute: _dispute('dsp-1'));
    final cubit = DisputeStatusCubit(repository: repo, disputeId: 'dsp-1');

    await cubit.load();
    await cubit.load();

    expect(repo.calls, 1);
    await cubit.close();
  });

  test('blank id short-circuits to not-found without a repo call', () async {
    final repo = _ScriptedRepository(dispute: _dispute('dsp-1'));
    final cubit = DisputeStatusCubit(repository: repo, disputeId: '   ');

    await cubit.load();

    expect(cubit.state.status, DisputeStatusViewStatus.failed);
    expect(cubit.state.error, DisputeStatusFailure.notFound);
    expect(repo.calls, 0);
    await cubit.close();
  });

  test('typed failure surfaces as failed + the typed error', () async {
    final repo = _ScriptedRepository(
      fetchThrows: DisputeStatusFailure.notFound,
    );
    final cubit = DisputeStatusCubit(repository: repo, disputeId: 'dsp-1');

    await cubit.load();

    expect(cubit.state.status, DisputeStatusViewStatus.failed);
    expect(cubit.state.error, DisputeStatusFailure.notFound);
    await cubit.close();
  });

  test('refresh recovers from a failed cold load', () async {
    final repo = _ScriptedRepository(fetchThrows: DisputeStatusFailure.network);
    final cubit = DisputeStatusCubit(repository: repo, disputeId: 'dsp-1');

    await cubit.load();
    expect(cubit.state.status, DisputeStatusViewStatus.failed);

    // The network heals; refresh re-fetches and loads.
    repo.fetchThrows = null;
    repo.dispute = _dispute('dsp-1');
    await cubit.refresh();

    expect(cubit.state.status, DisputeStatusViewStatus.loaded);
    expect(cubit.state.error, isNull);
    await cubit.close();
  });

  test('a refresh failure over a loaded dispute keeps it (WP7-N1)', () async {
    final repo = _ScriptedRepository(dispute: _dispute('dsp-1'));
    final cubit = DisputeStatusCubit(repository: repo, disputeId: 'dsp-1');
    await cubit.load();
    expect(cubit.state.status, DisputeStatusViewStatus.loaded);

    repo.fetchThrows = DisputeStatusFailure.network;
    await cubit.refresh();

    expect(cubit.state.status, DisputeStatusViewStatus.loaded);
    expect(cubit.state.dispute, isNotNull);
    expect(cubit.state.refreshError, isNotNull);
    cubit.acknowledgeRefreshError();
    expect(cubit.state.refreshError, isNull);
    await cubit.close();
  });

  test('load() can run again from failed (the cold retry path)', () async {
    final repo = _ScriptedRepository(
      dispute: _dispute('dsp-1'),
      fetchThrows: DisputeStatusFailure.network,
    );
    final cubit = DisputeStatusCubit(repository: repo, disputeId: 'dsp-1');
    await cubit.load();
    expect(cubit.state.status, DisputeStatusViewStatus.failed);

    repo.fetchThrows = null;
    await cubit.load();

    expect(cubit.state.status, DisputeStatusViewStatus.loaded);
    expect(repo.calls, 2);
    await cubit.close();
  });

  test('a blank id is terminal, and carries a NotFoundFailure', () async {
    final repo = _ScriptedRepository(dispute: _dispute('dsp-1'));
    final cubit = DisputeStatusCubit(repository: repo, disputeId: '  ');
    await cubit.load();

    expect(cubit.state.status, DisputeStatusViewStatus.failed);
    expect(cubit.state.failure, isA<NotFoundFailure>());
    expect(cubit.state.failure!.isRetryable, isFalse);
    await cubit.close();
  });

  test('a completed fetch does not emit after the cubit closes', () async {
    final repo = _PendingRepository();
    final cubit = DisputeStatusCubit(repository: repo, disputeId: 'dsp-1');

    final load = cubit.load();
    expect(repo.calls, 1);
    await cubit.close();
    repo.complete(_dispute('dsp-1'));
    await load;

    expect(repo.calls, 1);
  });
}

class _PendingRepository implements DisputeStatusRepository {
  final Completer<DisputeStatus> _result = Completer<DisputeStatus>();
  int calls = 0;

  void complete(DisputeStatus dispute) => _result.complete(dispute);

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) {
    calls++;
    return _result.future;
  }
}
