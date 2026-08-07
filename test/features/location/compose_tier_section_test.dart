// The delivery tier is DISCLOSED on the last screen before POST /requests.
//
// The voice path picks the recommended tier for the customer so the mic can
// reach a create in one hop. That hop is only legitimate if the price band the
// order goes out at is visible and changeable first — these pin that, and that
// changing it does not blank the recorded description the way `setTier` does.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/di/injection_container.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/location/presentation/widgets/compose_tier_section.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

import '../../support/sync_app_localizations.dart';

class _NoopSubmission implements RequestSubmissionService {
  @override
  Future<String> submit(RequestDraft draft) async => 'req-1';
}

const Tier _standard = Tier(
  id: TierId.standard,
  serverId: 'tier-standard',
  priceLow: 45000,
  priceHigh: 70000,
  currency: 'LBP',
  vehicleClass: TierVehicleClass.bikeOrScooter,
  slaMinutes: 240,
  recommended: true,
);

const Tier _flash = Tier(
  id: TierId.flash,
  serverId: 'tier-flash',
  priceLow: 120000,
  priceHigh: 160000,
  currency: 'LBP',
  vehicleClass: TierVehicleClass.scooterOrCar,
  slaMinutes: 60,
);

class _Catalog implements TierRepository {
  const _Catalog();

  @override
  Future<List<Tier>> fetchTiers() async => const <Tier>[_standard, _flash];
}

Widget _harness() {
  return MaterialApp(
    theme: AppTheme.light(),
    locale: const Locale('en'),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      SyncAppLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: const Scaffold(
      body: SingleChildScrollView(child: ComposeTierSection()),
    ),
  );
}

ComposeRequestController _seed() {
  final controller = ComposeRequestController(_NoopSubmission());
  sl.registerSingleton<ComposeRequestController>(controller);
  sl.registerSingleton<TierRepository>(const _Catalog());
  return controller;
}

void main() {
  tearDown(() => sl.reset());

  testWidgets('the seeded tier is named on screen, never silent', (
    tester,
  ) async {
    _seed().beginVoiceSession(
      tier: _standard,
      description: 'two kilos of apples',
      transcription: 'two kilos of apples',
      audioUrl: 'clip-1',
    );

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('compose_tier_row'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Delivery type'), findsOneWidget);
    expect(find.bySemanticsIdentifier('compose_tier_change'), findsOneWidget);
  });

  testWidgets('no seeded session renders nothing at all', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.bySemanticsIdentifier('compose_tier_row'), findsNothing);
    expect(find.text('Delivery type'), findsNothing);
  });

  testWidgets('changing the tier keeps the recorded description and clip', (
    tester,
  ) async {
    final controller = _seed()
      ..beginVoiceSession(
        tier: _standard,
        description: 'two kilos of apples',
        transcription: 'two kilos of apples',
        audioUrl: 'clip-1',
      );

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsIdentifier('compose_tier_change'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsIdentifier('compose_tier_sheet'), findsOneWidget);

    await tester.tap(
      find.bySemanticsIdentifier('compose_tier_option_flash'),
    );
    await tester.pumpAndSettle();

    expect(controller.tier, _flash);
    // `setTier` would have blanked both — that is why `changeTier` exists.
    expect(controller.description, 'two kilos of apples');
    expect(find.text('Flash'), findsOneWidget);
  });
}
