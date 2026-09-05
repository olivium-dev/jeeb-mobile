import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_status/domain/delivery_address.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_snapshot.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_stage.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_status_gateway.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/delivery_tier.dart';
import 'package:jeeb_mobile/features/delivery_status/domain/jeeber_summary.dart';
import 'package:jeeb_mobile/features/delivery_status/presentation/delivery_status_screen.dart';
import 'package:jeeb_mobile/features/delivery_status/presentation/widgets/delivery_details_card.dart';
import 'package:jeeb_mobile/features/delivery_status/presentation/widgets/delivery_eta_badge.dart';
import 'package:jeeb_mobile/features/delivery_status/presentation/widgets/delivery_jeeber_card.dart';
import 'package:jeeb_mobile/features/delivery_status/presentation/widgets/delivery_lifecycle_banner.dart';
import 'package:jeeb_mobile/features/delivery_status/presentation/widgets/delivery_stage_indicator.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import 'support/sync_app_localizations.dart';

DeliverySnapshot _snapshot({
  String id = 'd-1',
  DeliveryStage stage = DeliveryStage.matched,
  DeliveryLifecycle lifecycle = DeliveryLifecycle.active,
  Map<DeliveryStage, DateTime>? stageTimestamps,
  JeeberSummary? jeeber,
  int? etaMinutes,
}) {
  return DeliverySnapshot(
    id: id,
    stage: stage,
    lifecycle: lifecycle,
    stageTimestamps: stageTimestamps ??
        <DeliveryStage, DateTime>{
          DeliveryStage.matched: DateTime(2026, 5, 17, 10, 0),
        },
    pickup: const DeliveryAddress(label: 'Hamra'),
    dropoff: const DeliveryAddress(label: 'Verdun'),
    tier: DeliveryTier.scooter,
    jeeber: jeeber ??
        const JeeberSummary(
          displayName: 'Karim H.',
          vehicleLabel: 'Scooter',
          phoneE164: '+96171000000',
          rating: 4.8,
        ),
    etaMinutes: etaMinutes,
  );
}

/// Mounts [DeliveryStatusScreen] with the screen owning its cubit lifecycle.
/// We deliberately pass the [gateway] (the `BlocProvider.create` path) rather
Future<void> _pumpScreen(
  WidgetTester tester, {
  required DeliveryStatusGateway gateway,
  String deliveryId = 'd-1',
  ContactJeeberHandler? onContactJeeber,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: DeliveryStatusScreen(
        deliveryId: deliveryId,
        gateway: gateway,
        onContactJeeber: onContactJeeber,
      ),
    ),
  );
  // The active-stage pulsing dot uses a repeating AnimationController, so
  await tester.pump();
}

void main() {
  testWidgets('renders the stage indicator + jeeber card + details on ready',
      (tester) async {
    await _pumpScreen(
      tester,
      gateway: InMemoryDeliveryStatusGateway(
        seed: _snapshot(stage: DeliveryStage.inTransit, etaMinutes: 7),
      ),
    );
    expect(find.byKey(DeliveryStageIndicator.listKey), findsOneWidget);
    expect(find.byKey(DeliveryDetailsCard.rootKey), findsOneWidget);
    expect(find.byKey(DeliveryJeeberCard.rootKey), findsOneWidget);
    expect(find.byKey(DeliveryEtaBadge.rootKey), findsOneWidget);
  });

  testWidgets('hides the ETA badge when not in transit', (tester) async {
    await _pumpScreen(
      tester,
      gateway: InMemoryDeliveryStatusGateway(
        seed: _snapshot(stage: DeliveryStage.matched),
      ),
    );
    expect(find.byKey(DeliveryEtaBadge.rootKey), findsNothing);
  });

  testWidgets('shows the completed banner and hides action buttons on delivery',
      (tester) async {
    await _pumpScreen(
      tester,
      gateway: InMemoryDeliveryStatusGateway(
        seed: _snapshot(
          stage: DeliveryStage.delivered,
          lifecycle: DeliveryLifecycle.completed,
        ),
      ),
    );
    expect(find.byKey(DeliveryLifecycleBanner.rootKey), findsOneWidget);
    expect(
      find.text('Cancel delivery'),
      findsNothing,
      reason: 'terminal state must hide the cancel CTA',
    );
    expect(
      find.text('Contact Jeeber'),
      findsNothing,
      reason: 'terminal state must hide the contact CTA',
    );
  });

  testWidgets('contact CTA invokes the handler with the gateway-supplied phone',
      (tester) async {
    String? captured;
    await _pumpScreen(
      tester,
      gateway: InMemoryDeliveryStatusGateway(seed: _snapshot()),
      onContactJeeber: (n) => captured = n,
    );
    // The CTA sits at the bottom of a scrolling column; on the default
    final contactCta = find.text('Contact Jeeber');
    await tester.ensureVisible(contactCta);
    await tester.pump();
    await tester.tap(contactCta);
    // The contact handler is synchronous; the screen has a live pulsing-dot
    await tester.pump();
    expect(captured, '+96171000000');
  });

  testWidgets('cancel CTA is hidden once the courier picks up',
      (tester) async {
    await _pumpScreen(
      tester,
      gateway: InMemoryDeliveryStatusGateway(
        seed: _snapshot(
          stage: DeliveryStage.pickedUp,
          stageTimestamps: {
            DeliveryStage.matched: DateTime(2026, 5, 17, 10, 0),
            DeliveryStage.pickedUp: DateTime(2026, 5, 17, 10, 6),
          },
        ),
      ),
    );
    expect(find.text('Cancel delivery'), findsNothing);
    expect(find.text('Contact Jeeber'), findsOneWidget);
  });

  testWidgets('renders the error view with retry when the stream errors',
      (tester) async {
    // A gateway that throws on subscribe pushes the stream into the error
    await _pumpScreen(tester, gateway: _BrokenGateway());
    expect(find.text("Couldn't load the status"), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}

class _BrokenGateway implements DeliveryStatusGateway {
  @override
  Stream<DeliverySnapshot> watch(String deliveryId) =>
      Stream<DeliverySnapshot>.error(StateError('transport down'));

  @override
  Future<CancellationOutcome> cancel(String deliveryId) async =>
      CancellationOutcome.networkError;
}
