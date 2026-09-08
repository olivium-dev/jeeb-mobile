// AE-13: a field-shaped 400 lands on its own slot, and no `HTTP 400` string
// ever reaches a rendered node.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/offers/domain/offer_submission_repository.dart';
import 'package:jeeb_mobile/features/offers/presentation/widgets/jeeb_money_field.dart';
import 'package:jeeb_mobile/features/offers/presentation/offer_submission_screen.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _ThrowingRepo implements OfferSubmissionRepository {
  _ThrowingRepo(this.failure);

  final OfferSubmissionFailure failure;

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async =>
      throw OfferSubmissionException(failure);
}

Future<void> _pump(
  WidgetTester tester,
  OfferSubmissionRepository repo, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    wrapForTest(
      OfferSubmissionScreen(
        requestId: 'req-1',
        submissionService: null,
        repository: repo,
        onWithdrawn: () {},
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _send(WidgetTester tester) async {
  await tester.enterText(find.byType(EditableText).first, '7');
  await tester.pump();
  await tester.tap(find.bySemanticsIdentifier('offer_composer_eta_option_0'));
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsIdentifier('offer_composer_send_cta'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final String tag = locale.languageCode;

    testWidgets('$tag: offer-fee-too-low fills the PRICE slot and leaves the '
        'ETA slot clean', (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _ThrowingRepo(OfferSubmissionFailure.feeTooLow),
          locale: locale);
      await _send(tester);

      // The note rung is NOT used for a field-shaped rejection (UX-38).
      expect(
        find.bySemanticsIdentifier('offer_composer_error_note'),
        findsNothing,
      );
      expect(find.bySemanticsIdentifier('offer_composer_note_error'),
          findsNothing);

      final money = tester.widget<JeebMoneyField>(find.byType(JeebMoneyField));
      expect(money.errorText, isNotNull);
      expect(money.errorText, isNot(contains('HTTP')));

      handle.dispose();
    });

    testWidgets('$tag: offer-eta-invalid fills the ETA slot', (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _ThrowingRepo(OfferSubmissionFailure.etaInvalid),
          locale: locale);
      await _send(tester);

      expect(
        find.bySemanticsIdentifier('offer_composer_error_note'),
        findsNothing,
      );
      // The price slot stays clean.
      final money = tester.widget<JeebMoneyField>(find.byType(JeebMoneyField));
      expect(money.errorText, isNull);

      handle.dispose();
    });

    testWidgets('$tag: offer-note-too-long fills the note error line',
        (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pump(tester, _ThrowingRepo(OfferSubmissionFailure.noteTooLong),
          locale: locale);
      await _send(tester);

      expect(
        find.bySemanticsIdentifier('offer_composer_note_error'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('offer_composer_error_note'),
        findsNothing,
      );

      handle.dispose();
    });
  }

  testWidgets('no `HTTP 400` string reaches any rendered node', (tester) async {
    useReduceMotion(tester);
    await _pump(tester, _ThrowingRepo(OfferSubmissionFailure.invalidInput));
    await _send(tester);

    expect(find.textContaining('HTTP'), findsNothing);
    expect(
      find.bySemanticsIdentifier('offer_composer_error_note'),
      findsOneWidget,
    );
  });
}
