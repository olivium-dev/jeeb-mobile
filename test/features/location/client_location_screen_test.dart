// JM-024 — location-select screen contract (63_W1_TEST_PLAN §2.3): the three
// Semantics identifiers, the seeded saved-address cards, and the nav-callback
// seams (confirm → order-chat, saved-row → saved-addresses, new → map-pin).
//
// Isolated (no router): the screen self-provides its cubit over the injected
// FakeLocationSelectRepository.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/location/application/location_select_state.dart';
import 'package:jeeb_mobile/features/location/data/fake_location_select_repository.dart';
import 'package:jeeb_mobile/features/location/domain/location_select_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/transcription/domain/voice_clip.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/fake_request_submission_service.dart';

class _SyncDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _SyncDelegate(this._arbByTag);
  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncDelegate old) => false;
}

late _SyncDelegate _delegate;

Widget _harness(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

/// Same harness pinned to an explicit [locale] (G1 ar/RTL coverage).
Widget _harnessLocalized(Widget child, Locale locale) => MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        _delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  setUpAll(() {
    _delegate = _SyncDelegate({
      'en': File('lib/l10n/app_en.arb').readAsStringSync(),
      'ar': File('lib/l10n/app_ar.arb').readAsStringSync(),
    });
  });

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2600);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  testWidgets('exposes the three JM-024 location-select identifiers',
      (tester) async {
    await tester.pumpWidget(
      _harness(const ClientLocationScreen(
        // DEFECT A: inject the user id so the screen uses the test seam instead
        // of resolving from AuthTokenStore (secure storage, unavailable here).
        userId: 'user-client-001',
        repository: FakeLocationSelectRepository(),
      )),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier('location_select_saved_addresses_row'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('location_select_new_location_cta'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('location_select_confirm_cta'),
      findsOneWidget,
    );
    // The seeded saved addresses render as selectable cards.
    expect(
      find.bySemanticsIdentifier(
          'location_select_saved_address_addr-client-001-home'),
      findsOneWidget,
    );
  });

  testWidgets('confirm / saved-row / new callbacks fire (nav seams)',
      (tester) async {
    var confirmed = false;
    var openedSaved = false;
    var addedNew = false;
    await tester.pumpWidget(
      _harness(ClientLocationScreen(
        userId: 'user-client-001',
        repository: const FakeLocationSelectRepository(),
        onConfirm: () => confirmed = true,
        onOpenSavedAddresses: () => openedSaved = true,
        onAddLocation: () => addedNew = true,
      )),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.bySemanticsIdentifier('location_select_saved_addresses_row'),
    );
    expect(openedSaved, isTrue);

    await tester.tap(
      find.bySemanticsIdentifier('location_select_new_location_cta'),
    );
    expect(addedNew, isTrue);

    // G1: Confirm is gated on the "What do you need?" entry — type one first.
    await tester.enterText(
      find.byKey(const Key('clientLocation.descriptionField')),
      '2 shawarma + cola from Barbar',
    );
    await tester.pump();

    await tester.tap(
      find.bySemanticsIdentifier('location_select_confirm_cta'),
    );
    expect(confirmed, isTrue);
  });

  testWidgets('renders the affordances even when the saved-address load fails',
      (tester) async {
    await tester.pumpWidget(
      _harness(const ClientLocationScreen(
        userId: 'user-client-001',
        repository: FakeLocationSelectRepository(
          failWith: LocationSelectFailure.network,
        ),
      )),
    );
    await tester.pumpAndSettle();

    // The create flow stays usable: Current + New + Confirm still present.
    expect(
      find.bySemanticsIdentifier('client_location_option_current'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('location_select_new_location_cta'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('location_select_confirm_cta'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('location_select_saved_addresses_error'),
      findsOneWidget,
    );
  });

  // ── G1 (sprint-009 P0) — the "What do you need?" compose block ────────────

  group('G1 compose description', () {
    const fieldKey = Key('clientLocation.descriptionField');
    const micKey = Key('clientLocation.descriptionMic');

    OmdsPrimaryButton confirmButton(WidgetTester tester) {
      final cta = find.bySemanticsIdentifier('location_select_confirm_cta');
      expect(cta, findsOneWidget);
      return tester.widget<OmdsPrimaryButton>(
        find.descendant(of: cta, matching: find.byType(OmdsPrimaryButton)),
      );
    }

    tearDown(() async {
      await sl.reset();
    });

    testWidgets(
        'renders the description block and gates Confirm on a non-empty '
        'trimmed entry (typed path)', (tester) async {
      final submission = FakeRequestSubmissionService(requestId: 'req-g1');
      sl.registerLazySingleton<ComposeRequestController>(
        () => ComposeRequestController(submission),
      );
      await tester.pumpWidget(
        _harness(const ClientLocationScreen(
          userId: 'user-client-001',
          repository: FakeLocationSelectRepository(),
        )),
      );
      await tester.pumpAndSettle();

      // The block renders: field + mic affordance.
      expect(find.bySemanticsIdentifier('compose_description_input'),
          findsOneWidget);
      expect(find.byKey(micKey), findsOneWidget);

      // Empty → Confirm disabled (required-by-default).
      expect(confirmButton(tester).isEnabled, isFalse);

      // Whitespace-only stays disabled (non-empty TRIMMED required).
      await tester.enterText(find.byKey(fieldKey), '   ');
      await tester.pump();
      expect(confirmButton(tester).isEnabled, isFalse);

      // Real content enables Confirm and lands in the compose controller.
      await tester.enterText(
          find.byKey(fieldKey), '2 shawarma + cola from Barbar');
      await tester.pump();
      expect(confirmButton(tester).isEnabled, isTrue);
      expect(
        sl<ComposeRequestController>().description,
        '2 shawarma + cola from Barbar',
      );

      // Clearing re-disables and surfaces the required error.
      await tester.enterText(find.byKey(fieldKey), '');
      await tester.pump();
      expect(confirmButton(tester).isEnabled, isFalse);
      expect(find.text('Please describe what you need.'), findsOneWidget);
    });

    testWidgets(
        'mic affordance (voice path): the dictated transcript flows into the '
        'field and the POST draft carries description + transcription + audio',
        (tester) async {
      final submission = FakeRequestSubmissionService(requestId: 'req-g1');
      sl.registerLazySingleton<ComposeRequestController>(
        () => ComposeRequestController(submission),
      );
      var dictations = 0;
      await tester.pumpWidget(
        _harness(ClientLocationScreen(
          userId: 'user-client-001',
          repository: const FakeLocationSelectRepository(),
          onDictate: () async {
            dictations += 1;
            return const VoiceClip(
              audioPath: 'clip-42',
              durationMs: 2100,
              transcript: 'A birthday cake from Sea Sweet',
            );
          },
        )),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(micKey));
      await tester.tap(find.byKey(micKey));
      await tester.pumpAndSettle();

      expect(dictations, 1);
      // Transcript flows INTO the editable field (not a separate surface).
      expect(find.text('A birthday cake from Sea Sweet'), findsOneWidget);
      expect(confirmButton(tester).isEnabled, isTrue);

      // The compose controller now builds the draft from the dictation.
      final draft = await sl<ComposeRequestController>()
          .submitFromLocation(const LocationSelectState(
        status: LocationSelectStatus.loaded,
      ))
          .then((_) => submission.lastDraft!);
      expect(draft.description, 'A birthday cake from Sea Sweet');
      expect(draft.transcription, 'A birthday cake from Sea Sweet');
      expect(draft.audioUrl, 'clip-42');
    });

    testWidgets('ar/RTL: the compose block renders localized and mirrored',
        (tester) async {
      await tester.pumpWidget(
        _harnessLocalized(
          const ClientLocationScreen(
            userId: 'user-client-001',
            repository: FakeLocationSelectRepository(),
          ),
          const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      // Arabic heading + hint of the G1 block.
      expect(find.text('ما الذي تحتاجه؟'), findsOneWidget);
      // The field itself lays out right-to-left under the ar locale.
      final fieldContext = tester.element(find.byKey(fieldKey));
      expect(Directionality.of(fieldContext), TextDirection.rtl);
    });
  });
}
