// Tests for MutualRatingCubit (JM-034).

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/rating/application/mutual_rating_cubit.dart';
import 'package:jeeb_mobile/features/rating/application/mutual_rating_state.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';

class _FakeRatingRepo implements RatingRepository {
  const _FakeRatingRepo({this.failSubmit = false});

  final bool failSubmit;

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {
    if (failSubmit) throw Exception('network error');
  }

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async {
    return RatingStatus(
      deliveryId: deliveryId,
      revealState: RatingRevealState.pendingTheirs,
    );
  }
}

void main() {
  group('MutualRatingCubit — setStars', () {
    test('emits updated stars', () {
      final cubit = MutualRatingCubit(
        repository: const _FakeRatingRepo(),
        deliveryId: 'dlv-1',
        isClient: true,
      );
      cubit.setStars(4);
      expect(cubit.state.stars, 4);
      cubit.close();
    });
  });

  group('MutualRatingCubit — submit', () {
    blocTest<MutualRatingCubit, MutualRatingState>(
      'does nothing when stars=0',
      build: () => MutualRatingCubit(
        repository: const _FakeRatingRepo(),
        deliveryId: 'dlv-1',
        isClient: true,
      ),
      act: (c) => c.submit(),
      expect: () => [],
    );

    blocTest<MutualRatingCubit, MutualRatingState>(
      'emits submitting → submitted on success (mandatory terminal)',
      build: () {
        final c = MutualRatingCubit(
          repository: const _FakeRatingRepo(),
          deliveryId: 'dlv-1',
          isClient: true,
        );
        c.setStars(4);
        return c;
      },
      act: (c) => c.submit(),
      expect: () => [
        predicate<MutualRatingState>(
          (s) => s.phase == MutualRatingPhase.submitting,
          'submitting phase',
        ),
        predicate<MutualRatingState>(
          (s) => s.phase == MutualRatingPhase.submitted,
          'submitted phase',
        ),
      ],
    );

    blocTest<MutualRatingCubit, MutualRatingState>(
      'emits error when submit throws',
      build: () {
        final c = MutualRatingCubit(
          repository: const _FakeRatingRepo(failSubmit: true),
          deliveryId: 'dlv-1',
          isClient: true,
        );
        c.setStars(3);
        return c;
      },
      act: (c) => c.submit(),
      expect: () => [
        predicate<MutualRatingState>((s) => s.phase == MutualRatingPhase.submitting),
        predicate<MutualRatingState>(
          (s) => s.phase == MutualRatingPhase.error,
          'error phase after failed submit',
        ),
      ],
    );
  });

  group('MutualRatingCubit — toggleTag', () {
    test('adds then removes a tag', () {
      final cubit = MutualRatingCubit(
        repository: const _FakeRatingRepo(),
        deliveryId: 'dlv-1',
        isClient: true,
      );
      cubit.toggleTag('Friendly');
      expect(cubit.state.tags, contains('Friendly'));
      cubit.toggleTag('Friendly');
      expect(cubit.state.tags, isNot(contains('Friendly')));
      cubit.close();
    });
  });

  group('MutualRatingCubit — loadCounterpart', () {
    MutualRatingCubit build({
      required bool isClient,
      OrderChatSummaryRepository? repo,
    }) =>
        MutualRatingCubit(
          repository: const _FakeRatingRepo(),
          deliveryId: 'dlv-1',
          isClient: isClient,
          counterpartRepository: repo,
        );

    test('client leg resolves the JEEBER name + avatar', () async {
      final cubit = build(isClient: true, repo: const _FakeSummaryRepo());
      await cubit.loadCounterpart();
      expect(cubit.state.counterpartName, 'Karim');
      expect(cubit.state.counterpartAvatarUrl, 'http://gw.test/j.png');
      await cubit.close();
    });

    test('jeeber leg resolves the CLIENT name + avatar', () async {
      final cubit = build(isClient: false, repo: const _FakeSummaryRepo());
      await cubit.loadCounterpart();
      expect(cubit.state.counterpartName, 'Nour');
      expect(cubit.state.counterpartAvatarUrl, 'http://gw.test/c.png');
      await cubit.close();
    });

    test('a throwing repository is swallowed — identity is decoration and must '
        'never error or block the mandatory rating', () async {
      final cubit = build(isClient: true, repo: const _ThrowingSummaryRepo());
      await cubit.loadCounterpart();
      expect(cubit.state.phase, MutualRatingPhase.inputting);
      expect(cubit.state.counterpartName, '');
      expect(cubit.state.counterpartAvatarUrl, '');
      await cubit.close();
    });

    test('no-ops when no repository is supplied', () async {
      final cubit = build(isClient: true);
      await cubit.loadCounterpart();
      expect(cubit.state, const MutualRatingState());
      await cubit.close();
    });

    test('does not emit after close', () async {
      final cubit = build(isClient: true, repo: const _SlowSummaryRepo());
      final pending = cubit.loadCounterpart();
      await cubit.close();
      await pending;
      expect(cubit.state.counterpartName, '');
    });
  });
}

const _summary = OrderChatSummary(
  deliveryId: 'dlv-1',
  jeeberName: 'Karim',
  jeeberAvatarUrl: 'http://gw.test/j.png',
  clientName: 'Nour',
  clientAvatarUrl: 'http://gw.test/c.png',
);

class _FakeSummaryRepo implements OrderChatSummaryRepository {
  const _FakeSummaryRepo();
  @override
  Future<OrderChatSummary> fetchSummary(String deliveryId) async => _summary;
}

class _ThrowingSummaryRepo implements OrderChatSummaryRepository {
  const _ThrowingSummaryRepo();
  @override
  Future<OrderChatSummary> fetchSummary(String deliveryId) async =>
      throw const OrderChatSummaryException(OrderChatSummaryFailure.network);
}

class _SlowSummaryRepo implements OrderChatSummaryRepository {
  const _SlowSummaryRepo();
  @override
  Future<OrderChatSummary> fetchSummary(String deliveryId) async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return _summary;
  }
}
