// redesign-2026-08 screen 15 — the rebuilt mutual-rating INPUT view.
//
// Covers only what the redesign added; the frozen contract ids are already
// pinned by `qa_keys_batch_test.dart` (B-5) and `decision_violations_test.dart`
// (D56), and the chip wire contract by
// `mutual_rating_tag_wire_contract_test.dart`. This file asserts:
//
//   a. the star VERDICT word maps 1..5 and is absent at 0 stars;
//   b. the HEADLINE resolves named → role-aware fallback, in both roles, with
//      no `{name}` placeholder leaking;
//   c. the new `mutual_rating_blind_note` / `mutual_rating_ratee_avatar` ids
//      surface in both locales;
//   d. an `ar` smoke: the screen lays out mirrored with no exception and every
//      frozen id survives.
//
// NOTE (integrator): this file compiles only once the `l10n` block of
// `docs/redesign-2026-08/wiring/15-mutual-rating.md` has landed — the screen
// calls ten `AppLocalizations` members that the ARB files do not carry yet.

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

MutualRatingCubit _cubit({required bool isClient}) => MutualRatingCubit(
      repository: const _FakeRatingRepo(),
      deliveryId: 'dlv-1',
      isClient: isClient,
    );

Future<void> _pump(
  WidgetTester tester, {
  required MutualRatingCubit cubit,
  Locale locale = const Locale('en'),
  String rateeName = '',
}) async {
  await tester.pumpWidget(
    wrapForTest(
      BlocProvider<MutualRatingCubit>.value(
        value: cubit,
        child: MutualRatingScreen(rateeName: rateeName),
      ),
      locale: locale,
    ),
  );
  await tester.pump();
}

void main() {
  group('star verdict', () {
    testWidgets('0 stars renders no verdict word at all', (tester) async {
      final cubit = _cubit(isClient: true);
      addTearDown(cubit.close);

      await _pump(tester, cubit: cubit);

      for (final word in const <String>[
        'Poor',
        'Fair',
        'Okay',
        'Great',
        'Excellent',
      ]) {
        expect(
          find.text(word),
          findsNothing,
          reason: 'no rating selected yet — the verdict line must not render',
        );
      }
    });

    testWidgets('4 stars renders the EN verdict pinned by the board',
        (tester) async {
      final cubit = _cubit(isClient: true);
      addTearDown(cubit.close);

      await _pump(tester, cubit: cubit);
      cubit.setStars(4);
      // Two pumps, not one: the cubit is driven from outside the widget, so
      // the BlocConsumer's stream listener fires on a microtask AFTER the
      // frame this first pump builds. The second frame is the one that
      // carries the new state.
      await tester.pump();
      await tester.pump();

      expect(find.text('Great'), findsOneWidget);
    });

    testWidgets('4 stars renders the AR verdict', (tester) async {
      final cubit = _cubit(isClient: true);
      addTearDown(cubit.close);

      await _pump(tester, cubit: cubit, locale: const Locale('ar'));
      cubit.setStars(4);
      // Two pumps, not one: the cubit is driven from outside the widget, so
      // the BlocConsumer's stream listener fires on a microtask AFTER the
      // frame this first pump builds. The second frame is the one that
      // carries the new state.
      await tester.pump();
      await tester.pump();

      expect(find.text('رائع'), findsOneWidget);
      expect(
        find.text('Great'),
        findsNothing,
        reason: 'the verdict must not leak English under ar',
      );
    });

    testWidgets('every 1..5 selection renders exactly one verdict word',
        (tester) async {
      final cubit = _cubit(isClient: true);
      addTearDown(cubit.close);

      await _pump(tester, cubit: cubit);

      const words = <int, String>{
        1: 'Poor',
        2: 'Fair',
        3: 'Okay',
        4: 'Great',
        5: 'Excellent',
      };
      for (final entry in words.entries) {
        cubit.setStars(entry.key);
        await tester.pump();
        await tester.pump();
        expect(find.text(entry.value), findsOneWidget);
      }
    });
  });

  group('headline', () {
    testWidgets('no name + client cubit asks about the Jeeber', (tester) async {
      final cubit = _cubit(isClient: true);
      addTearDown(cubit.close);

      await _pump(tester, cubit: cubit);

      expect(find.text('How was your Jeeber?'), findsOneWidget);
    });

    testWidgets('no name + jeeber cubit asks about the customer',
        (tester) async {
      final cubit = _cubit(isClient: false);
      addTearDown(cubit.close);

      await _pump(tester, cubit: cubit);

      expect(find.text('How was your customer?'), findsOneWidget);
    });

    testWidgets('a forwarded ?name= is interpolated, with no {name} left',
        (tester) async {
      final cubit = _cubit(isClient: true);
      addTearDown(cubit.close);

      await _pump(tester, cubit: cubit, rateeName: 'Karim');

      expect(find.text('How was Karim?'), findsOneWidget);
      expect(
        find.textContaining('{name}'),
        findsNothing,
        reason: 'the placeholder must never reach the screen',
      );
      expect(find.text('How was your Jeeber?'), findsNothing);
    });

    testWidgets('the AR headline interpolates a Latin name', (tester) async {
      final cubit = _cubit(isClient: true);
      addTearDown(cubit.close);

      await _pump(
        tester,
        cubit: cubit,
        locale: const Locale('ar'),
        rateeName: 'Karim',
      );

      expect(find.text('كيف كان Karim؟'), findsOneWidget);
    });
  });

  group('new semantics ids', () {
    for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets(
        'blind-reveal note and ratee avatar surface under '
        '${locale.languageCode}',
        (tester) async {
          final cubit = _cubit(isClient: true);
          addTearDown(cubit.close);

          await _pump(tester, cubit: cubit, locale: locale);

          expect(
            find.bySemanticsIdentifier('mutual_rating_blind_note'),
            findsOneWidget,
          );
          expect(
            find.bySemanticsIdentifier('mutual_rating_ratee_avatar'),
            findsOneWidget,
          );
        },
      );
    }
  });

  testWidgets(
    'ar smoke — the rebuilt input view lays out mirrored with no exception '
    'and every frozen id survives',
    (tester) async {
      final cubit = _cubit(isClient: true);
      addTearDown(cubit.close);

      await _pump(tester, cubit: cubit, locale: const Locale('ar'));

      expect(tester.takeException(), isNull);

      expect(find.bySemanticsIdentifier('rating_root'), findsOneWidget);
      expect(find.bySemanticsIdentifier('mutual_rating_stars'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('mutual_rating_comment'),
        findsOneWidget,
      );
      expect(find.bySemanticsIdentifier('rating_submit_cta'), findsOneWidget);
      for (final tag in kMutualRatingTags) {
        expect(
          find.bySemanticsIdentifier('mutual_rating_tag_${tag.key}'),
          findsOneWidget,
        );
      }

      // D56: still no escape affordance anywhere on the mandatory terminal.
      expect(find.bySemanticsIdentifier('rating_skip_cta'), findsNothing);
      expect(find.bySemanticsIdentifier('rating_close_cta'), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byType(CloseButton), findsNothing);

      expect(find.byKey(const Key('mutualRating.stars')), findsOneWidget);
      expect(find.byKey(const Key('mutualRating.comment')), findsOneWidget);
      expect(find.byKey(const Key('mutualRating.submit')), findsOneWidget);
    },
  );
}
