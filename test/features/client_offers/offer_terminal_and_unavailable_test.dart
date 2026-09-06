import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/features/client_offers/application/offer_accept_cubit.dart';
import 'package:jeeb_mobile/features/client_offers/application/offer_accept_state.dart';
import 'package:jeeb_mobile/features/client_offers/application/client_offers_state.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_accept_sheet.dart';
import 'package:jeeb_mobile/features/client_offers/presentation/widgets/offer_sort_bar.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/client_offers_screen_fixtures.dart';
import 'package:jeeb_mobile/features/delivery_receipt/presentation/delivery_receipt_screen.dart';
import '../../core/widgets/jeeb/jeeb_failure_test_harness.dart';
import '../../support/midnight_test_harness.dart';

class _Rejected extends OffersRepository {
  _Rejected(this.failure);
  final OffersFailure failure;
  int calls = 0;
  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async =>
      throw StateError('unexpected read');
  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    calls++;
    throw OffersRepositoryException(failure);
  }
}

void main() {
  for (final failure in [
    OffersFailure.requestExpired,
    OffersFailure.requestNotOpen,
    OffersFailure.offerNotPending,
  ]) {
    test('real $failure response prevents repeated confirm writes', () async {
      final repo = _Rejected(failure);
      final cubit = OfferAcceptCubit(
        repository: repo,
        requestId: 'r',
        offerId: 'o',
      );
      addTearDown(cubit.close);
      await cubit.confirm();
      expect(cubit.state.status, OfferAcceptStatus.failed);
      expect(cubit.state.canConfirm, isFalse);
      await cubit.confirm();
      expect(repo.calls, 1);
    });
  }

  test('balance change can make a wallet-short retry meaningful', () async {
    final repo = _Rejected(OffersFailure.jeeberWalletShort);
    final cubit = OfferAcceptCubit(
      repository: repo,
      requestId: 'r',
      offerId: 'o',
    );
    addTearDown(cubit.close);
    await cubit.confirm();
    expect(cubit.state.canConfirm, isTrue);
    await cubit.confirm();
    expect(repo.calls, 2);
  });

  testWidgets('expired response disables both pointer and semantic confirm', (
    tester,
  ) async {
    useReduceMotion(tester);
    final repo = _Rejected(OffersFailure.requestExpired);
    await tester.pumpWidget(
      wrapMidnight(
        OfferAcceptSheet(
          offer: ClientOffersScreenPreviewFixtures.threeBids.first,
          requestId: 'r',
          repository: repo,
        ),
        scrollable: false,
      ),
    );
    await tester.tap(find.byKey(const Key('offer-accept-confirm-cta')));
    await tester.pumpAndSettle();
    final target = find.byKey(const Key('offer-accept-confirm-cta'));
    expect(tester.widget<JeebCtaButton>(target).isEnabled, isFalse);
    final cubit = tester.element(target).read<OfferAcceptCubit>();
    await cubit.confirm();
    expect(repo.calls, 1);
    final semantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.identifier == 'offer_accept_confirm_cta',
      ),
    );
    expect(semantics.properties.onTap, isNull);
  });

  testWidgets('DI-less offer confirmation never calls success', (tester) async {
    useReduceMotion(tester);
    await sl.reset();
    var confirmed = false;
    await tester.pumpWidget(
      wrapMidnight(
        OfferAcceptSheet(
          offer: ClientOffersScreenPreviewFixtures.threeBids.first,
          requestId: 'r',
          onConfirmed: (_) => confirmed = true,
        ),
        scrollable: false,
      ),
    );
    await tester.tap(find.byKey(const Key('offer-accept-confirm-cta')));
    await tester.pumpAndSettle();
    expect(confirmed, isFalse);
    expect(find.byKey(const Key('offer-accept-error')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DI-less receipt cannot display a fabricated cash receipt', (
    tester,
  ) async {
    useReduceMotion(tester);
    await sl.reset();
    await tester.pumpWidget(
      wrapMidnight(
        const DeliveryReceiptScreen(deliveryId: 'r'),
        scrollable: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('receipt_load_error'), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('receipt_cash_to_jeeber_label'),
      findsNothing,
    );
    expect(find.bySemanticsIdentifier('receipt_confirm_cta'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sort choices remain reachable at narrow width with large text', (
    tester,
  ) async {
    useReduceMotion(tester);
    OfferSortMode selected = OfferSortMode.best;
    await tester.pumpWidget(
      wrapMidnight(
        Center(
          child: SizedBox(
            width: 300,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: OfferSortBar(
                mode: selected,
                onChanged: (value) => selected = value,
              ),
            ),
          ),
        ),
        scrollable: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final last = find.byKey(const Key('offer-sort-rating'));
    await tester.ensureVisible(last);
    await tester.tap(last);
    expect(selected, OfferSortMode.byRating);
    expect(tester.takeException(), isNull);
  });
}
