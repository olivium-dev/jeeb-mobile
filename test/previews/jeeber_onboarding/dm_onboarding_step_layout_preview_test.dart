import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_state.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_step_layout.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _settling = <String, Widget Function()>{
  'Photo step · Continue gated': dmOnboardingStepLayoutPhotoGated,
  'Address step · Continue live': dmOnboardingStepLayoutAddressForm,
  'Service area · gated, short viewport':
      dmOnboardingStepLayoutServiceAreaGated,
  'Service area · home base pinned': dmOnboardingStepLayoutServiceAreaPinned,
};

DmOnboardingCubit _cubitOf(WidgetTester tester) =>
    BlocProvider.of<DmOnboardingCubit>(
      tester.element(find.byType(DmOnboardingStepLayout)),
    );

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'DmOnboardingStepLayout',
    _settling,
    expectedText: const <String, String>{
      'Photo step · Continue gated': 'Upload a clear photo for you',
      // A field HINT, not a label: 'Address' also labels the step's other
      'Address step · Continue live': 'Jasmine Tower, Apartment 12B',
      'Service area · gated, short viewport':
          'Tap Location to set your home base',
      // The pinned place label — the one line the gated twin cannot render.
      'Service area · home base pinned': 'Beirut',
    },
  );

  // The in-flight preview holds an indeterminate `CircularProgressIndicator`
  group('DmOnboardingStepLayout previews · in-flight', () {
    Future<void> pumpInFlight(
      WidgetTester tester, {
      Locale locale = const Locale('en'),
    }) async {
      await tester.pumpWidget(
        previewCanvas(dmOnboardingStepLayoutSubmitting, locale),
      );
      await tester.pump(); // resolve localizations
      await tester.pump(const Duration(milliseconds: 16)); // one spinner frame
    }

    for (final Locale locale in const <Locale>[Locale('en'), Locale('ar')]) {
      testWidgets('Coverage check in flight · ${locale.languageCode}', (
        WidgetTester tester,
      ) async {
        await pumpInFlight(tester, locale: locale);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Coverage check in flight renders its own state', (
      WidgetTester tester,
    ) async {
      await pumpInFlight(tester);

      // The submit REPLACES the label rather than dimming it. No other preview
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Beirut'), findsOneWidget);
    });

    testWidgets('the in-flight CTA is not tappable', (
      WidgetTester tester,
    ) async {
      await pumpInFlight(tester);

      expect(
        tester.widget<OmdsLoadingButton>(find.byType(OmdsLoadingButton))
            .isEnabled,
        isFalse,
        reason: 'isEnabled: enabled && !isSubmitting — the submit guard must '
            'hold even though this preview passes enabled: true.',
      );
    });
  });

  group('DmOnboardingStepLayout preview specifics', () {
    // The whole contract of this chrome: the body scrolls, the CTA does not.
    testWidgets('every preview pins a full-width CTA below the scroll area', (
      WidgetTester tester,
    ) async {
      for (final Widget Function() preview in _settling.values) {
        await pumpPreview(tester, preview);

        final Rect layout = tester.getRect(find.byType(DmOnboardingStepLayout));
        final Rect viewport = tester.getRect(find.byType(SingleChildScrollView));
        final Rect cta = tester.getRect(find.byType(OmdsLoadingButton));

        expect(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(OmdsLoadingButton),
          ),
          findsNothing,
          reason: 'The CTA must sit outside the scrollable, or it scrolls away.',
        );
        expect(cta.top, greaterThanOrEqualTo(viewport.bottom));
        expect(cta.height, 48.0); // Sizes.fourXLarge, fixed at every text scale
        expect(cta.left, layout.left + 24.0); // Spacing.xLarge page gutter
        expect(cta.right, layout.right - 24.0);
        expect(layout.bottom - cta.bottom, 20.0); // Spacing.large gutter
      }
    });

    // Same numbers under RTL. The gutter is an `EdgeInsetsDirectional`, so this
    testWidgets('the CTA keeps its box and its localized label in Arabic', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        dmOnboardingStepLayoutAddressForm,
        locale: const Locale('ar'),
      );

      final Rect layout = tester.getRect(find.byType(DmOnboardingStepLayout));
      final Rect cta = tester.getRect(find.byType(OmdsLoadingButton));
      expect(cta.left, layout.left + 24.0);
      expect(cta.right, layout.right - 24.0);

      expect(
        Directionality.of(tester.element(find.byType(DmOnboardingStepLayout))),
        TextDirection.rtl,
      );
      // Nothing in the chrome is a hardcoded English literal.
      expect(find.text('متابعة'), findsOneWidget);
      expect(find.text('Continue'), findsNothing);
    });

    // `enabled` is the layout's one behavioural input. Assert what it DOES —
    testWidgets('a gated CTA offers no tap action and cannot advance', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingStepLayoutPhotoGated);
      final DmOnboardingCubit cubit = _cubitOf(tester);
      expect(cubit.state.step, DmOnboardingStep.photo);

      final Finder continueButton =
          find.bySemanticsIdentifier('dm_onboarding_continue');
      expect(continueButton, findsOneWidget);
      expect(
        tester.getSemantics(continueButton).getSemanticsData().hasAction(
              SemanticsAction.tap,
            ),
        isFalse,
      );

      await tester.tap(continueButton, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(cubit.state.step, DmOnboardingStep.photo);
    });

    testWidgets('a live CTA is tappable and advances the wizard', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingStepLayoutAddressForm);
      final DmOnboardingCubit cubit = _cubitOf(tester);
      expect(cubit.state.step, DmOnboardingStep.photo);

      final Finder continueButton =
          find.bySemanticsIdentifier('dm_onboarding_continue');
      expect(
        tester.getSemantics(continueButton).getSemanticsData().hasAction(
              SemanticsAction.tap,
            ),
        isTrue,
      );

      await tester.tap(continueButton);
      await tester.pumpAndSettle();
      // `next()` chains through the wizard — it is not a fake submit.
      expect(cubit.state.step, DmOnboardingStep.address);
    });

    // The gated/live pair differ by one alpha step and nothing else. If that
    testWidgets('gated and live differ only by the disabled fill', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, dmOnboardingStepLayoutServiceAreaGated);
      final OmdsLoadingButton gated =
          tester.widget(find.byType(OmdsLoadingButton));

      await pumpPreview(tester, dmOnboardingStepLayoutServiceAreaPinned);
      final OmdsLoadingButton live =
          tester.widget(find.byType(OmdsLoadingButton));

      expect(gated.isEnabled, isFalse);
      expect(live.isEnabled, isTrue);
      expect(gated.text, live.text);
      expect(gated.isLoading, live.isLoading);
    });

    // Bodies taller than the viewport must scroll rather than overflow — the
    testWidgets('a taller-than-viewport body scrolls', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 500);
      addTearDown(tester.view.reset);

      await pumpPreview(tester, dmOnboardingStepLayoutPhotoGated);
      expect(tester.takeException(), isNull);

      final ScrollableState scrollable = tester.state(find.byType(Scrollable));
      expect(scrollable.position.maxScrollExtent, greaterThan(0));

      final Rect before = tester.getRect(find.byType(OmdsLoadingButton));
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, greaterThan(0));
      expect(
        tester.getRect(find.byType(OmdsLoadingButton)),
        before,
        reason: 'The CTA must not move when the body scrolls under it.',
      );
    });
  });
}
