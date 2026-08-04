// M4 — the KYC funnel's four §2.7 states, read off the widget.
//
// Every one of them was catalog-invisible before this row, and every untinted
// `OmdsLoadingState` inked its ring `colorScheme.primary` — #D73B00 under
// Midnight, i.e. the brightest thing on a screen that is only waiting.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_cta_button.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_state.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_wizard_screen.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_capture_tile.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_state_art.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _SeededCubit extends KycWizardCubit {
  _SeededCubit(KycWizardState seed)
      : super(
          pickerService: StubPhotoPickerService(),
          gateway: FakeKycGateway(),
        ) {
    emit(seed);
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    KycWizardState seed, {
    Locale locale = const Locale('en'),
  }) async {
    final KycWizardCubit cubit = _SeededCubit(seed);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.midnight(),
        locale: locale,
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
  }

  JeebEmptyState block(WidgetTester tester) =>
      tester.widget<JeebEmptyState>(find.byType(JeebEmptyState));

  group('M4 · the KYC state art is one family', () {
    test('is radar, and is NOT the funnel-terminal street tile', () {
      expect(kycStateVariant, JeebEmptyStateVariant.radar);
      expect(kycStateVariant, isNot(JeebEmptyStateVariant.street));
      // Not radar's default K/N/R jeeber initials: this funnel is about
      // DOCUMENTS, and the letters would be meaningless on it.
      expect(kycStateMedallions, isNot(JeebEmptyState.radarMedallions));
      expect(kycStateMedallions.length, 3);
      expect(
        kycStateMedallions.map((JeebEmptyMedallion m) => m.icon),
        <IconData>[
          Icons.badge_outlined,
          Icons.face_outlined,
          Icons.description_outlined,
        ],
      );
    });
  });

  group('M4 · schema step', () {
    testWidgets('the cold form load is the breathing skeleton, not a spinner',
        (tester) async {
      await pump(tester, const KycWizardState(step: KycWizardStep.schema));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      final JeebEmptyState state = block(tester);
      expect(state.status, JeebEmptyStateStatus.loading);
      expect(state.status, isNot(JeebEmptyStateStatus.empty));
      expect(state.variant, kycStateVariant);
      expect(state.medallions, kycStateMedallions);
      expect(state.identifier, 'kyc_wizard_schema_loading');
      // §2.7: the CTA is withheld while loading.
      expect(state.action, isNull);
    });

    testWidgets('a failed load is the DANGER-tinted tile plus the retry CTA',
        (tester) async {
      await pump(
        tester,
        const KycWizardState(
          step: KycWizardStep.schema,
          error: KycWizardError.schemaLoadFailed,
        ),
      );

      final JeebEmptyState state = block(tester);
      expect(state.status, JeebEmptyStateStatus.error);
      expect(state.status, isNot(JeebEmptyStateStatus.loading));
      expect(state.identifier, 'kyc_wizard_schema_error');
      expect(state.action, isNotNull);
      // The frozen id survived the chrome that used to host it.
      expect(
        find.bySemanticsIdentifier('kyc_wizard_retry_cta'),
        findsOneWidget,
      );
      expect(find.byType(JeebCtaButton), findsOneWidget);
    });

    testWidgets('the error headline is the shipped key, verbatim',
        (tester) async {
      await pump(
        tester,
        const KycWizardState(
          step: KycWizardStep.schema,
          error: KycWizardError.schemaLoadFailed,
        ),
      );
      final AppLocalizations l10n =
          AppLocalizations.of(tester.element(find.byType(JeebEmptyState)));
      expect(block(tester).headline, l10n.kycErrorSchemaLoadFailed);
      expect(find.text(l10n.kycErrorSchemaLoadFailed), findsOneWidget);
    });
  });

  group('M4 · status step', () {
    testWidgets('the first status read draws the loading member',
        (tester) async {
      await pump(
        tester,
        const KycWizardState(
          step: KycWizardStep.status,
          isLoadingStatus: true,
        ),
      );

      final JeebEmptyState state = block(tester);
      expect(state.status, JeebEmptyStateStatus.loading);
      expect(state.variant, kycStateVariant);
      expect(state.identifier, 'kyc_status_loading');
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('M4 · headline ink', () {
    testWidgets('every KYC state headline is onSurface, never primary',
        (tester) async {
      await pump(tester, const KycWizardState(step: KycWizardStep.schema));
      final BuildContext context = tester.element(find.byType(JeebEmptyState));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final String headline = block(tester).headline;

      final Text text = tester.widget<Text>(find.text(headline));
      expect(text.style?.color?.toARGB32(), scheme.onSurface.toARGB32());
      expect(text.style?.color?.toARGB32(), isNot(scheme.primary.toARGB32()));
    });
  });

  group('M4 · the inline capture wait', () {
    testWidgets('a processing tile marks with MUTED ink, never the accent',
        (tester) async {
      await pump(
        tester,
        const KycWizardState(
          step: KycWizardStep.identity,
          capturing: KycCaptureSlot.idBack,
        ),
      );

      final Finder mark = find.descendant(
        of: find.byType(KycCaptureTile),
        matching: find.byType(CircularProgressIndicator),
      );
      expect(mark, findsOneWidget);
      final ColorScheme scheme =
          Theme.of(tester.element(mark)).colorScheme;
      final CircularProgressIndicator spinner =
          tester.widget<CircularProgressIndicator>(mark);
      expect(spinner.color, isNotNull);
      expect(spinner.color!.toARGB32(), isNot(scheme.primary.toARGB32()));
      // An inline row cannot host a 150px illustration, so the §2.7 block must
      // NOT be what a capture tile draws.
      expect(
        find.descendant(
          of: find.byType(KycCaptureTile),
          matching: find.byType(JeebEmptyState),
        ),
        findsNothing,
      );
    });
  });

  group('M4 · RTL', () {
    testWidgets('the Arabic schema error still draws one state and one CTA',
        (tester) async {
      await pump(
        tester,
        const KycWizardState(
          step: KycWizardStep.schema,
          error: KycWizardError.schemaLoadFailed,
        ),
        locale: const Locale('ar'),
      );

      expect(find.byType(JeebEmptyState), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('kyc_wizard_retry_cta'),
        findsOneWidget,
      );
      expect(
        Directionality.of(tester.element(find.byType(JeebEmptyState))),
        TextDirection.rtl,
      );
    });
  });
}
