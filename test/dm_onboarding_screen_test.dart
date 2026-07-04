import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_cubit.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/application/dm_onboarding_state.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/domain/dm_onboarding_gateway.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/dm_onboarding_screen.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_address_step.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_photo_step.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_photo_upload_card.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_progress_header.dart';
import 'package:jeeb_mobile/features/jeeber_onboarding/presentation/widgets/dm_onboarding_service_area_step.dart';
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
  Future<AppLocalizations> load(Locale locale) async =>
      debugLoadAppLocalizationsSync(locale, _arbByTag[locale.languageCode]!);

  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

late _SyncAppLocalizationsDelegate _syncDelegate;

void _loadArbFromDisk() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncAppLocalizationsDelegate({'en': en, 'ar': ar});
}

Uint8List _bytes(int length) {
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = 0x42;
  }
  return out;
}

DmOnboardingCubit _newCubit({
  PhotoPickerService? picker,
  DmOnboardingGateway? gateway,
  DmOnboardingStep initialStep = DmOnboardingStep.photo,
}) {
  final cubit = DmOnboardingCubit(
    pickerService:
        picker ?? StubPhotoPickerService(cameraPayload: _bytes(100 * 1024)),
    gateway: gateway ?? FakeDmOnboardingGateway(),
    initialStep: initialStep,
  );
  addTearDown(cubit.close);
  return cubit;
}

Widget _host(DmOnboardingCubit cubit, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: DmOnboardingScreen(cubit: cubit),
  );
}

void main() {
  setUpAll(_loadArbFromDisk);

  testWidgets('photo step renders with progress + upload card', (tester) async {
    await tester.pumpWidget(_host(_newCubit()));
    await tester.pumpAndSettle();

    expect(find.byKey(DmOnboardingScreen.rootKey), findsOneWidget);
    expect(find.byKey(DmOnboardingProgressHeader.rootKey), findsOneWidget);
    expect(find.byKey(DmOnboardingPhotoStep.rootKey), findsOneWidget);
    expect(find.byKey(DmOnboardingPhotoUploadCard.rootKey), findsOneWidget);
  });

  testWidgets('address step renders four labeled fields (no vehicle, D20)',
      (tester) async {
    await tester.pumpWidget(
      _host(_newCubit(initialStep: DmOnboardingStep.address)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(DmOnboardingAddressStep.rootKey), findsOneWidget);
    // D20 (JM-037): vehicle-number field removed → state/country/street/address.
    expect(find.byType(TextField), findsNWidgets(4));
  });

  testWidgets('service-area step renders the home-base pin, no slider (D51)',
      (tester) async {
    await tester.pumpWidget(
      _host(_newCubit(initialStep: DmOnboardingStep.serviceArea)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(DmOnboardingServiceAreaStep.rootKey), findsOneWidget);
    expect(
      find.bySemanticsIdentifier('service_area_map_pin'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsIdentifier('service_area_select_location'),
      findsOneWidget,
    );
    // D51: the distance slider is removed.
    expect(find.byType(Slider), findsNothing);
    expect(
      find.bySemanticsIdentifier('dm_onboarding_distance_slider'),
      findsNothing,
    );
  });

  testWidgets('tapping select-location sets the home base (no-router fallback)',
      (tester) async {
    final cubit = _newCubit(initialStep: DmOnboardingStep.serviceArea);
    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    expect(cubit.state.hasHomeBase, isFalse);
    await tester.tap(
      find.bySemanticsIdentifier('service_area_select_location'),
    );
    await tester.pumpAndSettle();
    expect(cubit.state.hasHomeBase, isTrue);
  });

  testWidgets(
      'JEBV4-13 P1-5: failed coverage probe surfaces an honest error '
      'instead of leaving the wizard silently stuck', (tester) async {
    final cubit = _newCubit(
      gateway: FakeDmOnboardingGateway(shouldFail: true),
      initialStep: DmOnboardingStep.serviceArea,
    );
    await tester.pumpWidget(_host(cubit));
    await tester.pumpAndSettle();

    cubit.setHomeBase(
      const DmOnboardingHomeBase(lat: 1, lng: 1, label: 'Home'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsIdentifier('dm_onboarding_continue'));
    await tester.pumpAndSettle();

    // Previously: zero error surface (submitFailed had no listener) — the
    // wizard just sat there. Now a SnackBar carries the honest message and
    // the transient error is acknowledged (not replayed).
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text("Couldn't check coverage for this area. Please try again."),
        findsOneWidget);
    expect(cubit.state.error, isNull);
    expect(cubit.state.coverageReady, isFalse);
  });

  testWidgets('renders mirrored under Arabic (RTL)', (tester) async {
    await tester.pumpWidget(
      _host(_newCubit(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    final dir = Directionality.of(
      tester.element(find.byKey(DmOnboardingScreen.rootKey)),
    );
    expect(dir, TextDirection.rtl);
    expect(find.text('ارفع صورة واضحة لك'), findsOneWidget);
  });
}
