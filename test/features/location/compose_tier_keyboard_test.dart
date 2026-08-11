import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:jeeb_mobile/features/location/presentation/widgets/compose_tier_section.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';
import 'package:jeeb_mobile/features/tier_selection/data/tier_repository.dart';
import 'package:jeeb_mobile/features/tier_selection/domain/tier.dart';

import '../../support/sync_app_localizations.dart';

class _NoSubmission implements RequestSubmissionService {
  @override
  Future<String> submit(RequestDraft draft) async => 'req-1';
}

class _FakeTiers implements TierRepository {
  @override
  Future<List<Tier>> fetchTiers() async => const [_flash, _standard];
}

const _flash = Tier(
  id: TierId.flash,
  priceLow: 5,
  priceHigh: 9,
  currency: 'USD',
  vehicleClass: TierVehicleClass.bikeOrScooter,
);

const _standard = Tier(
  id: TierId.standard,
  priceLow: 3,
  priceHigh: 6,
  currency: 'USD',
  vehicleClass: TierVehicleClass.any,
);

void main() {
  final sl = GetIt.instance;

  setUp(() {
    sl.registerSingleton<ComposeRequestController>(
      ComposeRequestController(_NoSubmission())..setTier(_flash),
    );
    sl.registerSingleton<TierRepository>(_FakeTiers());
  });

  tearDown(sl.reset);

  testWidgets(
      'changing the tier does not put the keyboard back over the confirm CTA',
      (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      wrapForTest(
        Scaffold(
          body: Column(
            children: [
              TextField(focusNode: focus),
              const ComposeTierSection(),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // The customer typed the description first — this is the state the defect
    // was reported in.
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    await tester.tap(find.bySemanticsIdentifier('compose_tier_change'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsIdentifier('compose_tier_option_standard'));
    await tester.pumpAndSettle();

    expect(
      sl<ComposeRequestController>().tier?.id,
      TierId.standard,
      reason: 'the pick still has to land',
    );
    expect(
      focus.hasFocus,
      isFalse,
      reason: 'the sheet route must not restore focus to the description field',
    );
  });
}
