// F1: `loadStatus` awaited `fetchStatus()` with no `try`, so a throwing
// gateway left `isLoadingStatus: true` forever — a permanent spinner.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_state.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_wizard_screen.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _ThrowingStatusGateway extends FakeKycGateway {
  _ThrowingStatusGateway(this.failure);

  final AppFailure failure;
  int statusReads = 0;

  @override
  Future<KycSubmission> fetchStatus() async {
    statusReads++;
    throw KycGatewayException(failure);
  }
}

KycWizardCubit _cubit(KycGateway gateway) => KycWizardCubit(
      pickerService: StubPhotoPickerService(),
      gateway: gateway,
    );

Future<void> _pump(
  WidgetTester tester,
  KycWizardCubit cubit, {
  Locale locale = const Locale('en'),
}) async {
  useReduceMotion(tester);
  await tester.pumpWidget(
    wrapForTest(KycWizardScreen(cubit: cubit), locale: locale),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('a throwing status read clears the spinner and names the failure',
      () async {
    final gateway = _ThrowingStatusGateway(const ServerFailure(status: 500));
    final cubit = _cubit(gateway);
    addTearDown(cubit.close);

    await cubit.loadStatus();

    expect(cubit.state.isLoadingStatus, isFalse);
    expect(cubit.state.error, KycWizardError.statusLoadFailed);
    expect(cubit.state.failure, isA<ServerFailure>());
  });

  test('a second failure keeps the error rung — it never blanks', () async {
    final gateway = _ThrowingStatusGateway(const NetworkFailure());
    final cubit = _cubit(gateway);
    addTearDown(cubit.close);

    await cubit.loadStatus();
    await cubit.loadStatus();

    expect(gateway.statusReads, 2);
    expect(cubit.state.error, KycWizardError.statusLoadFailed);
    expect(cubit.state.isLoadingStatus, isFalse);
  });

  testWidgets('the screen renders kyc_wizard_status_error, not the spinner',
      (tester) async {
    final cubit = _cubit(_ThrowingStatusGateway(const NetworkFailure()));
    addTearDown(cubit.close);
    await cubit.loadStatus();

    await _pump(tester, cubit);

    expect(
      find.bySemanticsIdentifier('kyc_wizard_status_error'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('kyc_wizard_schema_loading'),
      findsNothing,
    );
    expect(
      find.bySemanticsIdentifier('kyc_wizard_status_retry_cta'),
      findsOneWidget,
    );
  });

  testWidgets('tapping retry re-invokes loadStatus', (tester) async {
    final gateway = _ThrowingStatusGateway(const NetworkFailure());
    final cubit = _cubit(gateway);
    addTearDown(cubit.close);
    await cubit.loadStatus();

    await _pump(tester, cubit);
    await tester.tap(
      find.bySemanticsIdentifier('kyc_wizard_status_retry_cta'),
    );
    await tester.pumpAndSettle();

    expect(gateway.statusReads, 2);
  });

  // The PRODUCTION order: the screen mounts first, then `..loadStatus()`
  // resolves, so the error arrives while the BlocListener is subscribed.
  testWidgets('mount-then-load keeps the status error rung — EN and AR',
      (tester) async {
    for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
      final cubit = _cubit(_ThrowingStatusGateway(const ServerFailure(status: 500)));
      addTearDown(cubit.close);

      useReduceMotion(tester);
      await tester.pumpWidget(
        wrapForTest(KycWizardScreen(cubit: cubit), locale: locale),
      );
      await tester.pump();
      await cubit.loadStatus();
      await tester.pumpAndSettle();

      expect(cubit.state.error, KycWizardError.statusLoadFailed);
      expect(
        find.bySemanticsIdentifier('kyc_wizard_status_error'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('kyc_wizard_schema_loading'),
        findsNothing,
      );
      expect(
        find.bySemanticsIdentifier('kyc_wizard_error_snack'),
        findsNothing,
      );
    }
  });

  testWidgets('a 500 never prints the connection line — EN and AR',
      (tester) async {
    for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
      final cubit = _cubit(_ThrowingStatusGateway(const ServerFailure(status: 500)));
      addTearDown(cubit.close);
      await cubit.loadStatus();

      await _pump(tester, cubit, locale: locale);

      expect(
        find.bySemanticsIdentifier('kyc_wizard_status_error'),
        findsOneWidget,
      );
      expect(find.text('Check your connection and try again.'), findsNothing);
      expect(find.text('تحقّق من اتصالك وحاول مرة أخرى.'), findsNothing);
    }
  });
}
