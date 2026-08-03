// Render tests for the KycWizardScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/previews/jeeb_preview.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/kyc_wizard_screen_fixtures.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_status_view.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_wizard_screen.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_identity_step.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_submitting_view.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/load_test_fonts.dart';
import '../../support/sync_app_localizations.dart';
import '../preview_test_harness.dart';

/// Exact ARB copy, so a reworded string breaks the test instead of silently
/// unpinning the preview.
const String _wizardTitle = 'Verify your identity';
const String _scrollHint = 'Scroll for selfie';
const String _schemaLoadFailed =
    "Couldn't load the form. Check your connection and try again.";
const String _retryCta = 'Retry';
const String _submittingTitle = 'Submitting your documents';
const String _pendingTitle = 'Submission received';
const String _approvedTitle = "You're approved";
const String _idUnreadable =
    "We couldn't read the ID photos. "
    'Make sure both sides are sharp and well-lit.';
const String _stepOneOfTwo = 'Step 1 of 2';
const String _stepTwoOfTwo = 'Step 2 of 2';
const String _pendingTitleAr = 'تم استلام الطلب';

/// The seeded document numbers, one per identity preview, which is what makes
/// each of them identifiable from its rendering alone.
const String _nationalIdNumber =
    KycWizardScreenPreviewFixtures.nationalIdNumber;
const String _passportNumber = KycWizardScreenPreviewFixtures.passportNumber;

/// One marker per body, so the state with NO text of its own can be pinned by
/// asserting that none of the other three is on screen.
const List<String> _otherBodyMarkers = <String>[
  _scrollHint,
  _schemaLoadFailed,
  _submittingTitle,
  _pendingTitle,
  _approvedTitle,
  _idUnreadable,
];

Finder _byIdentifier(String id) {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is Semantics && widget.properties.identifier == id,
  );
}

/// How many pixels a captured layout error overflowed by, or 0 when [error] is
/// not an overflow at all. Read from the message rather than pinned as an exact
int _overflowPixels(Object? error) {
  if (error == null) return 0;
  final RegExpMatch? match = RegExp(
    r'overflowed by ([\d.]+) pixels',
  ).firstMatch('$error');
  if (match == null) return 0;
  return double.parse(match.group(1)!).round();
}

/// [previewCanvas] with the real font faces installed on the theme.
/// The shared canvas builds `AppTheme.light()` unmodified and the theme carries
Widget _kycWizardScreenCanvas(Widget Function() preview, Locale locale) {
  return MaterialApp(
    theme: withGoldenTestFonts(AppTheme.light()),
    darkTheme: withGoldenTestFonts(AppTheme.dark()),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object?>>[
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: jeebPreviewHost(preview()),
  );
}

/// Pumps a preview into the real device box the annotation declares, at
/// [textScale] and with the REAL faces, instead of into the 800 x 600 default
Future<void> _pumpInDeviceBox(
  WidgetTester tester,
  Widget Function() preview, {
  required double textScale,
  Size box = const Size(390, 844),
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = box;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: _kycWizardScreenCanvas(preview, locale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadInterTestFont();
    loadPreviewArbs();
  });

  testPreviewsRender(
    'KycWizardScreen',
    const <String, Widget Function()>{
      'Identity · cold entry': kycWizardScreenIdentityColdEntry,
      'Identity · ready to submit': kycWizardScreenIdentityReadyToSubmit,
      'Schema · load in flight': kycWizardScreenSchemaLoading,
      'Schema · load FAILED (retry unreachable in-app)':
          kycWizardScreenSchemaLoadFailed,
      'Submitting · POST hung': kycWizardScreenSubmitting,
      'Status · pending review': kycWizardScreenStatusPending,
      'Status · approved': kycWizardScreenStatusApproved,
      'Status · rejected': kycWizardScreenStatusRejected,
      'Longest content · compact 320': kycWizardScreenCompactCeiling,
    },
    expectedText: const <String, String>{
      // The affordance that exists only while no selfie is captured — so it is
      'Identity · cold entry': _scrollHint,
      // The two identity states that ARE fully captured are told apart by the
      'Identity · ready to submit': _nationalIdNumber,
      'Longest content · compact 320': _passportNumber,
      // The failure line `_SchemaErrorView` renders, which no other state can
      'Schema · load FAILED (retry unreachable in-app)': _schemaLoadFailed,
      'Submitting · POST hung': _submittingTitle,
      'Status · pending review': _pendingTitle,
      'Status · approved': _approvedTitle,
      'Status · rejected': _idUnreadable,
      // 'Schema · load in flight' renders a bare spinner and no text at all; it
    },
  );

  group('KycWizardScreen preview specifics', () {
    // NB: one preview per test. Pumping a second preview into the same tester

    testWidgets('every body keeps the wizard AppBar', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycWizardScreenStatusApproved);

      expect(find.text(_wizardTitle), findsOneWidget);
      expect(find.byKey(KycWizardScreen.rootKey), findsOneWidget);
      expect(_byIdentifier('kyc_wizard_root'), findsOneWidget);
    });

    testWidgets('the schema read in flight is a bare spinner and NOTHING else', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycWizardScreenSchemaLoading);

      expect(find.byType(OmdsLoadingState), findsOneWidget);
      expect(find.text(_wizardTitle), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
      for (final String marker in _otherBodyMarkers) {
        expect(find.text(marker), findsNothing, reason: marker);
      }
      expect(_byIdentifier('kyc_wizard_retry_cta'), findsNothing);
    });

    testWidgets('the FAILED branch is the only thing in this feature that '
        'offers a retry', (WidgetTester tester) async {
      await pumpPreview(tester, kycWizardScreenSchemaLoadFailed);

      expect(find.text(_schemaLoadFailed), findsOneWidget);
      expect(_byIdentifier('kyc_wizard_retry_cta'), findsOneWidget);
      expect(find.text(_retryCta), findsOneWidget);
      expect(find.byType(OmdsLoadingState), findsNothing);
    });

    testWidgets('a schema load that fails IN-APP never renders the retry: the '
        "wizard's own error listener acknowledges the failure in the same turn",
        (WidgetTester tester) async {
      final KycWizardCubit cubit = KycWizardCubit(
        pickerService: StubPhotoPickerService(),
        gateway: KycWizardScreenPreviewGateway(schemaFails: true),
      );
      addTearDown(cubit.close);

      await tester.pumpWidget(
        previewCanvas(
          () => TickerMode(
            enabled: false,
            child: KycWizardScreen(cubit: cubit, onSubmitted: (_) {}),
          ),
          const Locale('en'),
        ),
      );
      await tester.pump();
      expect(_byIdentifier('kyc_wizard_retry_cta'), findsNothing);

      // The real path: `loadSchema` catches the gateway failure and emits
      await cubit.loadSchema();
      await tester.pump();

      expect(
        cubit.state.error,
        isNull,
        reason: '_surfaceError called acknowledgeError() on the same emit',
      );
      expect(
        _byIdentifier('kyc_wizard_retry_cta'),
        findsNothing,
        reason: 'the retry CTA cannot survive its own error flag',
      );
      expect(
        find.byType(OmdsLoadingState),
        findsOneWidget,
        reason: 'the body degrades back to the indefinite schema spinner',
      );
      expect(find.text(_schemaLoadFailed), findsOneWidget);

      // Unmount so the snackbar's auto-dismiss timer is cancelled with its
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets('the progress header floors at "Step 1 of 2" on an empty form', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycWizardScreenIdentityColdEntry);

      expect(find.byKey(KycWizardScreen.progressKey), findsOneWidget);
      expect(find.text(_stepOneOfTwo), findsOneWidget);
      expect(find.text(_stepTwoOfTwo), findsNothing);
      expect(find.byKey(KycIdentityStep.submitButtonKey), findsOneWidget);
    });

    testWidgets('a fully captured form reads "Step 2 of 2" and arms the CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycWizardScreenIdentityReadyToSubmit);

      expect(find.text(_stepTwoOfTwo), findsOneWidget);
      expect(find.text(_scrollHint), findsNothing);
      expect(
        tester
            .widget<OmdsPrimaryButton>(
              find.byKey(KycIdentityStep.submitButtonKey),
            )
            .isEnabled,
        isTrue,
        reason: 'the catalog state labelled "ready to submit" must actually be '
            'ready — the gate is hasSelfie && hasValidIdNumber (JEBV4-295/E3)',
      );
    });

    testWidgets('the submit spinner replaces the whole form', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycWizardScreenSubmitting);

      expect(find.byKey(KycSubmittingView.rootKey), findsOneWidget);
      expect(find.text(_submittingTitle), findsOneWidget);
      expect(find.byKey(KycWizardScreen.progressKey), findsNothing);
      expect(find.byKey(KycIdentityStep.submitButtonKey), findsNothing);
      expect(find.text(_stepTwoOfTwo), findsNothing);
    });

    testWidgets('the pending body is caught with its automatic re-check IN '
        'FLIGHT', (WidgetTester tester) async {
      await pumpPreview(tester, kycWizardScreenStatusPending);

      expect(find.byKey(KycStatusView.pendingTitleKey), findsOneWidget);
      final OmdsLoadingButton cta = tester.widget<OmdsLoadingButton>(
        find.byKey(KycStatusView.checkAgainCtaKey),
      );
      expect(
        cta.isLoading,
        isTrue,
        reason: 'the frame clock must have run past the 3 s first probe — if '
            'this fails the fixture is showing a pre-probe frame, and the '
            'render test is no longer covering the state it claims to',
      );
      expect(_byIdentifier('kyc_status_poll_expired'), findsNothing);
      expect(
        tester.getTopLeft(_byIdentifier('kyc_status_topup_cta')).dy,
        lessThan(
          tester.getTopLeft(find.byKey(KycStatusView.checkAgainCtaKey)).dy,
        ),
      );
    });

    testWidgets('rejection is final: a reason and no resubmit CTA (D52/D87)', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, kycWizardScreenStatusRejected);

      expect(find.byKey(KycStatusView.rejectedTitleKey), findsOneWidget);
      expect(find.text(_idUnreadable), findsOneWidget);
      expect(_byIdentifier('kyc_status_view_rejection'), findsOneWidget);
      expect(_byIdentifier('kyc_status_resubmit_cta'), findsNothing);
    });

    testWidgets('every state localizes: no English leaks into the AR reading', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        kycWizardScreenStatusPending,
        locale: const Locale('ar'),
      );

      expect(find.text(_pendingTitleAr), findsOneWidget);
      expect(find.text(_pendingTitle), findsNothing);
      expect(find.text(_wizardTitle), findsNothing);
      final Element title = tester.element(
        find.byKey(KycStatusView.pendingTitleKey),
      );
      expect(Directionality.of(title), TextDirection.rtl);
    });
  });

  group('KycWizardScreen geometry · real fonts', () {
    testWidgets('the identity route SCROLLS', (WidgetTester tester) async {
      await _pumpInDeviceBox(
        tester,
        kycWizardScreenIdentityColdEntry,
        textScale: 1,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsWidgets);
    });

    testWidgets('the status route does NOT scroll — same screen, same AppBar', (
      WidgetTester tester,
    ) async {
      await _pumpInDeviceBox(
        tester,
        kycWizardScreenStatusApproved,
        textScale: 1,
      );

      expect(tester.takeException(), isNull);
      expect(
        find.byType(Scrollable),
        findsNothing,
        reason:
            'with no scroll view, anything that outgrows the viewport is '
            'clipped and unreachable rather than scrolled to',
      );
    });

    testWidgets('the SHORTEST status body overflows a 320 pt phone at 200% '
        'text, taking its CTAs off the screen', (WidgetTester tester) async {
      await _pumpInDeviceBox(
        tester,
        kycWizardScreenStatusApproved,
        textScale: 2,
        box: const Size(320, 568),
      );

      expect(_overflowPixels(tester.takeException()), greaterThan(0));
      expect(
        tester.getRect(_byIdentifier('kyc_status_topup_cta')).bottom,
        greaterThan(568),
      );
    });

    testWidgets('the identity route survives the same box and scale, because '
        'it scrolls', (WidgetTester tester) async {
      // Same phone, same text scale, same AppBar — the only difference is that
      await _pumpInDeviceBox(
        tester,
        kycWizardScreenCompactCeiling,
        textScale: 2,
        box: const Size(320, 568),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsWidgets);
    });

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('the 320 pt ceiling lays out clean in ${locale.languageCode}',
          (WidgetTester tester) async {
        // The `_ProgressHeader` is the risk: it is the ONE thing on the identity
        await _pumpInDeviceBox(
          tester,
          kycWizardScreenCompactCeiling,
          textScale: 1,
          box: const Size(320, 568),
          locale: locale,
        );

        expect(tester.takeException(), isNull);
        expect(find.byKey(KycWizardScreen.progressKey), findsOneWidget);
      });
    }
  });
}
