// CANC-01..04 / AE-22 / AE-23 — one strip per kind, a numeric `retryAfter`
// that does not throw, and a terminal 409 with somewhere to go.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/cancellation/data/dio_cancellation_repository.dart';
import 'package:jeeb_mobile/features/cancellation/domain/cancellation_repository.dart';
import 'package:jeeb_mobile/features/cancellation/domain/cancellation_result.dart';
import 'package:jeeb_mobile/features/cancellation/presentation/cancellation_screen.dart';
import 'package:jeeb_mobile/features/cancellation/presentation/cubit/cancellation_state.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';
import '../otp_handover/_scripted_dio.dart';

Future<Object> _cancelFailure(
  void Function(RequestOptions, ResponseHandler) respond,
) async {
  final repo = DioCancellationRepository(scriptedDio(respond));
  try {
    await repo.cancel(deliveryId: 'DLV-1', reason: 'changed_mind');
  } catch (e) {
    return e;
  }
  fail('expected a failure');
}

/// Never reached: every state under test is seeded, so the repository only
/// has to satisfy the type.
class _RejectingRepository implements CancellationRepository {
  const _RejectingRepository();

  @override
  Future<CancellationResult> cancel({
    required String deliveryId,
    required String reason,
    String? otherDetails,
  }) async => throw const CancellationException(null, CancellationFailure.unknown);
}

void main() {
  group('kind mapping', () {
    test('400 + cancellation-reason-required', () async {
      final e = await _cancelFailure(
        (_, r) => r.failWithStatus(
          400,
          body: problem('cancellation-reason-required'),
        ),
      );
      expect(
        (e as CancellationException).kind,
        CancellationFailure.reasonRequired,
      );
      expect(e.message, isNull, reason: 'no gateway prose on the state');
    });

    test('403 + not-a-party', () async {
      final e = await _cancelFailure(
        (_, r) => r.failWithStatus(403, body: problem('not-a-party')),
      );
      expect((e as CancellationException).kind, CancellationFailure.notAParty);
    });

    test('a PLAIN 403 is forbidden, not "you are not a party"', () async {
      final e = await _cancelFailure((_, r) => r.failWithStatus(403));
      expect((e as CancellationException).kind, CancellationFailure.forbidden);
    });

    test('409 stays the dedicated too-late exception', () async {
      expect(
        await _cancelFailure((_, r) => r.failWithStatus(409)),
        isA<CancellationTooLateException>(),
      );
    });

    test('transport is network, >=500 is server, 429 is rateLimited', () async {
      expect(
        ((await _cancelFailure(
          (_, r) => r.failWithType(DioExceptionType.connectionError),
        )) as CancellationException).kind,
        CancellationFailure.network,
      );
      expect(
        ((await _cancelFailure((_, r) => r.failWithStatus(503)))
                as CancellationException)
            .kind,
        CancellationFailure.server,
      );
      expect(
        ((await _cancelFailure((_, r) => r.failWithStatus(429)))
                as CancellationException)
            .kind,
        CancellationFailure.rateLimited,
      );
    });
  });

  test('AE-23: a NUMERIC retryAfter does not throw a TypeError', () async {
    final repo = DioCancellationRepository(
      scriptedDio(
        (_, r) => r.respondWith(200, body: <String, Object?>{
          'deliveryId': 'DLV-1',
          'weeklyCount': 1,
          'retryAfter': 90,
        }),
      ),
    );
    final result = await repo.cancel(deliveryId: 'DLV-1', reason: 'x');
    expect(result.retryAfter, isNotNull);
  });

  testWidgets('each kind renders its OWN cancellation_error_note, EN + AR',
      (tester) async {
    for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
      final rendered = <String>{};
      for (final kind in const <CancellationFailure>[
        CancellationFailure.reasonRequired,
        CancellationFailure.notAParty,
        CancellationFailure.forbidden,
        CancellationFailure.network,
        CancellationFailure.server,
      ]) {
        useReduceMotion(tester);
        // A fresh key per case: without it the element (and its BlocProvider's
        // already-created cubit) is reused and every case shows the first copy.
        await tester.pumpWidget(
          wrapForTest(
            CancellationScreen(
              key: ValueKey<String>('$kind-$locale'),
              deliveryId: 'DLV-1',
              isJeeber: false,
              repository: const _RejectingRepository(),
              initialState: CancellationError(null, kind),
            ),
            locale: locale,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsIdentifier('cancellation_error_note'),
          findsOneWidget,
          reason: '$kind / $locale',
        );

        final l10n = AppLocalizations.of(
          tester.element(find.byType(CancellationScreen)),
        );
        final expected = switch (kind) {
          CancellationFailure.reasonRequired =>
            l10n.cancellationErrorReasonRequired,
          CancellationFailure.notAParty => l10n.cancellationErrorNotAParty,
          CancellationFailure.forbidden => l10n.errorForbiddenBody,
          CancellationFailure.network => l10n.cancellationErrorNetwork,
          _ => l10n.cancellationErrorNote,
        };
        expect(find.text(expected), findsOneWidget, reason: '$kind / $locale');
        rendered.add(expected);
      }
      expect(
        rendered.length,
        5,
        reason: 'each kind must have its own line in $locale',
      );
    }
  });

  testWidgets('the 409 lane offers a way onward, never a Retry',
      (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      wrapForTest(
        const CancellationScreen(
          deliveryId: 'DLV-1',
          isJeeber: false,
          repository: _RejectingRepository(),
          initialState: CancellationTooLate(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('cancellation_too_late_track_cta'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('cancellation_too_late_escalate_cta'),
      findsOneWidget,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CancellationScreen)),
    );
    expect(find.text(l10n.actionRetry), findsNothing);
  });
}
