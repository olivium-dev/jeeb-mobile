// Isolated native UI test — MutualRatingScreen (canonical mutual-rating
// terminal, JM-034). The screen is a StatelessWidget that reads its
// MutualRatingCubit from the tree (no self-provider), so we wrap it in a
// BlocProvider.value over a cubit driven by an in-memory RatingRepository.
// Router.maybeOf(context) is null under the harness's plain MaterialApp, so the
// screen returns its scope directly (no BackButtonListener needed).
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/rating/application/mutual_rating_cubit.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/features/rating/presentation/mutual_rating_screen.dart';

import '../support/screen_harness.dart';

/// No-op rating repo — a successful submit is fire-and-forget on this terminal.
class _NoopRatingRepo implements RatingRepository {
  const _NoopRatingRepo();
  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {}
  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async =>
      throw UnimplementedError();
}

/// Always-failing repo so a submit lands the cubit in the error phase.
class _ThrowingRatingRepo implements RatingRepository {
  const _ThrowingRatingRepo();
  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async =>
      throw const RatingRepositoryException(RatingFailure.network);
  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async =>
      throw UnimplementedError();
}

MutualRatingCubit _cubit(RatingRepository repo) => MutualRatingCubit(
      repository: repo,
      deliveryId: 'del-client-001',
      isClient: true,
    );

Widget _host(MutualRatingCubit cubit) => BlocProvider<MutualRatingCubit>.value(
      value: cubit,
      child: const MutualRatingScreen(),
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mutual-rating: inputting (en)', (tester) async {
    final cubit = _cubit(const _NoopRatingRepo())..setStars(4);
    addTearDown(cubit.close);
    await pumpAndShoot(tester, binding, _host(cubit), 'mutual-rating__input');
  });

  testWidgets('mutual-rating: inputting (ar)', (tester) async {
    final cubit = _cubit(const _NoopRatingRepo())..setStars(5);
    addTearDown(cubit.close);
    await pumpAndShoot(
      tester,
      binding,
      _host(cubit),
      'mutual-rating__input-ar',
      locale: const Locale('ar'),
    );
  });

  testWidgets('mutual-rating: submit failure error state (en)', (tester) async {
    final cubit = _cubit(const _ThrowingRatingRepo())..setStars(4);
    addTearDown(cubit.close);
    await cubit.submit(); // drives inputting → submitting → error
    await pumpAndShoot(tester, binding, _host(cubit), 'mutual-rating__error');
  });
}
