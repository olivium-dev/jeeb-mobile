// Render tests for the AvailabilityStatusBlock previews.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_home/application/availability_state.dart';
import 'package:jeeb_mobile/features/jeeber_home/domain/entities/availability_status.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/availability_card.dart';
import 'package:jeeb_mobile/features/jeeber_home/presentation/widgets/availability_status_block.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'Offline · headline only': availabilityStatusBlockOffline,
  'Auto-offline · 2 deliveries dropped':
      availabilityStatusBlockAutoOfflineHoldingWork,
  'Online · empty queue': availabilityStatusBlockOnlineEmpty,
  'Online · 2 deliveries': availabilityStatusBlockOnlineTwo,
  'Going online · in flight': availabilityStatusBlockGoingOnline,
  'Going offline · in flight, 3 deliveries':
      availabilityStatusBlockGoingOffline,
};

final Finder _block = find.byKey(AvailabilityStatusBlock.rootKey);
final Finder _activeDeliveries =
    find.byKey(AvailabilityStatusBlock.activeDeliveriesKey);

/// Pumps [preview] on a real 390pt phone instead of the 800x600 test surface,
/// optionally at a raised text scale.
Future<void> _pumpOnPhone(
  WidgetTester tester,
  Widget Function() preview, {
  double textScale = 1.0,
  Locale locale = const Locale('en'),
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 900);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: previewCanvas(preview, locale),
    ),
  );
  await tester.pump();
}

/// The paragraph behind a rendered string, for the question a [Finder] cannot
/// answer: how tall the text WANTED to be.
RenderParagraph _paragraph(WidgetTester tester, String text) =>
    tester.renderObject<RenderParagraph>(find.text(text));

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'AvailabilityStatusBlock',
    _previews,
    expectedText: const <String, String>{
      'Offline · headline only': "You're offline",
      'Auto-offline · 2 deliveries dropped': 'Automatically taken offline',
      'Online · empty queue': 'No active deliveries',
      'Online · 2 deliveries': '2 active deliveries',
      'Going online · in flight': 'Updating…',
      'Going offline · in flight, 3 deliveries': '3 active deliveries',
    },
  );

  group('AvailabilityStatusBlock preview specifics', () {
    testWidgets('the preview width is the width the REAL card hands it', (
      WidgetTester tester,
    ) async {
      // `availabilityStatusBlockSlotWidth` is derived by hand from
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        previewCanvas(
          () => const AvailabilityCard(
            view: AvailabilityViewState(
              loadPhase: AvailabilityLoadPhase.ready,
              status: AvailabilityStatus(
                state: AvailabilityState.online,
                activeDeliveryCount: 3,
              ),
              isToggleInFlight: true,
            ),
            onToggle: _noop,
          ),
          const Locale('en'),
        ),
      );
      await tester.pump();

      expect(
        tester.getSize(_block).width,
        availabilityStatusBlockSlotWidth,
        reason: 'the preview host must reproduce the real slot, not guess it',
      );
    });

    testWidgets('auto-offline SILENTLY DROPS the deliveries still assigned', (
      WidgetTester tester,
    ) async {
      // Reachable today: `AvailabilityCubit._onIdleTick` emits
      await _pumpOnPhone(
        tester,
        availabilityStatusBlockAutoOfflineHoldingWork,
      );

      expect(find.text('Automatically taken offline'), findsOneWidget);
      expect(_activeDeliveries, findsNothing);
      expect(find.textContaining('active deliver'), findsNothing);
      expect(find.text('Auto-offline after 8 h idle'), findsNothing);

      // The same two deliveries ARE disclosed when the state is online, which
      await _pumpOnPhone(tester, availabilityStatusBlockOnlineTwo);
      expect(_activeDeliveries, findsOneWidget);
      expect(find.text('2 active deliveries'), findsOneWidget);
    });

    testWidgets('in flight, the block asserts the STALE pre-toggle truth', (
      WidgetTester tester,
    ) async {
      // `_StatusHeadline` short-circuits to "Updating…" on isToggleInFlight,
      await _pumpOnPhone(tester, availabilityStatusBlockGoingOffline);

      expect(find.text('Updating…'), findsOneWidget);
      expect(find.text('3 active deliveries'), findsOneWidget);
      expect(find.text('Auto-offline after 8 h idle'), findsOneWidget);

      // Going the other way the guard is false, so the identical headline is
      await _pumpOnPhone(tester, availabilityStatusBlockGoingOnline);
      expect(find.text('Updating…'), findsOneWidget);
      expect(_activeDeliveries, findsNothing);
      expect(find.text('Auto-offline after 8 h idle'), findsNothing);
    });

    testWidgets('every line is start-aligned and mirrors in Arabic', (
      WidgetTester tester,
    ) async {
      // CrossAxisAlignment.start + TextAlign.start, so the three lines share a
      await _pumpOnPhone(tester, availabilityStatusBlockOnlineTwo);
      Rect block = tester.getRect(_block);
      final Rect headlineLtr = tester.getRect(
        find.text("You're online — receiving requests"),
      );
      expect(headlineLtr.left, block.left);
      expect(
        tester.getRect(find.text('2 active deliveries')).left,
        block.left,
        reason: 'LTR: the count shares the headline\'s leading edge',
      );
      expect(
        tester.getRect(find.text('Auto-offline after 8 h idle')).left,
        block.left,
      );

      await _pumpOnPhone(
        tester,
        availabilityStatusBlockOnlineTwo,
        locale: const Locale('ar'),
      );
      block = tester.getRect(_block);
      expect(
        tester.getRect(find.text('أنت متصل — تستقبل الطلبات')).right,
        block.right,
        reason: 'AR: the headline must hug the trailing (right) edge',
      );
      expect(
        tester.getRect(find.text('توصيلتان نشطتان')).right,
        block.right,
        reason: 'AR: count=2 is the DUAL form, and it mirrors with the rest',
      );
      expect(
        tester.getRect(find.text('إيقاف تلقائي بعد 8 ساعات من عدم النشاط')).right,
        block.right,
      );
      // And the block itself sits at the trailing edge of its host.
      expect(block.right, greaterThan(390 / 2));
    });

    testWidgets('nothing is truncated at the 200% ceiling — it grows instead', (
      WidgetTester tester,
    ) async {
      // The block is a Column of plain Texts with no maxLines, no ellipsis and
      await _pumpOnPhone(tester, availabilityStatusBlockGoingOffline);
      final double atOneX = tester.getSize(_block).height;
      RenderParagraph hint = _paragraph(tester, 'Auto-offline after 8 h idle');
      expect(hint.getMinIntrinsicHeight(hint.size.width), hint.size.height);
      expect(hint.didExceedMaxLines, isFalse);

      await _pumpOnPhone(
        tester,
        availabilityStatusBlockGoingOffline,
        textScale: 2.0,
      );
      hint = _paragraph(tester, 'Auto-offline after 8 h idle');
      expect(
        hint.didExceedMaxLines,
        isFalse,
        reason: 'the hint wraps rather than clipping — no maxLines is set',
      );
      expect(
        tester.getSize(_block).height,
        greaterThan(atOneX * 2),
        reason: 'a three-line stack at 290pt more than doubles at 200% text '
            '(measured 76pt -> 240pt here, and 76pt -> 360pt for the settled '
            'online headline); whatever hosts it must have room to give',
      );
      expect(tester.takeException(), isNull);
    });
  });
}

void _noop() {}
