// JEBV4-296 regression guard — the mutual-rating quick-tag chips rendered

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/rating/application/mutual_rating_cubit.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/features/rating/presentation/mutual_rating_screen.dart';

import '../../support/sync_app_localizations.dart';

class _FakeRatingRepo implements RatingRepository {
  const _FakeRatingRepo();

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
      const RatingStatus(
        deliveryId: 'dlv-1',
        revealState: RatingRevealState.pendingTheirs,
      );
}

void main() {
  late MutualRatingCubit cubit;

  setUp(() {
    cubit = MutualRatingCubit(
      repository: const _FakeRatingRepo(),
      deliveryId: 'dlv-1',
      isClient: true,
    );
  });

  tearDown(() => cubit.close());

  Future<void> pump(WidgetTester tester, {required Locale locale}) async {
    await tester.pumpWidget(
      wrapForTest(
        BlocProvider<MutualRatingCubit>.value(
          value: cubit,
          child: const MutualRatingScreen(),
        ),
        locale: locale,
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'ar locale: all five tag chips render the localized Arabic labels',
    (tester) async {
      await pump(tester, locale: const Locale('ar'));

      expect(find.text('دقيق بالمواعيد'), findsOneWidget); // punctuality
      expect(find.text('التواصل'), findsOneWidget); // communication
      expect(find.text('حريص'), findsOneWidget); // package_condition
      expect(find.text('ودود'), findsOneWidget); // courtesy
      expect(find.text('الملاحة'), findsOneWidget); // navigation
    },
  );

  testWidgets(
    'ar locale: the hardcoded English chip labels no longer leak',
    (tester) async {
      await pump(tester, locale: const Locale('ar'));

      expect(find.text('Punctual'), findsNothing);
      expect(find.text('Communication'), findsNothing);
      expect(find.text('Careful'), findsNothing);
      expect(find.text('Friendly'), findsNothing);
      expect(find.text('Navigation'), findsNothing);
    },
  );

  testWidgets(
    'en locale: tag chips still render the English labels (no regression)',
    (tester) async {
      await pump(tester, locale: const Locale('en'));

      expect(find.text('Punctual'), findsOneWidget);
      expect(find.text('Communication'), findsOneWidget);
      expect(find.text('Careful'), findsOneWidget);
      expect(find.text('Friendly'), findsOneWidget);
      expect(find.text('Navigation'), findsOneWidget);
    },
  );

  testWidgets(
    'ar locale: tapping the localized chip toggles the CANONICAL gateway '
    'taxonomy wire value in cubit state (l10n must not change the backend '
    'contract established by JEBV4-297)',
    (tester) async {
      await pump(tester, locale: const Locale('ar'));

      await tester.tap(find.text('ودود')); // "Friendly" -> `courtesy`
      await tester.pump();

      expect(cubit.state.tags, contains('courtesy'));
      expect(cubit.state.tags, isNot(contains('ودود')));
      expect(cubit.state.tags, isNot(contains('Friendly')));
    },
  );
}
