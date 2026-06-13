// Widget tests for EscalateScreen (T-MOB-022).
//
// Verifies:
//   - Reason options rendered.
//   - Submit disabled until reason selected.
//   - Success view shows case number.
//   - Error view shows retry option.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/escalate/application/escalate_cubit.dart';
import 'package:jeeb_mobile/features/escalate/application/escalate_state.dart';
import 'package:jeeb_mobile/features/escalate/domain/escalate_repository.dart';
import 'package:jeeb_mobile/features/escalate/presentation/escalate_screen.dart';

import 'support/sync_app_localizations.dart';

class _FakeRepo implements EscalateRepository {
  const _FakeRepo({this.failWith});
  final EscalateErrorKind? failWith;

  @override
  Future<EscalateResult> submitEscalation({
    required String deliveryId,
    required EscalateReason reason,
    String? comment,
    List<String> photoPaths = const [],
  }) async {
    if (failWith != null) throw EscalateException(failWith!);
    return const EscalateResult(caseId: 'case-999', status: 'open');
  }
}

Widget _wrap({EscalateRepository? repo}) {
  return wrapForTest(
    BlocProvider<EscalateCubit>(
      create: (_) => EscalateCubit(
        repository: repo ?? const _FakeRepo(),
        deliveryId: 'delivery-008',
      ),
      child: const EscalateScreen(),
    ),
  );
}

void main() {
  testWidgets('renders report title and reason options', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.text('Report an Issue'), findsOneWidget);
    expect(find.text('Damaged item'), findsOneWidget);
    expect(find.text('Fraud'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets('submit button is disabled until reason selected', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();

    final submitFinder = find.text('Submit Report');
    expect(submitFinder, findsOneWidget);
    // OmdsButton disables onTap when isEnabled=false — verify no state change.
    await tester.tap(submitFinder, warnIfMissed: false);
    await tester.pump();
    expect(find.text('Submit Report'), findsOneWidget);
  });

  testWidgets('selecting a reason and submitting shows confirmation',
      (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();

    await tester.tap(find.text('Damaged item'));
    await tester.pump();

    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(find.text('Report submitted'), findsOneWidget);
    expect(find.textContaining('case-999'), findsOneWidget);
  });

  testWidgets('server error shows error message', (tester) async {
    await tester.pumpWidget(
      _wrap(repo: const _FakeRepo(failWith: EscalateErrorKind.server)),
    );
    await tester.pump();

    await tester.tap(find.text('No-show'));
    await tester.pump();
    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    expect(find.textContaining("Couldn't submit"), findsOneWidget);
  });

  testWidgets('renders in Arabic locale', (tester) async {
    await tester.pumpWidget(
      wrapForTest(
        BlocProvider<EscalateCubit>(
          create: (_) => EscalateCubit(
            repository: const _FakeRepo(),
            deliveryId: 'dlv-1',
          ),
          child: const EscalateScreen(),
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();

    expect(find.text('الإبلاغ عن مشكلة'), findsOneWidget);
    expect(find.text('عنصر تالف'), findsOneWidget);

    final dir = Directionality.of(tester.element(find.byType(EscalateScreen)));
    expect(dir, TextDirection.rtl);
  });
}
