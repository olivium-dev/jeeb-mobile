// F26: `refreshStatus` swallowed with `catch (_) { return; }`, so a stale KYC
// status never said so. R6: a refresh NEVER flips the screen to loading.
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

/// The first read lands; every later one fails.
class _RefreshFailingGateway extends FakeKycGateway {
  _RefreshFailingGateway() : super(initial: _pending);

  static const KycSubmission _pending = KycSubmission(status: KycStatus.pending);

  int reads = 0;

  @override
  Future<KycSubmission> fetchStatus() async {
    reads++;
    if (reads == 1) return _pending;
    throw const KycGatewayException(NetworkFailure(offline: true));
  }
}

KycWizardCubit _cubit(KycGateway gateway) => KycWizardCubit(
      pickerService: StubPhotoPickerService(),
      gateway: gateway,
    );

void main() {
  test('a failed refresh keeps the loaded submission and never loads',
      () async {
    final cubit = _cubit(_RefreshFailingGateway());
    addTearDown(cubit.close);
    await cubit.loadStatus();
    expect(cubit.state.step, KycWizardStep.status);

    final emitted = <bool>[];
    final sub = cubit.stream.listen((s) => emitted.add(s.isLoadingStatus));
    await cubit.refreshStatus();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(cubit.state.step, KycWizardStep.status);
    expect(cubit.state.submission.status, KycStatus.pending);
    expect(cubit.state.refreshFailure, isA<NetworkFailure>());
    expect(emitted, isNot(contains(true)));
  });

  test('acknowledgeRefreshFailure clears the note', () async {
    final cubit = _cubit(_RefreshFailingGateway());
    addTearDown(cubit.close);
    await cubit.loadStatus();
    await cubit.refreshStatus();
    expect(cubit.state.refreshFailure, isNotNull);

    cubit.acknowledgeRefreshFailure();

    expect(cubit.state.refreshFailure, isNull);
  });

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('${locale.languageCode} · the refresh-failed note renders and '
        'dismisses', (tester) async {
      useReduceMotion(tester);
      final cubit = _cubit(_RefreshFailingGateway());
      addTearDown(cubit.close);
      await cubit.loadStatus();
      await cubit.refreshStatus();

      await tester.pumpWidget(
        wrapForTest(KycWizardScreen(cubit: cubit), locale: locale),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('kyc_status_refresh_failed_note'),
        findsOneWidget,
      );

      await tester.tap(
        find.bySemanticsIdentifier('kyc_status_refresh_failed_note_dismiss_cta'),
      );
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier('kyc_status_refresh_failed_note'),
        findsNothing,
      );
    });
  }
}
