import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/domain/prohibited_acknowledgment_repository.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/domain/prohibited_item.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/presentation/cubit/prohibited_acknowledgment_cubit.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/presentation/cubit/prohibited_acknowledgment_state.dart';

/// Fake repo for testing.
class _FakeRepo implements ProhibitedAcknowledgmentRepository {
  _FakeRepo({
    this.items = _kItems,
    this.alreadyAcknowledged = false,
    this.acknowledgeThrows = false,
  });

  static const _kItems = [
    ProhibitedItem(id: 'arak', name: 'Arak'),
    ProhibitedItem(id: 'knife', name: 'Knife', severity: ProhibitedItemSeverity.warn),
  ];

  final List<ProhibitedItem> items;
  final bool alreadyAcknowledged;
  final bool acknowledgeThrows;

  bool localSaved = false;

  @override
  Future<List<ProhibitedItem>> fetchItems() async => items;

  @override
  Future<void> acknowledge() async {
    if (acknowledgeThrows) throw Exception('server error');
  }

  @override
  Future<bool> hasAcknowledged() async => alreadyAcknowledged;

  @override
  Future<void> saveLocalAcknowledgment() async => localSaved = true;
}

void main() {
  group('ProhibitedAcknowledgmentCubit', () {
    test('initial state is initial status', () {
      final cubit = ProhibitedAcknowledgmentCubit(repository: _FakeRepo());
      expect(cubit.state.status, ProhibitedAckStatus.initial);
      cubit.close();
    });

    blocTest<ProhibitedAcknowledgmentCubit, ProhibitedAcknowledgmentState>(
      'load emits loading then loaded with items',
      build: () => ProhibitedAcknowledgmentCubit(repository: _FakeRepo()),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<ProhibitedAcknowledgmentState>()
            .having((s) => s.status, 'status', ProhibitedAckStatus.loading),
        isA<ProhibitedAcknowledgmentState>()
            .having((s) => s.status, 'status', ProhibitedAckStatus.loaded)
            .having((s) => s.items.length, 'items.length', 2),
      ],
    );

    blocTest<ProhibitedAcknowledgmentCubit, ProhibitedAcknowledgmentState>(
      'load emits acknowledged immediately when already acked (AC2)',
      build: () => ProhibitedAcknowledgmentCubit(
        repository: _FakeRepo(alreadyAcknowledged: true),
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<ProhibitedAcknowledgmentState>()
            .having((s) => s.status, 'status', ProhibitedAckStatus.loading),
        isA<ProhibitedAcknowledgmentState>()
            .having((s) => s.status, 'status', ProhibitedAckStatus.acknowledged),
      ],
    );

    blocTest<ProhibitedAcknowledgmentCubit, ProhibitedAcknowledgmentState>(
      'acknowledge emits acknowledging then acknowledged and saves locally',
      build: () => ProhibitedAcknowledgmentCubit(repository: _FakeRepo()),
      seed: () => const ProhibitedAcknowledgmentState(
        status: ProhibitedAckStatus.loaded,
        items: [ProhibitedItem(id: 'arak', name: 'Arak')],
      ),
      act: (cubit) => cubit.acknowledge(),
      expect: () => [
        isA<ProhibitedAcknowledgmentState>()
            .having((s) => s.status, 'status', ProhibitedAckStatus.acknowledging),
        isA<ProhibitedAcknowledgmentState>()
            .having((s) => s.status, 'status', ProhibitedAckStatus.acknowledged),
      ],
    );

    blocTest<ProhibitedAcknowledgmentCubit, ProhibitedAcknowledgmentState>(
      'acknowledge still acks locally when server call throws',
      build: () => ProhibitedAcknowledgmentCubit(
        repository: _FakeRepo(acknowledgeThrows: true),
      ),
      seed: () => const ProhibitedAcknowledgmentState(
        status: ProhibitedAckStatus.loaded,
        items: [ProhibitedItem(id: 'arak', name: 'Arak')],
      ),
      act: (cubit) => cubit.acknowledge(),
      expect: () => [
        isA<ProhibitedAcknowledgmentState>()
            .having((s) => s.status, 'status', ProhibitedAckStatus.acknowledging),
        isA<ProhibitedAcknowledgmentState>()
            .having((s) => s.status, 'status', ProhibitedAckStatus.acknowledged),
      ],
    );

    blocTest<ProhibitedAcknowledgmentCubit, ProhibitedAcknowledgmentState>(
      'load emits error when fetchItems throws',
      build: () {
        final repo = _FakeErrorRepo();
        return ProhibitedAcknowledgmentCubit(repository: repo);
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<ProhibitedAcknowledgmentState>()
            .having((s) => s.status, 'status', ProhibitedAckStatus.loading),
        isA<ProhibitedAcknowledgmentState>()
            .having((s) => s.status, 'status', ProhibitedAckStatus.error),
      ],
    );
  });
}

class _FakeErrorRepo implements ProhibitedAcknowledgmentRepository {
  @override
  Future<List<ProhibitedItem>> fetchItems() => Future.error(Exception('fail'));

  @override
  Future<void> acknowledge() async {}

  @override
  Future<bool> hasAcknowledged() async => false;

  @override
  Future<void> saveLocalAcknowledgment() async {}
}
