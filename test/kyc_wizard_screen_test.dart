import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/role/role_availability_cubit.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_state.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_status_view.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_wizard_screen.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_identity_step.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_submitting_view.dart';
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

/// Host that also provides the app-root [RoleAvailabilityCubit] above the
/// wizard, so the JEBV4-271 round-3 role-arrived listener is wired (production
Widget _hostWithRoles(
  KycWizardCubit cubit,
  RoleAvailabilityCubit availability, {
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
    home: BlocProvider<RoleAvailabilityCubit>.value(
      value: availability,
      child: KycWizardScreen(cubit: cubit, onSubmitted: onSubmitted),
    ),
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

/// Mimics the on-device submit-hang: `submit()` NEVER resolves (a stalled CDN
/// upload / a 201 the client never receives), while the server-side status is
/// scripted so the submitting-view safety-net poll can reconcile against it.
class _HangingSubmitKycGateway extends FakeKycGateway {
  _HangingSubmitKycGateway({required this.serverStatus});

  final KycStatus serverStatus;

  @override
  Future<KycSubmission> submit(KycSubmission draft) =>
      Completer<KycSubmission>().future; // never resolves

  @override
  Future<KycSubmission> fetchStatus() async =>
      KycSubmission(status: serverStatus, submittedAt: DateTime.now());
}

/// JEBV4-295: throws a field-scoped BFF rejection on submit, mimicking the
/// RFC-7807 `field` extension the live gateway returns on a 400.
class _FieldRejectingKycGateway extends FakeKycGateway {
  _FieldRejectingKycGateway(this.field);

  final String field;

  @override
  Future<KycSubmission> submit(KycSubmission draft) {
    throw KycSubmitFieldException(field: field, detail: 'server said no');
  }
}

void main() {
  setUpAll(_loadArbFromDisk);

  testWidgets(
    'identity screen renders all three uploads, the submit CTA, and no vehicle step',
    (tester) async {
      final cubit = _newCubit();
      await tester.pumpWidget(_host(cubit));
      await tester.pumpAndSettle();

      expect(_byIdentifier('kyc_wizard_root'), findsOneWidget);

      expect(_byIdentifier('kyc_id_front_upload'), findsOneWidget);
      expect(_byIdentifier('kyc_id_back_upload'), findsOneWidget);
      expect(_byIdentifier('kyc_selfie_upload'), findsOneWidget);

      expect(_byIdentifier('kyc_id_type_picker'), findsOneWidget);
      expect(_byIdentifier('kyc_id_type_national_id'), findsOneWidget);
      expect(_byIdentifier('kyc_id_type_passport'), findsOneWidget);
      expect(_byIdentifier('kyc_id_type_residency'), findsOneWidget);
      expect(_byIdentifier('kyc_id_number_input'), findsOneWidget);
      expect(find.byKey(KycIdentityStep.idNumberFieldKey), findsOneWidget);

      expect(_byIdentifier('kyc_submit_cta'), findsOneWidget);
      expect(find.byKey(KycIdentityStep.submitButtonKey), findsOneWidget);

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

      // JEBV4-295: the selfie is a hard client gate alongside the ID number.
      await cubit.captureSelfie();
      // The ID number is the other hard client gate (E3) — fill it too.
      await tester.enterText(
        find.byKey(KycIdentityStep.idNumberFieldKey),
        '123456789012',
      );
      await tester.pump();

      await tester.tap(find.byKey(KycIdentityStep.submitButtonKey));
      await tester.pump();
      await tester.pump();

      expect(fundingNav, 1);
      expect(cubit.state.justSubmitted, isFalse);
      expect(cubit.state.submission.status, KycStatus.pending);
    },
  );

  testWidgets(
    'JEBV4-271: an AUTO-APPROVED submit (gateway decision approved) renders the '
    'in-wizard approved status view and does NOT chain to onboarding-funding '
    '(so KycStatusView._ApprovedBody activates the jeeber role in-session)',
    (tester) async {
      var fundingNav = 0;
      final cubit = _newCubit(
        gateway: FakeKycGateway(decision: KycStatus.approved),
      );
      await tester.pumpWidget(
        _host(cubit, onSubmitted: (_) => fundingNav++),
      );
      await tester.pumpAndSettle();

      // JEBV4-295: the selfie is a hard client gate alongside the ID number.
      await cubit.captureSelfie();
      await tester.enterText(
        find.byKey(KycIdentityStep.idNumberFieldKey),
        '123456789012',
      );
      await tester.pump();

      await tester.tap(find.byKey(KycIdentityStep.submitButtonKey));
      await tester.pumpAndSettle();

      expect(fundingNav, 0,
          reason: 'auto-approve must not navigate away to onboarding-funding');
      expect(cubit.state.justSubmitted, isFalse);
      expect(cubit.state.submission.status, KycStatus.approved);
      expect(find.byKey(KycStatusView.approvedTitleKey), findsOneWidget);
    },
  );

  testWidgets(
    'JEBV4-259/271: a HUNG submit auto-recovers — the submitting-view poller '
    'reconciles against the server (Verified) after the grace window and '
    'advances to the approved status view with NO force-stop',
    (tester) async {
      var fundingNav = 0;
      final cubit = _newCubit(
        gateway: _HangingSubmitKycGateway(serverStatus: KycStatus.approved),
      );
      await tester.pumpWidget(_host(cubit, onSubmitted: (_) => fundingNav++));
      await tester.pumpAndSettle();

      // JEBV4-295: the selfie is a hard client gate alongside the ID number.
      await cubit.captureSelfie();
      await tester.enterText(
        find.byKey(KycIdentityStep.idNumberFieldKey),
        '123456789012',
      );
      await tester.pump();

      // Submit → the wizard shows the submitting spinner and STAYS there (the
      await tester.tap(find.byKey(KycIdentityStep.submitButtonKey));
      await tester.pump();
      expect(find.byKey(KycSubmittingView.rootKey), findsOneWidget);
      expect(find.byKey(KycStatusView.approvedTitleKey), findsNothing,
          reason: 'still stuck before the grace window elapses');

      // Advance past the safety-net grace window (12s). The poller re-reads the
      await tester.pump(const Duration(seconds: 13));
      await tester.pump(); // apply the emitted status transition
      await tester.pumpAndSettle();

      expect(find.byKey(KycSubmittingView.rootKey), findsNothing);
      expect(find.byKey(KycStatusView.approvedTitleKey), findsOneWidget);
      expect(fundingNav, 0,
          reason: 'the recovered submit lands on the in-wizard approved status '
              'view (which activates the jeeber role), never funding');
    },
  );

  testWidgets(
    'JEBV4-271 (round 3): a HUNG submit auto-recovers off the role-arrived '
    'signal — when the getMe available_roles projection gains jeeber, the '
    'wizard advances off the spinner to the approved status view (no restart, '
    'no /kyc/status poll)',
    (tester) async {
      var fundingNav = 0;
      final cubit = _newCubit(
        gateway: _HangingSubmitKycGateway(serverStatus: KycStatus.approved),
      );
      final availability = RoleAvailabilityCubit();
      addTearDown(availability.close);
      await tester.pumpWidget(
        _hostWithRoles(cubit, availability, onSubmitted: (_) => fundingNav++),
      );
      await tester.pumpAndSettle();

      // JEBV4-295: the selfie is a hard client gate alongside the ID number.
      await cubit.captureSelfie();
      await tester.enterText(
        find.byKey(KycIdentityStep.idNumberFieldKey),
        '123456789012',
      );
      await tester.pump();

      // Submit hangs → the wizard is stranded on the submit spinner.
      await tester.tap(find.byKey(KycIdentityStep.submitButtonKey));
      await tester.pump();
      expect(find.byKey(KycSubmittingView.rootKey), findsOneWidget);
      expect(find.byKey(KycStatusView.approvedTitleKey), findsNothing);

      // The jeeber role lands out-of-band via /v1/users/me (RoleSync publishes
      availability.setAvailableRoles(const ['client', 'jeeber']);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(KycSubmittingView.rootKey), findsNothing);
      expect(find.byKey(KycStatusView.approvedTitleKey), findsOneWidget);
      expect(cubit.state.submission.status, KycStatus.approved);
      expect(fundingNav, 0,
          reason: 'the role-recovered submit lands on the in-wizard approved '
              'view (which activates the jeeber role), never funding');
    },
  );

  testWidgets(
    'submit is reachable without driving the ID front/back camera (server '
    'validates ID-photo completeness; only the ID number + selfie are '
    'client gates)',
    (tester) async {
      // Mirrors the JM-040 Maestro flow for the gov-ID photos: it cannot
      var fundingNav = 0;
      final cubit = _newCubit(
        gateway: FakeKycGateway(decision: KycStatus.pending),
      );
      await tester.pumpWidget(
        _host(cubit, onSubmitted: (_) => fundingNav++),
      );
      await tester.pumpAndSettle();

      // No ID front/back tiles tapped — only the selfie + the ID number.
      await cubit.captureSelfie();
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

  group('JEBV4-295: identity-step UX gaps', () {
    testWidgets(
      'submit-disabled-without-selfie: a VALID id number alone must NOT '
      'unlock the CTA — tapping it fires no POST until a selfie is captured',
      (tester) async {
        var fundingNav = 0;
        final gateway = FakeKycGateway(decision: KycStatus.pending);
        final cubit = _newCubit(gateway: gateway);
        await tester.pumpWidget(
          _host(cubit, onSubmitted: (_) => fundingNav++),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(KycIdentityStep.idNumberFieldKey),
          '123456789012',
        );
        await tester.pump();
        expect(cubit.state.submission.hasValidIdNumber, isTrue);

        // A valid ID number alone must NOT enable the CTA — the selfie is a
        await tester.tap(find.byKey(KycIdentityStep.submitButtonKey));
        await tester.pump();
        await tester.pump();
        expect(fundingNav, 0,
            reason: 'a valid ID number without a selfie must never reach '
                'the network');
        expect(cubit.state.submission.status, KycStatus.notSubmitted);
        expect(cubit.state.step, KycWizardStep.identity);

        // Capturing the selfie unlocks the CTA.
        await cubit.captureSelfie();
        await tester.pump();
        expect(cubit.state.submission.hasSelfie, isTrue);
        await tester.tap(find.byKey(KycIdentityStep.submitButtonKey));
        await tester.pump();
        await tester.pump();
        expect(fundingNav, 1,
            reason: 'once the selfie is captured the same tap now submits');
      },
    );

    testWidgets(
      'the RTL-safe scroll-for-selfie cue (kyc_scroll_hint) is visible '
      'before the selfie is captured, and hidden once it is',
      (tester) async {
        final cubit = _newCubit();
        await tester.pumpWidget(_host(cubit));
        await tester.pumpAndSettle();

        expect(_byIdentifier('kyc_scroll_hint'), findsOneWidget,
            reason: 'the selfie section is below the fold and not yet '
                'captured — the affordance must be visible');

        await cubit.captureSelfie();
        await tester.pumpAndSettle();

        expect(_byIdentifier('kyc_scroll_hint'), findsNothing,
            reason: 'once the selfie is captured the cue has nothing left '
                'to prompt for');
      },
    );

    testWidgets(
      'tapping kyc_scroll_hint scrolls the identity screen towards the '
      'selfie tile',
      (tester) async {
        // The redesign (screen 22) shortened the column by ~340pt, so the
        // "selfie is below the fold" precondition would otherwise depend on
        // the harness's 800×600 luck. Pin a real phone viewport instead of
        // weakening the assertions.
        tester.view.physicalSize = const Size(1080, 1920); // 360×640 @3x
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final cubit = _newCubit();
        await tester.pumpWidget(_host(cubit));
        await tester.pumpAndSettle();

        expect(find.byKey(KycIdentityStep.selfieTileKey).hitTestable(),
            findsNothing);

        // The cue itself sits at the ID/selfie fold boundary and may also
        await tester.ensureVisible(
          find.byKey(KycIdentityStep.scrollHintKey),
        );
        await tester.pump();
        await tester.tap(find.byKey(KycIdentityStep.scrollHintKey));
        // Let the scroll animation run to completion.
        await tester.pumpAndSettle();

        expect(find.byKey(KycIdentityStep.selfieTileKey).hitTestable(),
            findsOneWidget,
            reason: 'the scroll-hint tap must reveal the selfie tile');
      },
    );

    testWidgets(
      'an unmapped field-400 surfaces its real (validation) message, never '
      'the generic "check your connection" copy',
      (tester) async {
        final cubit = _newCubit(
          gateway: _FieldRejectingKycGateway('tos_accepted_version'),
        );
        await tester.pumpWidget(_host(cubit));
        await tester.pumpAndSettle();

        await cubit.captureSelfie();
        await tester.enterText(
          find.byKey(KycIdentityStep.idNumberFieldKey),
          '123456789012',
        );
        await tester.pump();

        await tester.tap(find.byKey(KycIdentityStep.submitButtonKey));
        await tester.pump();
        await tester.pump();

        final message = await _syncDelegate.load(const Locale('en'));
        expect(find.text(message.kycErrorSubmitValidationFailed),
            findsOneWidget,
            reason: 'a field-scoped 400 is a validation rejection, not a '
                'connectivity failure');
        expect(find.text(message.kycErrorSubmitFailed), findsNothing,
            reason: 'the mislabeled "check your connection" toast must not '
                'appear for a validation 400');
      },
    );
  });

  group('redesign-2026-08 (screen 22): the identity checklist', () {
    testWidgets(
      'the selfie row is locked until BOTH ID sides exist — and the lock is '
      'presentation-only (the cubit path stays open for Maestro/tests)',
      (tester) async {
        final cubit = _newCubit();
        await tester.pumpWidget(_host(cubit));
        await tester.pumpAndSettle();

        final locked =
            tester.widget<Semantics>(find.byKey(KycIdentityStep.selfieTileKey));
        expect(locked.properties.enabled, isFalse,
            reason: 'step 2 has not opened yet');

        await tester.ensureVisible(find.byKey(KycIdentityStep.selfieTileKey));
        await tester.tap(
          find.byKey(KycIdentityStep.selfieTileKey),
          warnIfMissed: false,
        );
        await tester.pump();
        expect(cubit.state.capturing, isNull,
            reason: 'the locked row must not open the camera');
        expect(cubit.state.submission.hasSelfie, isFalse);

        // Both ID sides captured → the row unlocks.
        await cubit.captureIdFront();
        await cubit.captureIdBack();
        await tester.pumpAndSettle();

        final unlocked =
            tester.widget<Semantics>(find.byKey(KycIdentityStep.selfieTileKey));
        expect(unlocked.properties.enabled, isTrue);

        // JEBV4-295 / JM-040: the cubit itself never enforces the gate.
        expect(cubit.state.isSelfieUnlocked, isTrue);
      },
    );

    testWidgets(
      'a captured row reports its captured sub-line',
      (tester) async {
        final cubit = _newCubit();
        await tester.pumpWidget(_host(cubit));
        await tester.pumpAndSettle();

        final message = await _syncDelegate.load(const Locale('en'));
        expect(find.text(message.kycCaptureCaptured), findsNothing);

        await cubit.captureIdFront();
        await tester.pump();
        await tester.pump();

        expect(find.text(message.kycCaptureCaptured), findsOneWidget);
      },
    );

    testWidgets(
      'kyc_review_note states the review time on the identity step',
      (tester) async {
        final cubit = _newCubit();
        await tester.pumpWidget(_host(cubit));
        await tester.pumpAndSettle();

        expect(_byIdentifier('kyc_review_note'), findsOneWidget);
        final message = await _syncDelegate.load(const Locale('en'));
        expect(find.text(message.kycReviewTimeTitle), findsOneWidget);
      },
    );

    testWidgets(
      'kyc_tos_read_cta opens the terms document sheet (submit signs a '
      'contract, so the document must stay reachable before signing)',
      (tester) async {
        final cubit = _newCubit();
        await tester.pumpWidget(_host(cubit));
        await tester.pumpAndSettle();

        expect(_byIdentifier('kyc_tos_document_sheet'), findsNothing);

        await tester.ensureVisible(_byIdentifier('kyc_tos_read_cta'));
        await tester.pump();
        await tester.tap(_byIdentifier('kyc_tos_read_cta'));
        await tester.pumpAndSettle();

        expect(_byIdentifier('kyc_tos_document_sheet'), findsOneWidget);
        final message = await _syncDelegate.load(const Locale('en'));
        expect(find.text(message.kycTosDocumentBody), findsOneWidget);
      },
    );
  });

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
      expect(_byIdentifier('kyc_status_resubmit_cta'), findsNothing);
    },
  );

  testWidgets(
    're-entry on a resubmit-requested KYC shows the resubmit CTA + steps, '
    'distinct from the final rejected branch',
    (tester) async {
      final shared = FakeKycGateway(
        initial: const KycSubmission(
          status: KycStatus.resubmitRequested,
          rejectionReason: KycRejectionReason.idUnreadable,
          resubmitSteps: [KycResubmitStep.idFront, KycResubmitStep.selfie],
        ),
      );
      final reentry = KycWizardCubit(
        pickerService: StubPhotoPickerService(cameraPayload: _bytes(1024)),
        gateway: shared,
      )..loadStatus();
      addTearDown(reentry.close);

      await tester.pumpWidget(_host(reentry));
      await tester.pumpAndSettle();

      expect(find.byKey(KycStatusView.resubmitTitleKey), findsOneWidget);
      expect(_byIdentifier('kyc_status_resubmit_cta'), findsOneWidget);
      expect(_byIdentifier('kyc_status_resubmit_steps'), findsOneWidget);
      expect(find.byKey(KycStatusView.rejectedTitleKey), findsNothing);
      expect(_byIdentifier('kyc_status_view_rejection'), findsNothing);
    },
  );

  testWidgets(
    'tapping the resubmit CTA re-opens the wizard on the identity capture step',
    (tester) async {
      final shared = FakeKycGateway(
        initial: const KycSubmission(
          status: KycStatus.resubmitRequested,
          rejectionReason: KycRejectionReason.idUnreadable,
          resubmitSteps: [KycResubmitStep.idFront],
        ),
      );
      final reentry = KycWizardCubit(
        pickerService: StubPhotoPickerService(cameraPayload: _bytes(1024)),
        gateway: shared,
      )..loadStatus();
      addTearDown(reentry.close);

      await tester.pumpWidget(_host(reentry));
      await tester.pumpAndSettle();
      expect(find.byKey(KycStatusView.resubmitTitleKey), findsOneWidget);

      await tester.tap(_byIdentifier('kyc_status_resubmit_cta'));
      await tester.pumpAndSettle();

      expect(find.byKey(KycStatusView.resubmitTitleKey), findsNothing);
      expect(_byIdentifier('kyc_submit_cta'), findsOneWidget);
      expect(_byIdentifier('kyc_id_front_upload'), findsOneWidget);
    },
  );
}
