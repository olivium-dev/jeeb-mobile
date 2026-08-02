// Render tests for the DmOnboardingAddressStep previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. Each state pins a DISTINCT string, which is
// what separates "the previews render" from "the previews render their own
// state" — five previews of the same four hint-filled boxes would pass the
// weaker check.
//
// The pinned strings come from the previews' `draft:` strip, because the step
// itself renders identically for every cubit state: the fields have no
// controller, so a full address in the cubit and an empty cubit look the same.
// The `preview specifics` group asserts that divergence directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_address_step.dart';
import 'package:jeeb_mobile/previews/jeeber_onboarding/dm_onboarding_address_step_preview.dart';

import '../preview_test_harness.dart';

/// The draft seeded by the re-entry previews, as the strip prints it.
const String _kTypedDraft = 'draft: Beirut Governorate / Lebanon / Rue Hamra / '
    'Sassine Square, Ashrafieh';

void main() {
  setUpAll(loadPreviewArbs);

  // Every preview except `Coverage probe in flight`, which cannot settle — see
  // the dedicated group below.
  testPreviewsRender(
    'DmOnboardingAddressStep',
    const <String, Widget Function()>{
      'Fresh entry · empty': dmOnboardingAddressStepEmpty,
      'Returned via Back · draft not restored':
          dmOnboardingAddressStepDraftNotRestored,
      'Compact viewport · CTA pinned': dmOnboardingAddressStepCompact,
      'In the wizard · app bar + progress': dmOnboardingAddressStepInWizard,
    },
    expectedText: const <String, String>{
      'Fresh entry · empty': 'draft: (empty) · cta: idle · viewport: full',
      'Returned via Back · draft not restored':
          '$_kTypedDraft · cta: idle · viewport: full',
      'Compact viewport · CTA pinned':
          'draft: (empty) · cta: idle · viewport: 320 pt',
      // The only preview framed by the real host, so the only one that can show
      // the wizard's app-bar title.
      'In the wizard · app bar + progress': 'Personal Details',
    },
  );

  // The in-flight state renders `OmdsButtonLoading`, i.e. an INDETERMINATE
  // `CircularProgressIndicator`. `pumpAndSettle` (which `pumpPreview` calls)
  // never returns while one is on screen, so this preview gets the same three
  // assertions the shared suite makes — builds in EN, builds in AR, renders its
  // OWN state — driven by fixed pumps instead.
  group('DmOnboardingAddressStep previews · Coverage probe in flight', () {
    Future<void> pumpInFlight(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(dmOnboardingAddressStepCoverageInFlight, locale),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Coverage probe in flight · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpInFlight(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('renders its own state', (WidgetTester tester) async {
      await pumpInFlight(tester);

      expect(
        find.text('$_kTypedDraft · cta: submitting · viewport: full'),
        findsOneWidget,
      );
    });

    testWidgets(
        'the service-area probe spinner lands on THIS step\'s Continue, '
        'blocking it', (WidgetTester tester) async {
      await pumpInFlight(tester);

      // The label is swapped for the spinner, and the CTA refuses taps — on a
      // step that is not submitting anything itself.
      expect(find.text('Continue'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<OmdsLoadingButton>(find.byType(OmdsLoadingButton))
            .isEnabled,
        isFalse,
      );
    });
  });

  group('DmOnboardingAddressStep preview specifics', () {
    Iterable<TextField> fields(WidgetTester tester) =>
        tester.widgetList<TextField>(find.byType(TextField));

    testWidgets('D20 (JM-037) — four fields, no vehicle-number field', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingAddressStepEmpty);

      expect(find.byKey(DmOnboardingAddressStep.rootKey), findsOneWidget);
      expect(fields(tester), hasLength(4));
    });

    testWidgets('a draft in the cubit never reaches the fields', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingAddressStepDraftNotRestored);

      // Every box is blank even though the cubit holds the full address, which
      // is what makes coming back to this step look like lost work. The values
      // exist on screen only inside the previews' own diagnostic strip.
      for (final TextField field in fields(tester)) {
        expect(field.controller?.text ?? '', isEmpty);
      }
      expect(find.text('Rue Hamra'), findsNothing);
      expect(find.text('Sassine Square, Ashrafieh'), findsNothing);
    });

    testWidgets('Continue is tappable with an entirely empty address', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingAddressStepEmpty);

      // No `enabled` is passed to DmOnboardingStepLayout, so nothing gates the
      // step on its own four fields — unlike the service-area step, which
      // requires a home base. Pinned so a later readiness gate is a deliberate
      // change to this expectation rather than a silent one.
      expect(
        tester.widget<OmdsLoadingButton>(find.byType(OmdsLoadingButton))
            .isEnabled,
        isTrue,
      );
    });

    testWidgets('the framed preview really contains the address step', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingAddressStepInWizard);

      expect(find.byKey(DmOnboardingAddressStep.rootKey), findsOneWidget);
      expect(fields(tester), hasLength(4));
    });
  });
}
