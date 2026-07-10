import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_state.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_status_view.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_wizard_screen.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_identity_step.dart';
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

Widget _host(
  KycWizardCubit cubit, {
  void Function(BuildContext context)? onSubmitted,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: KycWizardScreen(cubit: cubit, onSubmitted: onSubmitted),
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

/// Finds a widget by its `Semantics(identifier:)` value.
Finder _byIdentifier(String id) => find.byWidgetPredicate(
      (w) => w is Semantics && w.properties.identifier == id,
    );

void main() {
  setUpAll(_loadArbFromDisk);

  testWidgets(
    'identity screen renders all three uploads, the submit CTA, and no vehicle step',
    (tester) async {
      final cubit = _newCubit();
      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      // kyc_wizard_root wraps the whole body.
      expect(_byIdentifier('kyc_wizard_root'), findsOneWidget);

      // AC2: gov-ID front/back + selfie present.
      expect(_byIdentifier('kyc_id_front_upload'), findsOneWidget);
      expect(_byIdentifier('kyc_id_back_upload'), findsOneWidget);
      expect(_byIdentifier('kyc_selfie_upload'), findsOneWidget);

      // E3/JEBV4-197: the ID-type picker (all 3 ratified variants) and the
      // ID-number field are part of the identity screen.
      expect(_byIdentifier('kyc_id_type_picker'), findsOneWidget);
      expect(_byIdentifier('kyc_id_type_national_id'), findsOneWidget);
      expect(_byIdentifier('kyc_id_type_passport'), findsOneWidget);
      expect(_byIdentifier('kyc_id_type_residency'), findsOneWidget);
      expect(_byIdentifier('kyc_id_number_input'), findsOneWidget);
      expect(find.byKey(KycIdentityStep.idNumberFieldKey), findsOneWidget);

      // kyc_submit_cta present from the first frame of the identity screen.
      expect(_byIdentifier('kyc_submit_cta'), findsOneWidget);
      expect(find.byKey(KycIdentityStep.submitButtonKey), findsOneWidget);

      // AC1: NO vehicle step anywhere.
      expect(_byIdentifier('kyc_vehicle_step'), findsNothing);
      expect(find.text('LB-12345'), findsNothing);
    },
  );

  testWidgets(
    'progress header reflects 2 capture steps (vehicle removed)',
    (tester) async {
      final cubit = _newCubit();
      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      expect(find.byKey(KycWizardScreen.progressKey), findsOneWidget);
      expect(KycWizardState.totalCaptureSteps, 2);
    },
  );

  testWidgets(
    'AC4: tapping kyc_submit_cta chains to onboarding-funding (not status view)',
    (tester) async {
      var fundingNav = 0;
      final cubit = _newCubit(
        gateway: FakeKycGateway(decision: KycStatus.pending),
      );
      await tester.pumpWidget(
        _host(cubit, onSubmitted: (_) => fundingNav++),
      );
      await tester.pumpAndSettle();

      // The ID number is the one hard client gate (E3) — fill it first.
      await tester.enterText(
        find.byKey(KycIdentityStep.idNumberFieldKey),
        '123456789012',
      );
      await tester.pump();

      await tester.tap(find.byKey(KycIdentityStep.submitButtonKey));
      await tester.pump();
      await tester.pump();

      // The screen fired the funding-navigation hook exactly once...
      expect(fundingNav, 1);
      // ...and consumed the one-shot flag so it cannot re-fire.
      expect(cubit.state.justSubmitted, isFalse);
      expect(cubit.state.submission.status, KycStatus.pending);
    },
  );

  testWidgets(
    'submit is reachable without driving the camera (server validates photos; '
    'the typed ID number is the one client gate)',
    (tester) async {
      // Mirrors the JM-040 Maestro flow: it cannot drive the camera, so it
      // types the ID number (text input IS Maestro-drivable), taps
      // kyc_submit_cta, and expects the chain to funding to fire — photo
      // completeness stays back-office validated (JM-051 convention).
      var fundingNav = 0;
      final cubit = _newCubit(
        gateway: FakeKycGateway(decision: KycStatus.pending),
      );
      await tester.pumpWidget(
        _host(cubit, onSubmitted: (_) => fundingNav++),
      );
      await tester.pumpAndSettle();

      // No capture tiles tapped — just the ID number, then submit.
      await tester.enterText(
        find.byKey(KycIdentityStep.idNumberFieldKey),
        '123456789012',
      );
      await tester.pump();
      await tester.tap(find.byKey(KycIdentityStep.submitButtonKey));
      await tester.pump();
      await tester.pump();

      expect(fundingNav, 1);
    },
  );

  testWidgets(
    'blank/invalid ID number disables the CTA — a tap cannot fire a POST '
    '(review finding 1)',
    (tester) async {
      var fundingNav = 0;
      final cubit = _newCubit(
        gateway: FakeKycGateway(decision: KycStatus.pending),
      );
      await tester.pumpWidget(
        _host(cubit, onSubmitted: (_) => fundingNav++),
      );
      await tester.pumpAndSettle();

      // Blank ID number → tap does nothing.
      await tester.tap(find.byKey(KycIdentityStep.submitButtonKey));
      await tester.pump();
      await tester.pump();
      expect(fundingNav, 0);
      expect(cubit.state.step, KycWizardStep.identity);

      // 11 digits (boundary below the ^\d{12}$ rule) → still gated.
      await tester.enterText(
        find.byKey(KycIdentityStep.idNumberFieldKey),
        '12345678901',
      );
      await tester.pump();
      await tester.tap(find.byKey(KycIdentityStep.submitButtonKey));
      await tester.pump();
      await tester.pump();
      expect(fundingNav, 0);
      expect(cubit.state.submission.status, KycStatus.notSubmitted,
          reason: 'nothing may reach the gateway with an invalid id_number');
    },
  );

  testWidgets(
    'typing a too-short national ID surfaces the localized inline error',
    (tester) async {
      final cubit = _newCubit();
      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(KycIdentityStep.idNumberFieldKey),
        '12345',
      );
      await tester.pump();

      expect(
        find.text('Enter a valid 12-digit national ID number'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Eastern Arabic-Indic digits normalize to ASCII and satisfy the 12-digit '
    'gate (review finding 5)',
    (tester) async {
      final cubit = _newCubit();
      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(KycIdentityStep.idNumberFieldKey),
        '١٢٣٤٥٦٧٨٩٠١٢',
      );
      await tester.pump();

      expect(cubit.state.submission.idNumber, '123456789012');
      expect(cubit.state.submission.hasValidIdNumber, isTrue);
    },
  );

  testWidgets(
    'switching the ID type to passport relaxes the 12-digit rule and swaps '
    'the field label (E3/Q-042)',
    (tester) async {
      final cubit = _newCubit();
      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(KycIdentityStep.idTypePassportKey),
      );
      await tester.tap(find.byKey(KycIdentityStep.idTypePassportKey));
      await tester.pump();

      expect(cubit.state.submission.idType, KycIdType.passport);
      expect(find.text('Passport number'), findsOneWidget);

      await tester.enterText(
        find.byKey(KycIdentityStep.idNumberFieldKey),
        'P1234567',
      );
      await tester.pump();
      expect(cubit.state.submission.hasValidIdNumber, isTrue,
          reason: 'passport requires non-empty only — no 12-digit rule');
    },
  );

  testWidgets(
    'resubmit() clears the visible ID-number text — the field is bound to '
    'cubit state (review finding 4)',
    (tester) async {
      final cubit = _newCubit();
      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(KycIdentityStep.idNumberFieldKey),
        '123456789012',
      );
      await tester.pump();
      expect(find.text('123456789012'), findsOneWidget);
      expect(cubit.state.submission.idNumber, '123456789012');

      cubit.resubmit();
      await tester.pumpAndSettle();

      expect(cubit.state.submission.idNumber, isNull);
      expect(find.text('123456789012'), findsNothing,
          reason: 'an uncontrolled field would keep showing the old digits');
    },
  );

  testWidgets(
    're-entry on an already-submitted KYC shows the status view, not funding',
    (tester) async {
      var fundingNav = 0;
      final shared = FakeKycGateway(decision: KycStatus.approved);
      // Pre-submit via a seeder cubit.
      final seeder = KycWizardCubit(
        pickerService: StubPhotoPickerService(cameraPayload: _bytes(1024)),
        gateway: shared,
      );
      addTearDown(seeder.close);
      await seeder.loadSchema();
      await seeder.captureIdFront();
      await seeder.captureIdBack();
      await seeder.captureSelfie();
      seeder.setIdNumber('123456789012');
      seeder.setTosAccepted(true);
      await seeder.submit();

      // A fresh cubit re-entering the wizard against the same gateway.
      final reentry = KycWizardCubit(
        pickerService: StubPhotoPickerService(cameraPayload: _bytes(1024)),
        gateway: shared,
      )..loadStatus();
      addTearDown(reentry.close);

      await tester.pumpWidget(
        _host(reentry, onSubmitted: (_) => fundingNav++),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(KycStatusView.approvedTitleKey), findsOneWidget);
      expect(fundingNav, 0, reason: 're-entry must not chain to funding');
    },
  );

  testWidgets(
    're-entry on a rejected KYC shows the view-rejection CTA and no resubmit (D52/D87)',
    (tester) async {
      // Preserves the JM-042/043 coverage: the rejected status branch exposes
      // `kyc_status_view_rejection` and NEVER a resubmit CTA (rejection is final).
      final shared = FakeKycGateway(
        decision: KycStatus.rejected,
        rejectionReason: KycRejectionReason.idUnreadable,
      );
      final seeder = KycWizardCubit(
        pickerService: StubPhotoPickerService(cameraPayload: _bytes(1024)),
        gateway: shared,
      );
      addTearDown(seeder.close);
      await seeder.loadSchema();
      await seeder.captureIdFront();
      await seeder.captureIdBack();
      await seeder.captureSelfie();
      seeder.setIdNumber('123456789012');
      seeder.setTosAccepted(true);
      await seeder.submit();

      final reentry = KycWizardCubit(
        pickerService: StubPhotoPickerService(cameraPayload: _bytes(1024)),
        gateway: shared,
      )..loadStatus();
      addTearDown(reentry.close);

      await tester.pumpWidget(_host(reentry));
      await tester.pumpAndSettle();

      expect(find.byKey(KycStatusView.rejectedTitleKey), findsOneWidget);
      expect(_byIdentifier('kyc_status_view_rejection'), findsOneWidget);
      // No resubmit affordance (the old key was removed under D52/D87).
      expect(_byIdentifier('kyc_status_resubmit_cta'), findsNothing);
    },
  );
}
