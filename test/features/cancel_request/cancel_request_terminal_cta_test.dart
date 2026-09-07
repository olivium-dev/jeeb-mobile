// CR-01 / OFF-24 / GEN-01 — a terminal 409 keeps a live destructive CTA, the
// network line is a LOGIN string, and a DI-less host fabricates a success.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/cancel_request/application/cancel_request_state.dart';
import 'package:jeeb_mobile/features/cancel_request/domain/cancel_request_repository.dart';
import 'package:jeeb_mobile/features/cancel_request/presentation/cancel_request_sheet.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _ThrowingRepository implements CancelRequestRepository {
  const _ThrowingRepository(this.failure);

  final CancelRequestFailure failure;

  @override
  Future<void> cancelRequest({required String requestId}) async =>
      throw CancelRequestException(failure);
}

Widget _sheet({
  CancelRequestRepository? repository,
  CancelRequestState? initialState,
  Locale locale = const Locale('en'),
}) => wrapForTest(
      Scaffold(
        body: CancelRequestSheet(
          requestId: 'REQ-1',
          repository: repository,
          initialState: initialState,
        ),
      ),
      locale: locale,
    );

void main() {
  testWidgets('a terminal conflict swaps the confirm CTA for a close, EN + AR',
      (tester) async {
    for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
      useReduceMotion(tester);
      await tester.pumpWidget(
        _sheet(
          repository: const _ThrowingRepository(CancelRequestFailure.conflict),
          initialState: const CancelRequestState(
            status: CancelRequestStatus.failed,
            error: CancelRequestFailure.conflict,
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('cancel_request_close_cta'),
        findsOneWidget,
        reason: 'locale: $locale',
      );
      expect(
        find.bySemanticsIdentifier('cancel_request_confirm_cta'),
        findsNothing,
      );
    }
  });

  testWidgets('a retryable network failure keeps the confirm CTA and drops '
      'the login string', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      _sheet(
        repository: const _ThrowingRepository(CancelRequestFailure.network),
        initialState: const CancelRequestState(
          status: CancelRequestStatus.failed,
          error: CancelRequestFailure.network,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('cancel_request_confirm_cta'),
      findsOneWidget,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(CancelRequestSheet)),
    );
    expect(find.text(l10n.loginNetworkError), findsNothing);
    expect(find.text(l10n.errorUnreachableBody), findsOneWidget);
  });

  testWidgets('a DI-less host says unavailable instead of fabricating a cancel',
      (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(_sheet());
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('cancel_request_unavailable'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('cancel_request_confirm_cta'),
      findsNothing,
    );
  });
}
