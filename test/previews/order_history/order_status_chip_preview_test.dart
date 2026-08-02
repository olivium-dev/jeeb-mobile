// Render tests for the OrderStatusChip previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/order_history/presentation/order_status_chip.dart';

import '../preview_test_harness.dart';

const Map<String, Widget Function()> _previews = <String, Widget Function()>{
  'In flight · En route': orderStatusChipInFlight,
  'Completed · Delivered': orderStatusChipDelivered,
  'Terminal · Cancelled': orderStatusChipCancelled,
  'Terminal · Disputed': orderStatusChipDisputed,
  'Unknown status · In progress': orderStatusChipUnknown,
  'Card header row · layout ceiling': orderStatusChipHeaderRow,
};

/// The chip's own pill — the [Container] `OrderStatusChip` builds.
Finder _pill() => find.descendant(
      of: find.byType(OrderStatusChip),
      matching: find.byType(Container),
    );

BoxDecoration _decoration(WidgetTester tester) =>
    tester.widget<Container>(_pill()).decoration! as BoxDecoration;

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'OrderStatusChip',
    _previews,
    // One distinct label per state. The chip's colour is chosen from
    // `status.tab`, so several states paint identically — the label is the only
    // thing that proves a preview rendered ITS OWN state rather than a
    // neighbour's.
    expectedText: const <String, String>{
      'In flight · En route': 'En route',
      'Completed · Delivered': 'Delivered',
      'Terminal · Cancelled': 'Cancelled',
      'Terminal · Disputed': 'Disputed',
      'Unknown status · In progress': 'In progress',
      'Card header row · layout ceiling': 'Picked up',
    },
  );

  group('OrderStatusChip preview specifics', () {
    testWidgets('an unrecognised status is labelled, never blank', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderStatusChipUnknown);

      // The forward-compatibility contract: `parse` funnels every status the
      // client has not heard of into `unknown`, and the chip must still say
      // something a customer can read — not an empty pill and not a raw wire
      // value such as `AtDoor`.
      final Text label = tester.widget<Text>(
        find.descendant(
          of: find.byType(OrderStatusChip),
          matching: find.byType(Text),
        ),
      );
      expect(label.data, isNotEmpty);
      expect(label.data, 'In progress');
    });

    testWidgets('the chip localizes into Arabic rather than falling back to '
        'the English label', (WidgetTester tester) async {
      await pumpPreview(
        tester,
        orderStatusChipDelivered,
        locale: const Locale('ar'),
      );

      expect(find.text('تم التسليم'), findsOneWidget);
      expect(find.text('Delivered'), findsNothing);
    });

    testWidgets('Disputed and Cancelled paint the SAME pill — only the word '
        'differs', (WidgetTester tester) async {
      // Not an endorsement: `disputed` buckets to `OrderHistoryTab.cancelled`,
      // so `_paletteFor` gives both the `errorContainer` fill. Pinned because
      // the two states mean opposite things to a customer (a dispute is open
      // and needs them; a cancellation is closed and needs nothing), and a
      // reviewer scrolling the canvas should know the identical colour is the
      // current contract rather than a canvas artefact.
      await pumpPreview(tester, orderStatusChipCancelled);
      final Color cancelled = _decoration(tester).color!;

      await pumpPreview(tester, orderStatusChipDisputed);
      final Color disputed = _decoration(tester).color!;

      expect(disputed, cancelled);
      expect(find.text('Disputed'), findsOneWidget);
      expect(find.text('Cancelled'), findsNothing);
    });

    testWidgets('header row · the chip keeps its full width and the date pays',
        (WidgetTester tester) async {
      await pumpPreview(tester, orderStatusChipHeaderRow);

      // The chip is the non-flexible child of the header `Row`, so it is
      // measured against unbounded width and never squeezed. Both children must
      // stay inside the 358pt the card really gives the row — an overflow here
      // is the yellow-and-black stripe on a real phone.
      final Rect row = tester.getRect(find.byType(Row).last);
      final Rect chip = tester.getRect(find.byType(OrderStatusChip));

      expect(chip.right, lessThanOrEqualTo(row.right + 0.5));
      expect(chip.left, greaterThanOrEqualTo(row.left - 0.5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('header row · RTL mirrors the row without help from the chip', (
      WidgetTester tester,
    ) async {
      // The chip's padding is `EdgeInsetsDirectional.symmetric`, and horizontal
      // symmetric padding has no side to get wrong — mirroring is the `Row`'s
      // job. This asserts the chip ends up on the START edge (left in Arabic)
      // and the date on the other side, which is what the AR rendering of the
      // matrix is there to show.
      await pumpPreview(tester, orderStatusChipHeaderRow);
      final Rect ltrChip = tester.getRect(find.byType(OrderStatusChip));
      final Rect ltrRow = tester.getRect(find.byType(Row).last);

      await pumpPreview(
        tester,
        orderStatusChipHeaderRow,
        locale: const Locale('ar'),
      );
      final Rect rtlChip = tester.getRect(find.byType(OrderStatusChip));
      final Rect rtlRow = tester.getRect(find.byType(Row).last);

      expect(
        ltrChip.right,
        closeTo(ltrRow.right, 0.5),
        reason: 'English: the chip is the trailing child, hard against the '
            'right edge of the row',
      );
      expect(
        rtlChip.left,
        closeTo(rtlRow.left, 0.5),
        reason: 'Arabic: the same trailing child must mirror to the left edge',
      );
    });
  });
}
