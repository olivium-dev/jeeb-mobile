import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_state.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc/domain/vehicle_type.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_status_view.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_wizard_screen.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_id_step.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_selfie_step.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_tos_step.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_vehicle_step.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncAppLocalizationsDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);
  }

  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

late _SyncAppLocalizationsDelegate _syncDelegate;

void _loadArbFromDisk() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncAppLocalizationsDelegate({'en': en, 'ar': ar});
}

Widget _host(KycWizardCubit cubit) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: KycWizardScreen(cubit: cubit),
  );
}

Uint8List _bytes(int length) {
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = 0x42;
  }
  return out;
}

KycWizardCubit _newCubit({
  PhotoPickerService? picker,
  KycGateway? gateway,
}) {
  final cubit = KycWizardCubit(
    pickerService: picker ??
        StubPhotoPickerService(cameraPayload: _bytes(100 * 1024)),
    gateway: gateway ?? FakeKycGateway(),
  )..loadSchema();
  addTearDown(cubit.close);
  return cubit;
}

void main() {
  setUpAll(_loadArbFromDisk);

  testWidgets(
    'wizard renders step 1 with a stepper progress indicator',
    (tester) async {
      final cubit = _newCubit();
      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      expect(find.byKey(KycWizardScreen.progressKey), findsOneWidget);
      expect(find.byKey(KycIdStep.frontTileKey), findsOneWidget);
      expect(find.byKey(KycIdStep.backTileKey), findsOneWidget);
      expect(find.byKey(KycIdStep.nextButtonKey), findsOneWidget);
    },
  );

  testWidgets(
    'capturing both ID sides enables the next button and advances to selfie',
    (tester) async {
      final cubit = _newCubit();
      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(KycIdStep.frontTileKey));
      await tester.tap(find.byKey(KycIdStep.frontTileKey));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(KycIdStep.backTileKey));
      await tester.tap(find.byKey(KycIdStep.backTileKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(KycIdStep.nextButtonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(KycSelfieStep.selfieTileKey), findsOneWidget);
      expect(find.byKey(KycSelfieStep.livenessPromptKey), findsOneWidget);
    },
  );

  testWidgets(
    'happy path: ID → selfie → vehicle → pending status',
    (tester) async {
      final cubit = _newCubit(
        gateway: FakeKycGateway(decision: KycStatus.pending),
      );
      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(KycIdStep.frontTileKey));
      await tester.tap(find.byKey(KycIdStep.frontTileKey));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(KycIdStep.backTileKey));
      await tester.tap(find.byKey(KycIdStep.backTileKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(KycIdStep.nextButtonKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(KycSelfieStep.selfieTileKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(KycSelfieStep.nextButtonKey));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(KycVehicleStep.vehicleChipKey(VehicleType.scooter)),
      );
      await tester.ensureVisible(
        find.byKey(KycVehicleStep.registrationFieldKey),
      );
      await tester.enterText(
        find.byKey(KycVehicleStep.registrationFieldKey),
        'LB-12345',
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(KycVehicleStep.submitButtonKey),
      );
      // Vehicle submit advances to the ToS step (contract loads async). Pump a
      // couple of frames rather than pumpAndSettle: the OmdsLoadingState spinner
      // shown while the contract loads never settles under pumpAndSettle.
      await tester.tap(find.byKey(KycVehicleStep.submitButtonKey));
      await tester.pump();
      await tester.pump();

      // Sign the ToS, then submit the full KYC payload.
      await tester.ensureVisible(find.byKey(KycTosStep.signaturePadKey));
      await tester.tap(find.byKey(KycTosStep.signaturePadKey));
      await tester.pump();
      await tester.ensureVisible(find.byKey(KycTosStep.signButtonKey));
      await tester.tap(find.byKey(KycTosStep.signButtonKey));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(KycStatusView.pendingTitleKey), findsOneWidget);
      expect(cubit.state.step, KycWizardStep.status);
      expect(cubit.state.submission.status, KycStatus.pending);
    },
  );

  testWidgets(
    'rejected submission shows rejection reason and resubmit CTA',
    (tester) async {
      final cubit = _newCubit(
        gateway: FakeKycGateway(
          decision: KycStatus.rejected,
          rejectionReason: KycRejectionReason.idUnreadable,
        ),
      );
      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      // Drive directly: capture all three slots, accept the ToS, and submit.
      await cubit.captureIdFront();
      await cubit.captureIdBack();
      cubit.goToSelfie();
      await cubit.captureSelfie();
      cubit.goToVehicle();
      cubit.setVehicleType(VehicleType.car);
      cubit.setVehicleRegistration('LB-99999');
      // submit() advances to the ToS step; signAndSubmit() posts the payload.
      await cubit.submit();
      await cubit.signAndSubmit('sig-blob');
      // pump (not pumpAndSettle): the status view contains no perpetual
      // animation, but earlier steps may briefly show the OmdsLoadingState
      // spinner which never settles.
      await tester.pump();

      expect(find.byKey(KycStatusView.rejectedTitleKey), findsOneWidget);
      expect(find.byKey(KycStatusView.rejectionReasonKey), findsOneWidget);
      expect(find.byKey(KycStatusView.resubmitCtaKey), findsOneWidget);

      await tester.tap(find.byKey(KycStatusView.resubmitCtaKey));
      await tester.pump();
      await tester.pump();

      // Resubmit returns the user to the ID step.
      expect(find.byKey(KycIdStep.frontTileKey), findsOneWidget);
      expect(cubit.state.step, KycWizardStep.id);
    },
  );

  testWidgets(
    'submit refuses to advance when registration is blank and surfaces inline error',
    (tester) async {
      final cubit = _newCubit();
      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      await cubit.captureIdFront();
      await cubit.captureIdBack();
      cubit.goToSelfie();
      await cubit.captureSelfie();
      cubit.goToVehicle();
      cubit.setVehicleType(VehicleType.bicycle);
      // Registration left blank; the submit button is disabled — push state
      // through the cubit directly so the inline error is exercised.
      await cubit.submit();
      await tester.pump();

      expect(cubit.state.error, KycWizardError.vehicleRegistrationRequired);
      expect(cubit.state.step, KycWizardStep.vehicle);
    },
  );
}
