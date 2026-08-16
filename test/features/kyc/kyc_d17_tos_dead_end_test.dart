// D17 — "Submit for review" was a silent dead end.
//
// On the live stack `GET /v1/kyc/contract-template` answered 404 ("No
// contract-signing template named 'jeeb_tos_v1' is registered"). The wizard
// then (a) reported it as `submitFailed`, whose copy blames the user's
// connection for a server-side misconfiguration, and (b) had the screen's own
// error listener call `acknowledgeError()` unconditionally, wiping
// `state.error` on the next frame so nothing durable was ever rendered. The
// user saw a button that appeared to do nothing.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_state.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_contract_template.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_wizard_screen.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_identity_step.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

Uint8List _bytes(int length) => Uint8List(length)..fillRange(0, length, 0x42);

/// Reproduces the live 404: the gateway cannot resolve the ToS template, so
/// `fetchContractTemplate` throws before anything is signed or submitted.
class _MissingTosTemplateGateway extends FakeKycGateway {
  int submitCalls = 0;
  int signCalls = 0;
  bool templateRegistered = false;

  @override
  Future<KycContractTemplate> fetchContractTemplate() async {
    if (!templateRegistered) {
      throw StateError(
        "404 ToS template not found: No contract-signing template named "
        "'jeeb_tos_v1' is registered.",
      );
    }
    return super.fetchContractTemplate();
  }

  @override
  Future<KycSignStamp> signContract({
    required String templateId,
    required String tosVersion,
    required String signatureBlob,
  }) {
    signCalls++;
    return super.signContract(
      templateId: templateId,
      tosVersion: tosVersion,
      signatureBlob: signatureBlob,
    );
  }

  @override
  Future<KycSubmission> submit(KycSubmission draft) {
    submitCalls++;
    return super.submit(draft);
  }
}

/// The template resolves but the signature ceremony upstream rejects it.
class _FailingSignGateway extends FakeKycGateway {
  int submitCalls = 0;

  @override
  Future<KycSignStamp> signContract({
    required String templateId,
    required String tosVersion,
    required String signatureBlob,
  }) =>
      Future<KycSignStamp>.error(StateError('502 signature ceremony failed'));

  @override
  Future<KycSubmission> submit(KycSubmission draft) {
    submitCalls++;
    return super.submit(draft);
  }
}

/// Template + signature succeed; only the submission POST fails.
class _FailingSubmitGateway extends FakeKycGateway {
  @override
  Future<KycSubmission> submit(KycSubmission draft) =>
      Future<KycSubmission>.error(StateError('dropped response'));

  @override
  Future<KycSubmission> fetchStatus() async =>
      const KycSubmission(status: KycStatus.notSubmitted);
}

KycWizardCubit _buildCubit(KycGateway gateway) {
  final cubit = KycWizardCubit(
    pickerService: StubPhotoPickerService(cameraPayload: _bytes(100 * 1024)),
    gateway: gateway,
  );
  addTearDown(cubit.close);
  return cubit;
}

Future<void> _completeIdentity(KycWizardCubit cubit) async {
  await cubit.loadSchema();
  await cubit.captureIdFront();
  await cubit.captureIdBack();
  await cubit.captureSelfie();
  cubit.setIdNumber('123456789012');
  cubit.setTosAccepted(true);
}

void main() {
  group('D17 · the submit phases report their own failure', () {
    test('a missing ToS template is contractLoadFailed, never submitFailed',
        () async {
      final gateway = _MissingTosTemplateGateway();
      final cubit = _buildCubit(gateway);
      await _completeIdentity(cubit);

      await cubit.submit();

      expect(cubit.state.error, KycWizardError.contractLoadFailed);
      expect(cubit.state.error, isNot(KycWizardError.submitFailed),
          reason: 'submitFailed reads "check your connection" — the connection '
              'was fine; the server has no ToS template registered');
      expect(cubit.state.step, KycWizardStep.identity);
      expect(gateway.signCalls, 0,
          reason: 'nothing may be signed against a template we could not read');
      expect(gateway.submitCalls, 0,
          reason: 'no KYC submission may be created without ToS acceptance');
    });

    test(
        'CONTROL: the same gateway submits cleanly once the template resolves, '
        'so the failure above is the missing template and not a dead fake',
        () async {
      final gateway = _MissingTosTemplateGateway()..templateRegistered = true;
      final cubit = _buildCubit(gateway);
      await _completeIdentity(cubit);

      await cubit.submit();

      expect(cubit.state.error, isNull);
      expect(cubit.state.step, KycWizardStep.status);
      expect(gateway.signCalls, 1);
      expect(gateway.submitCalls, 1);
    });

    test('a rejected signature ceremony is signFailed and submits nothing',
        () async {
      final gateway = _FailingSignGateway();
      final cubit = _buildCubit(gateway);
      await _completeIdentity(cubit);

      await cubit.submit();

      expect(cubit.state.error, KycWizardError.signFailed);
      expect(gateway.submitCalls, 0);
    });

    test('REGRESSION: a failed submission POST is still submitFailed',
        () async {
      final cubit = _buildCubit(_FailingSubmitGateway());
      await _completeIdentity(cubit);

      await cubit.submit();

      expect(cubit.state.error, KycWizardError.submitFailed);
      expect(cubit.state.step, KycWizardStep.identity);
    });
  });

  group('D17 · the dead end is visible and stays visible', () {
    Future<KycWizardCubit> pumpWizard(
      WidgetTester tester,
      KycGateway gateway,
    ) async {
      final cubit = _buildCubit(gateway);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.midnight(),
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            SyncAppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: KycWizardScreen(cubit: cubit),
            ),
          ),
        ),
      );
      await tester.pump();
      return cubit;
    }

    testWidgets(
        'a missing ToS template renders a persistent error with a retry — it '
        'must NOT be a snackbar that expires into an untouched-looking form',
        (tester) async {
      final cubit = await pumpWizard(tester, _MissingTosTemplateGateway());
      await _completeIdentity(cubit);
      await tester.pump();

      await cubit.submit();
      await tester.pump();
      await tester.pump();

      // Long past any snackbar's life.
      await tester.pump(const Duration(seconds: 10));

      expect(find.byType(JeebEmptyState), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(KycIdentityStep), findsNothing);
      expect(cubit.state.error, KycWizardError.contractLoadFailed,
          reason: 'the screen listener must not consume an error that owns a '
              'persistent surface');
    });

    testWidgets(
        'CONTROL: with no error the same screen shows the identity form and no '
        'error block',
        (tester) async {
      final cubit = await pumpWizard(tester, _MissingTosTemplateGateway());
      await _completeIdentity(cubit);
      await tester.pump(const Duration(seconds: 10));

      expect(find.byType(KycIdentityStep), findsOneWidget);
      expect(find.byType(JeebEmptyState), findsNothing);
    });
  });
}
