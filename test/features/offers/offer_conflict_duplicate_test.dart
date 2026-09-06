// AE-05: each 409 discriminator resolves its OWN state and copy, and the
// retired cap heuristic never fires again.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';
import 'package:jeeb_mobile/features/offers/data/dio_offer_submission_repository.dart';
import 'package:jeeb_mobile/features/offers/domain/offer_submission_repository.dart';
import 'package:jeeb_mobile/features/offers/presentation/offer_submission_screen.dart';
import 'package:jeeb_mobile/features/offers/application/offer_submission_cubit.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

/// Answers every POST with one canned problem document.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this.status, this.body);

  final int status;
  final Object? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

DioOfferSubmissionRepository _repo(int status, Object? body) =>
    DioOfferSubmissionRepository(
      Dio(BaseOptions(baseUrl: 'http://gw.test'))
        ..httpClientAdapter = _ScriptedAdapter(status, body),
    );

Map<String, Object?> _problem(String suffix) => <String, Object?>{
  'type': 'https://jeeb.app/errors/$suffix',
  'title': 'Conflict',
  'status': 409,
};

class _ThrowingRepo implements OfferSubmissionRepository {
  _ThrowingRepo(this.failure);

  final OfferSubmissionFailure failure;
  int submissions = 0;

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async {
    submissions++;
    throw OfferSubmissionException(failure);
  }
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
  test('out-of-range remains editable and can submit after correction', () async {
    final repository = _ThrowingRepo(OfferSubmissionFailure.outOfRange);
    final cubit = OfferFormCubit(repository: repository);
    await cubit.submit(requestId: 'request', priceUsd: 7, etaMinutes: 40);
    expect(repository.submissions, 1);
    cubit.acknowledgeError();
    expect(cubit.state.mode, OfferFormMode.idle);
    await cubit.submit(requestId: 'request', priceUsd: 9, etaMinutes: 80);
    expect(repository.submissions, 2);
    expect(cubit.state.errorReason, OfferSubmissionFailure.outOfRange);
    await cubit.close();
  });
  group('the 409 discriminators map one-to-one', () {
    Future<OfferSubmissionFailure> failureFor(Object? body) async {
      try {
        await _repo(
          409,
          body,
        ).submitOffer(requestId: 'r', priceUsd: 5, etaMinutes: 10);
      } on OfferSubmissionException catch (e) {
        return e.failure;
      }
      fail('expected an OfferSubmissionException');
    }

    test('offer-already-exists → duplicateOffer', () async {
      expect(
        await failureFor(_problem('offer-already-exists')),
        OfferSubmissionFailure.duplicateOffer,
      );
    });

    test('request-not-open-for-offers → requestNotOpen', () async {
      expect(
        await failureFor(_problem('request-not-open-for-offers')),
        OfferSubmissionFailure.requestNotOpen,
      );
    });

    test('same-delivery-role-violation → sameRoleViolation', () async {
      expect(
        await failureFor(_problem('same-delivery-role-violation')),
        OfferSubmissionFailure.sameRoleViolation,
      );
    });

    test('offer-out-of-range → outOfRange', () async {
      expect(
        await failureFor(_problem('offer-out-of-range')),
        OfferSubmissionFailure.outOfRange,
      );
    });

    test('UX-12: a GUID-shaped detail containing "20" is NOT a cap', () async {
      expect(
        await failureFor(<String, Object?>{
          'title': 'Conflict',
          'detail': 'offer 9c37b6af-4e21-4e4a-9c1b-1f2a3b4c2013 conflicts',
        }),
        OfferSubmissionFailure.requestGone,
      );
    });
  });

  for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets(
      '${locale.languageCode}: same-role refusal survives edits and blocks repeated POST',
      (tester) async {
        useReduceMotion(tester);
        final handle = tester.ensureSemantics();
        final repository = _ThrowingRepo(
          OfferSubmissionFailure.sameRoleViolation,
        );
        var exits = 0;
        await tester.pumpWidget(
          wrapForTest(
            OfferSubmissionScreen(
              requestId: 'own-request',
              submissionService: null,
              repository: repository,
              onWithdrawn: () => exits++,
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        await _send(tester);
        expect(repository.submissions, 1);
        await tester.enterText(find.byType(EditableText).first, '19');
        await tester.tap(
          find.bySemanticsIdentifier('offer_composer_eta_option_1'),
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        final context = tester.element(
          find.bySemanticsIdentifier('offer_composer_error_note'),
        );
        final cubit = context.read<OfferFormCubit>();
        expect(
          cubit.state.errorReason,
          OfferSubmissionFailure.sameRoleViolation,
        );
        expect(
          find.text(AppLocalizations.of(context).offerErrorSameRole),
          findsOneWidget,
        );
        final send = tester.widget<JeebCtaButton>(
          find.byWidgetPredicate(
            (w) =>
                w is JeebCtaButton && w.identifier == 'offer_composer_send_cta',
          ),
        );
        expect(send.isEnabled, isFalse);
        await tester.tap(find.bySemanticsIdentifier('offer_composer_send_cta'));
        await cubit.submit(
          requestId: 'own-request',
          priceUsd: 19,
          etaMinutes: 80,
        );
        expect(repository.submissions, 1);
        expect(
          cubit.state.errorReason,
          OfferSubmissionFailure.sameRoleViolation,
        );
        await tester.tap(
          find.bySemanticsIdentifier('offer_composer_terminal_exit_cta'),
        );
        expect(exits, 1);
        expect(tester.takeException(), isNull);
        handle.dispose();
      },
    );
    testWidgets('${locale.languageCode}: a duplicate offer draws its own note '
        'with a way to the pending list', (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrapForTest(
          OfferSubmissionScreen(
            requestId: 'req-1',
            submissionService: null,
            repository: _ThrowingRepo(OfferSubmissionFailure.duplicateOffer),
            onWithdrawn: () {},
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      await _send(tester);

      expect(
        find.bySemanticsIdentifier('offer_composer_duplicate_note'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('offer_composer_duplicate_cta'),
        findsOneWidget,
      );
      // A duplicate is not the generic rung.
      expect(
        find.bySemanticsIdentifier('offer_composer_error_note'),
        findsNothing,
      );

      handle.dispose();
    });

    testWidgets('${locale.languageCode}: out-of-range and same-role each get '
        'their own sentence on the note', (tester) async {
      useReduceMotion(tester);
      final SemanticsHandle handle = tester.ensureSemantics();

      for (final OfferSubmissionFailure failure in <OfferSubmissionFailure>[
        OfferSubmissionFailure.outOfRange,
        OfferSubmissionFailure.sameRoleViolation,
      ]) {
        await tester.pumpWidget(
          wrapForTest(
            OfferSubmissionScreen(
              key: ValueKey<OfferSubmissionFailure>(failure),
              requestId: 'req-1',
              submissionService: null,
              repository: _ThrowingRepo(failure),
              onWithdrawn: () {},
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();
        await _send(tester);

        expect(
          find.bySemanticsIdentifier('offer_composer_error_note'),
          findsOneWidget,
          reason: '${failure.name} must render the persistent note',
        );
        // Never the shared generic body — each has its own key.
        expect(
          find.text('Something went wrong. Please try again.'),
          findsNothing,
        );
      }

      handle.dispose();
    });
  }

  testWidgets('request-not-open-for-offers takes the terminal request-gone '
      'path and blocks resend if the exit host remains mounted', (
    tester,
  ) async {
    useReduceMotion(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    var withdrawals = 0;
    final repository = _ThrowingRepo(OfferSubmissionFailure.requestNotOpen);
    await tester.pumpWidget(
      wrapForTest(
        OfferSubmissionScreen(
          requestId: 'req-1',
          submissionService: null,
          repository: repository,
          onWithdrawn: () => withdrawals++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _send(tester);

    expect(withdrawals, 1);
    expect(repository.submissions, 1);
    // This test's callback intentionally does not navigate. A terminal page
    // left mounted must not look sendable after its transient snack expires.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsIdentifier('offer_composer_error_note'),
      findsOneWidget,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(OfferSubmissionScreen)),
    );
    expect(find.text(l10n.offerSubmitRequestGone), findsOneWidget);
    final send = tester.widget<JeebCtaButton>(
      find.byWidgetPredicate(
        (w) => w is JeebCtaButton && w.identifier == 'offer_composer_send_cta',
      ),
    );
    expect(send.isEnabled, isFalse);
    await tester.tap(find.bySemanticsIdentifier('offer_composer_send_cta'));
    await tester.pump();
    expect(repository.submissions, 1);
    expect(withdrawals, 1);
    expect(tester.takeException(), isNull);

    handle.dispose();
  });
}
