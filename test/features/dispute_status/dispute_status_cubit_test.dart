// Unit tests for DisputeStatusCubit (JM-065). Proves the 4-state machine:

import 'package:flutter_test/flutter_test.dart';
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
    final repo =
        _ScriptedRepository(fetchThrows: DisputeStatusFailure.notFound);
    final cubit = DisputeStatusCubit(repository: repo, disputeId: 'dsp-1');

    await cubit.load();

    expect(cubit.state.status, DisputeStatusViewStatus.failed);
    expect(cubit.state.error, DisputeStatusFailure.notFound);
    await cubit.close();
  });

  test('refresh recovers from a failed cold load', () async {
    final repo =
        _ScriptedRepository(fetchThrows: DisputeStatusFailure.network);
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
}
