import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/delivery_status/application/delivery_status_cubit.dart';
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

Future<void> _pumpScreen(
  WidgetTester tester, {
  required DeliveryStatusCubit cubit,
  ContactJeeberHandler? onContactJeeber,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: DeliveryStatusScreen(
        deliveryId: cubit.deliveryId,
        cubit: cubit,
        onContactJeeber: onContactJeeber,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the stage indicator + jeeber card + details on ready',
      (tester) async {
    final gateway = InMemoryDeliveryStatusGateway(
      seed: _snapshot(stage: DeliveryStage.inTransit, etaMinutes: 7),
    );
    final cubit = DeliveryStatusCubit(deliveryId: 'd-1', gateway: gateway);
    await _pumpScreen(tester, cubit: cubit);
    expect(find.byKey(DeliveryStageIndicator.listKey), findsOneWidget);
    expect(find.byKey(DeliveryDetailsCard.rootKey), findsOneWidget);
    expect(find.byKey(DeliveryJeeberCard.rootKey), findsOneWidget);
    expect(find.byKey(DeliveryEtaBadge.rootKey), findsOneWidget);
    await cubit.close();
  });

  testWidgets('hides the ETA badge when not in transit', (tester) async {
    final gateway = InMemoryDeliveryStatusGateway(
      seed: _snapshot(stage: DeliveryStage.matched),
    );
    final cubit = DeliveryStatusCubit(deliveryId: 'd-1', gateway: gateway);
    await _pumpScreen(tester, cubit: cubit);
    expect(find.byKey(DeliveryEtaBadge.rootKey), findsNothing);
    await cubit.close();
  });

  testWidgets('shows the completed banner and hides action buttons on delivery',
      (tester) async {
    final gateway = InMemoryDeliveryStatusGateway(
      seed: _snapshot(
        stage: DeliveryStage.delivered,
        lifecycle: DeliveryLifecycle.completed,
      ),
    );
    final cubit = DeliveryStatusCubit(deliveryId: 'd-1', gateway: gateway);
    await _pumpScreen(tester, cubit: cubit);
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
    await cubit.close();
  });

  testWidgets('contact CTA invokes the handler with the gateway-supplied phone',
      (tester) async {
    final gateway = InMemoryDeliveryStatusGateway(seed: _snapshot());
    final cubit = DeliveryStatusCubit(deliveryId: 'd-1', gateway: gateway);
    String? captured;
    await _pumpScreen(
      tester,
      cubit: cubit,
      onContactJeeber: (n) => captured = n,
    );
    await tester.tap(find.text('Contact Jeeber'));
    await tester.pumpAndSettle();
    expect(captured, '+96171000000');
    await cubit.close();
  });

  testWidgets('cancel CTA is hidden once the courier picks up',
      (tester) async {
    final gateway = InMemoryDeliveryStatusGateway(
      seed: _snapshot(
        stage: DeliveryStage.pickedUp,
        stageTimestamps: {
          DeliveryStage.matched: DateTime(2026, 5, 17, 10, 0),
          DeliveryStage.pickedUp: DateTime(2026, 5, 17, 10, 6),
        },
      ),
    );
    final cubit = DeliveryStatusCubit(deliveryId: 'd-1', gateway: gateway);
    await _pumpScreen(tester, cubit: cubit);
    expect(find.text('Cancel delivery'), findsNothing);
    expect(find.text('Contact Jeeber'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('renders the error view with retry when the stream errors',
      (tester) async {
    // Use a bare cubit + a gateway that throws on subscribe to push the
    // stream into the error state immediately.
    final cubit = DeliveryStatusCubit(
      deliveryId: 'd-1',
      gateway: _BrokenGateway(),
    );
    await _pumpScreen(tester, cubit: cubit);
    expect(find.text('Connection lost'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await cubit.close();
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
