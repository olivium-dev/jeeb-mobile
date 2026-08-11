// mob-avatar: the counterparty PHOTO on the mandatory rating terminal.
//
// The screen previously built `JeebAvatar.hero` with no `imageUrl` at all, so
// both roles saw a letter placeholder even though the kit supports the photo.
// Identity now arrives two ways — the `?avatar=` route param, and the cubit's
// own self-resolve for the entry points that carry none (receipt confirm, OTP
// handover). The route param wins; empty falls back to the initial.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_avatar.dart';
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/rating/application/mutual_rating_cubit.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';
import 'package:jeeb_mobile/features/rating/presentation/mutual_rating_screen.dart';

import '../../support/sync_app_localizations.dart';

const _jeeberPhoto = 'http://gw.test/api/users/j-1/avatar?v=abc';
const _clientPhoto = 'http://gw.test/api/users/c-1/avatar?v=def';

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

class _FakeSummaryRepo implements OrderChatSummaryRepository {
  const _FakeSummaryRepo();

  @override
  Future<OrderChatSummary> fetchSummary(String deliveryId) async =>
      const OrderChatSummary(
        deliveryId: 'dlv-1',
        jeeberName: 'Karim',
        jeeberAvatarUrl: _jeeberPhoto,
        clientName: 'Nour',
        clientAvatarUrl: _clientPhoto,
      );
}

MutualRatingCubit _cubit({
  required bool isClient,
  OrderChatSummaryRepository? counterpartRepository,
}) =>
    MutualRatingCubit(
      repository: const _FakeRatingRepo(),
      deliveryId: 'dlv-1',
      isClient: isClient,
      counterpartRepository: counterpartRepository,
    );

Future<void> _pump(
  WidgetTester tester, {
  required MutualRatingCubit cubit,
  String rateeName = '',
  String? rateeAvatarUrl,
}) async {
  await tester.pumpWidget(
    wrapForTest(
      BlocProvider<MutualRatingCubit>.value(
        value: cubit,
        child: MutualRatingScreen(
          rateeName: rateeName,
          rateeAvatarUrl: rateeAvatarUrl,
        ),
      ),
    ),
  );
  await tester.pump();
}

JeebAvatar _rateeAvatar(WidgetTester tester) => tester.widget<JeebAvatar>(
      find.byWidgetPredicate(
        (w) => w is JeebAvatar && w.identifier == 'mutual_rating_ratee_avatar',
      ),
    );

void main() {
  testWidgets('no identity anywhere ⇒ no imageUrl, the initial still renders',
      (tester) async {
    final cubit = _cubit(isClient: true);
    addTearDown(cubit.close);

    await _pump(tester, cubit: cubit, rateeName: 'Karim');

    expect(_rateeAvatar(tester).imageUrl, isNull);
    expect(find.text('K'), findsOneWidget);
  });

  testWidgets('the ?avatar= route param renders the photo', (tester) async {
    final cubit = _cubit(isClient: true);
    addTearDown(cubit.close);

    await _pump(
      tester,
      cubit: cubit,
      rateeName: 'Karim',
      rateeAvatarUrl: _jeeberPhoto,
    );

    expect(_rateeAvatar(tester).imageUrl, _jeeberPhoto);
  });

  testWidgets('CLIENT leg self-resolves the jeeber photo when the route '
      'carried none (receipt-confirm entry point)', (tester) async {
    final cubit = _cubit(isClient: true, counterpartRepository: const _FakeSummaryRepo());
    addTearDown(cubit.close);

    await _pump(tester, cubit: cubit);
    expect(_rateeAvatar(tester).imageUrl, isNull);

    await cubit.loadCounterpart();
    await tester.pump();
    await tester.pump();

    expect(_rateeAvatar(tester).imageUrl, _jeeberPhoto);
    expect(_rateeAvatar(tester).initial, 'Karim');
  });

  testWidgets('JEEBER leg self-resolves the CLIENT photo (OTP-handover entry '
      'point) — the leg that had no counterparty surface at all', (tester) async {
    final cubit = _cubit(isClient: false, counterpartRepository: const _FakeSummaryRepo());
    addTearDown(cubit.close);

    await _pump(tester, cubit: cubit);
    await cubit.loadCounterpart();
    await tester.pump();
    await tester.pump();

    expect(_rateeAvatar(tester).imageUrl, _clientPhoto);
    expect(_rateeAvatar(tester).initial, 'Nour');
  });

  testWidgets('the route param WINS over the self-resolved value',
      (tester) async {
    final cubit = _cubit(isClient: true, counterpartRepository: const _FakeSummaryRepo());
    addTearDown(cubit.close);

    await _pump(tester, cubit: cubit, rateeAvatarUrl: _clientPhoto);
    await cubit.loadCounterpart();
    await tester.pump();
    await tester.pump();

    expect(_rateeAvatar(tester).imageUrl, _clientPhoto);
  });
}
