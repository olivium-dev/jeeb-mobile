import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_tier_row.dart';
import 'package:jeeb_mobile/features/location/data/fake_location_select_repository.dart';
import 'package:jeeb_mobile/features/location/domain/current_location_resolver.dart';
import 'package:jeeb_mobile/features/location/presentation/capture_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/capture_map_viewport.dart';
import 'package:jeeb_mobile/features/request_type/presentation/request_type_screen.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/fake_current_location_resolver.dart';

/// Synchronous ARB-backed delegate so tests render the real EN/AR strings.
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

late _SyncDelegate _syncDelegate;

void _loadArbs() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncDelegate({'en': en, 'ar': ar});
}

Widget _harness(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  setUpAll(_loadArbs);

  // A tall surface so the lazy ListView builds the whole Request type screen
  // (5 tier cards + Location section) without needing to scroll in-test.
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final view = binding.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 1.0;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
    // JEBV4-176: the location-select screen resolves a device-GPS fix; provide
    // a fake so it renders normally (no real geolocator in the headless test).
    sl.registerLazySingleton<CurrentLocationResolver>(
      FakeCurrentLocationResolver.new,
    );
  });

  tearDown(() async {
    await sl.reset();
  });

  group('RequestTypeScreen (Figma 56535:2392)', () {
    testWidgets('renders all five tier cards + a Location section', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(const RequestTypeScreen(repository: FakeTierRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(JeebTierRow), findsNWidgets(5));
      // redesign-2026-08 · 07: the leading glyph is the design-system emoji
      // lexicon (⚡🚀🟦🤝🌿), not a Material vector icon.
      expect(find.text('Flash'), findsOneWidget);
      expect(find.text('Eco'), findsOneWidget);
      expect(find.text('⚡'), findsOneWidget);
      expect(find.text('🌿'), findsOneWidget);
      // The heading now lives in the in-body top bar (the duplicate section
      // heading was removed), so it is still exactly one widget.
      expect(find.text('Choose your request'), findsOneWidget);
      expect(find.text('Deliver to'), findsOneWidget);
      // The card draws the short action word; "Change Location" survives as the
      // accessible name on `request_type_change_location_button`.
      expect(find.text('Change'), findsOneWidget);

      // JM-024 / 63_W1_TEST_PLAN §2.2: the EXACT 5 tier-radio ids + the Continue
      // CTA id the create-flow Maestro flow asserts (on-the-way → on_the_way).
      for (final id in const [
        'request_type_flash_radio',
        'request_type_express_radio',
        'request_type_standard_radio',
        'request_type_on_the_way_radio',
        'request_type_eco_radio',
        'request_type_continue_cta',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }
    });

    testWidgets('tapping a tier card selects it', (tester) async {
      await tester.pumpWidget(
        _harness(const RequestTypeScreen(repository: FakeTierRepository())),
      );
      await tester.pumpAndSettle();

      // JM-024 / 63_W1_TEST_PLAN §2.2: tier radios carry the contract
      // `request_type_<tier>_radio` id (was `request_type_tier_<enum>`).
      final ecoCard = find.bySemanticsIdentifier('request_type_eco_radio');
      expect(ecoCard, findsOneWidget);
      // redesign-2026-08 · 08: the picker rows are the catalog variant, whose
      // a11y contract is `selected` (a fill swap), not the radio `checked`.
      // Every tier starts unselected until the customer makes a choice.
      expect(
        tester.getSemantics(ecoCard).flagsCollection.isSelected,
        Tristate.isFalse,
      );
      await tester.tap(ecoCard);
      await tester.pumpAndSettle();
      // After the tap the Eco card reports as the selected option.
      expect(
        tester.getSemantics(ecoCard).flagsCollection.isSelected,
        Tristate.isTrue,
      );
    });

    testWidgets('change-location callback fires', (tester) async {
      var changed = false;
      await tester.pumpWidget(
        _harness(
          RequestTypeScreen(
            repository: const FakeTierRepository(),
            onChangeLocation: () => changed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.bySemanticsIdentifier(
        'request_type_change_location_button',
      );
      expect(action, findsOneWidget);
      await tester.tap(action);
      expect(changed, isTrue);
    });

    testWidgets('renders Arabic strings in RTL', (tester) async {
      await tester.pumpWidget(
        _harness(
          const RequestTypeScreen(repository: FakeTierRepository()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      final heading = find.text('اختر نوع طلبك');
      expect(heading, findsOneWidget);
      expect(Directionality.of(tester.element(heading)), TextDirection.rtl);
      // The drawn word is the short `requestTypeChangeCta`; the long
      // `تغيير الموقع` remains the a11y label, not visible text.
      expect(find.text('تغيير'), findsOneWidget);
    });
  });

  group('ClientLocationScreen (Figma 56539:1444)', () {
    testWidgets('renders the current-location card + new-location row', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const ClientLocationScreen(
            repository: FakeLocationSelectRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose your location'), findsOneWidget);
      expect(find.text('Current Location'), findsOneWidget);
      expect(find.text('New Location'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('client_location_option_current'),
        findsOneWidget,
      );
      // JM-024 / 63_W1_TEST_PLAN §2.3: the new-location CTA carries the
      // contract `location_select_new_location_cta` id (the underlying row
      // widget defaults to the legacy `client_location_add_new` elsewhere).
      expect(
        find.bySemanticsIdentifier('location_select_new_location_cta'),
        findsOneWidget,
      );
      // The location-select Confirm CTA → order-chat (JM-024 AC4).
      expect(
        find.bySemanticsIdentifier('location_select_confirm_cta'),
        findsOneWidget,
      );
    });

    testWidgets('add-location callback fires', (tester) async {
      var added = false;
      await tester.pumpWidget(
        _harness(
          ClientLocationScreen(
            repository: const FakeLocationSelectRepository(),
            onAddLocation: () => added = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.bySemanticsIdentifier('location_select_new_location_cta'),
      );
      expect(added, isTrue);
    });
  });

  group('CaptureLocationScreen (Figma 56546:2303)', () {
    testWidgets('renders the map viewport, pin and confirm CTA', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const CaptureLocationScreen()));
      await tester.pumpAndSettle();
      expect(find.byType(CaptureMapViewport), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('capture_location_map'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('capture_location_pin'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('capture_location_pin_cta'),
        findsOneWidget,
      );
      expect(find.text('Pin Location'), findsOneWidget);
    });

    testWidgets('pin callback fires on CTA tap', (tester) async {
      var pinned = false;
      await tester.pumpWidget(
        _harness(CaptureLocationScreen(onPinned: () => pinned = true)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsIdentifier('capture_location_pin_cta'));
      expect(pinned, isTrue);
    });
  });
}
