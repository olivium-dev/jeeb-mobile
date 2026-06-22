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

import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/location/data/fake_location_select_repository.dart';
import 'package:jeeb_mobile/features/location/domain/location_select_repository.dart';
import 'package:jeeb_mobile/features/location/presentation/client_location_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

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
}
