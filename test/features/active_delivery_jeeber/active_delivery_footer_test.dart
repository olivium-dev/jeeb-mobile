// redesign-2026-08 screen 18: the docked 3-pill footer and the RTL behaviour of
// the rebuilt drop-off card / door-code row.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_code_cells.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/application/active_delivery_cubit.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/active_delivery_repository.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/domain/jeeber_delivery_status.dart';
import 'package:jeeb_mobile/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

class _Repo implements ActiveDeliveryRepository {
  const _Repo(this.delivery);

  final JeeberDelivery delivery;

  @override
  Future<JeeberDelivery> fetchDelivery(String deliveryId) async => delivery;

  @override
  Future<JeeberDeliveryStatus> transition({
    required String deliveryId,
    required JeeberDeliveryStatus from,
    required JeeberDeliveryStatus to,
    String? evidenceUrl,
  }) async => to;

  @override
  Future<String> uploadProofPhoto({
    required String deliveryId,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async => 'proof://x';

  @override
  Future<JeeberDeliveryStatus> verifyDoorOtp({
    required String deliveryId,
    required String code,
  }) async => JeeberDeliveryStatus.done;
}

JeeberDelivery _delivery({
  JeeberDeliveryStatus status = JeeberDeliveryStatus.inTransit,
  String? amountText = r'$8.00',
}) => JeeberDelivery(
  id: 'd1',
  status: status,
  dropOff: const DropOffAddress(
    label: 'Rue Monot 42',
    detail: 'Ring twice',
    lat: 33.9,
    lng: 35.5,
  ),
  amountText: amountText,
);

Future<ActiveDeliveryCubit> _seed(JeeberDelivery delivery) async {
  final cubit = ActiveDeliveryCubit(
    repository: _Repo(delivery),
    deliveryId: 'd1',
    refreshSignals: const Stream<void>.empty(),
  );
  await cubit.loadDelivery();
  return cubit;
}

Future<void> _pump(
  WidgetTester tester, {
  required ActiveDeliveryCubit cubit,
  VoidCallback? onEnterGoodsCost,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: ActiveDeliveryJeeberScreen(
        deliveryId: 'd1',
        cubit: cubit,
        onOpenChat: () {},
        onEnterGoodsCost: onEnterGoodsCost,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('quick-action footer', () {
    testWidgets('three pills sit on ONE row at 390pt / 1.0 scale', (
      tester,
    ) async {
      final cubit = await _seed(_delivery());
      addTearDown(cubit.close);
      await _pump(tester, cubit: cubit, onEnterGoodsCost: () {});

      final maps = find.bySemanticsIdentifier('mark_delivered_open_maps_cta');
      final chat = find.bySemanticsIdentifier('mark_delivered_open_chat_cta');
      final costs = find.bySemanticsIdentifier('mark_delivered_goods_cost_cta');
      expect(maps, findsOneWidget);
      expect(chat, findsOneWidget);
      expect(costs, findsOneWidget);

      final y = tester.getTopLeft(maps).dy;
      expect(tester.getTopLeft(chat).dy, y);
      expect(tester.getTopLeft(costs).dy, y);
      expect(tester.getTopLeft(chat).dx, greaterThan(tester.getTopLeft(maps).dx));
      expect(
        tester.getTopLeft(costs).dx,
        greaterThan(tester.getTopLeft(chat).dx),
      );
    });

    testWidgets('the pills stack at 200% text scale (the a11y guard)', (
      tester,
    ) async {
      final cubit = await _seed(_delivery());
      addTearDown(cubit.close);
      await _pump(
        tester,
        cubit: cubit,
        onEnterGoodsCost: () {},
        textScale: 2,
      );

      final maps = find.bySemanticsIdentifier('mark_delivered_open_maps_cta');
      final chat = find.bySemanticsIdentifier('mark_delivered_open_chat_cta');
      expect(
        tester.getTopLeft(chat).dy,
        greaterThan(tester.getTopLeft(maps).dy),
        reason: 'at 2.0 the labels cannot share a row',
      );
    });

    testWidgets('the Costs pill is absent when no caller wired it', (
      tester,
    ) async {
      final cubit = await _seed(_delivery());
      addTearDown(cubit.close);
      await _pump(tester, cubit: cubit);

      expect(
        find.bySemanticsIdentifier('mark_delivered_goods_cost_cta'),
        findsNothing,
        reason: 'GoodsCostScreen is an orphan; production must show two pills',
      );
      expect(
        find.bySemanticsIdentifier('mark_delivered_open_maps_cta'),
        findsOneWidget,
      );
    });
  });

  group('drop-off card', () {
    testWidgets('renders the collect line, never a fabricated amount', (
      tester,
    ) async {
      final cubit = await _seed(_delivery(amountText: null));
      addTearDown(cubit.close);
      await _pump(tester, cubit: cubit);

      expect(
        find.bySemanticsIdentifier('mark_delivered_cash_note'),
        findsOneWidget,
      );
      expect(
        find.text('Ring twice · Collect the order amount in cash on delivery'),
        findsOneWidget,
      );
    });

    testWidgets('folds the amount in when the snapshot carries one', (
      tester,
    ) async {
      final cubit = await _seed(_delivery());
      addTearDown(cubit.close);
      await _pump(tester, cubit: cubit);

      expect(
        find.text(r'Ring twice · Collect $8.00 cash on delivery'),
        findsOneWidget,
      );
    });

    // MIDNIGHT draws no trailing directions circle — the docked `Maps` pill
    // owns that action — so the card's RTL guard moves onto the leading pin.
    testWidgets('RTL: the leading pin mirrors to the end edge', (
      tester,
    ) async {
      final cubit = await _seed(_delivery());
      addTearDown(cubit.close);
      await _pump(tester, cubit: cubit, locale: const Locale('ar'));

      expect(
        find.bySemanticsIdentifier('mark_delivered_directions_cta'),
        findsNothing,
      );
      final pin = tester.getCenter(find.byIcon(Icons.location_on));
      final address = tester.getCenter(find.text('Rue Monot 42'));
      expect(
        pin.dx,
        greaterThan(address.dx),
        reason: 'under RTL the leading pin sits on the visual right',
      );
    });
  });

  group('door-code row', () {
    testWidgets('the code cells stay LTR under an Arabic locale', (
      tester,
    ) async {
      final cubit = await _seed(_delivery(status: JeeberDeliveryStatus.atDoor));
      addTearDown(cubit.close);
      await cubit.markDelivered();
      await _pump(tester, cubit: cubit, locale: const Locale('ar'));

      final cells = find.byType(JeebCodeCells);
      expect(cells, findsOneWidget);
      final isolate = tester.widget<Directionality>(
        find
            .descendant(of: cells, matching: find.byType(Directionality))
            .first,
      );
      expect(
        isolate.textDirection,
        TextDirection.ltr,
        reason: 'a door code never reorders — that hands over the wrong code',
      );
      expect(
        find.bySemanticsIdentifier('mark_delivered_otp_input'),
        findsOneWidget,
      );
    });
  });
}
