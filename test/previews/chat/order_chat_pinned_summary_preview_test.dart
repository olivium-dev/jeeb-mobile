// Render tests for the OrderChatPinnedSummary previews.
//
// Nothing in CI opens the preview canvas, so an untested preview rots silently
// until someone runs it by hand. This follows the template in
// `test/previews/preview_test_harness.dart`.
//
// Two things beyond "it built" are pinned here. Each state asserts a string
// only IT renders — a suite that just checks "something rendered" passes even
// when every preview shows the same widget. And the collapsed/expanded pair is
// asserted structurally, because those previews seed the process-wide
// `ChatHeaderExpansionStore` with a key the preview file re-derives; if that
// copy ever drifts from `_OrderChatPinnedSummaryState._expansionKey`, every
// "expanded" preview silently opens collapsed and the expectedText checks below
// are the only thing that would notice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_header_expansion_store.dart';
import 'package:jeeb_mobile/previews/chat/order_chat_pinned_summary_preview.dart';

import '../preview_test_harness.dart';

/// The description's own `Text` node (the one `AutoDirectionText` renders).
Text _descriptionText(WidgetTester tester) => tester.widget<Text>(
      find.descendant(
        of: find.bySemanticsIdentifier('order_chat_request_description'),
        matching: find.byType(Text),
      ),
    );

void main() {
  setUpAll(loadPreviewArbs);
  // The expansion choice is remembered for the SESSION and widget tests share
  // one process. Every preview re-seeds its own key, so this is belt-and-braces
  // — but it is what keeps a failure here meaning "the preview is wrong" rather
  // than "the previous test leaked".
  setUp(ChatHeaderExpansionStore.instance.reset);

  testPreviewsRender(
    'OrderChatPinnedSummary',
    const <String, Widget Function()>{
      'Collapsed (default)': orderChatPinnedSummaryCollapsed,
      'Expanded (all fields)': orderChatPinnedSummaryExpanded,
      'Pending (nothing resolved)': orderChatPinnedSummaryPending,
      'Jeeber viewer (no link)': orderChatPinnedSummaryJeeberViewer,
      'Longest content': orderChatPinnedSummaryLongContent,
      'Arabic requirement in EN UI': orderChatPinnedSummaryArabicDescription,
    },
    expectedText: const <String, String>{
      // The collapsed row paints the reference and nothing disclosed.
      'Collapsed (default)': 'ORD-23470',
      // Only rendered once the strip is expanded — so this doubles as the
      // proof that the expanded previews really open expanded.
      'Expanded (all fields)': '2 kilos apples from Spinneys',
      // Derived from the delivery id: never a raw UUID, never the screen title.
      'Pending (nothing resolved)': '#7719D4',
      // The Jeeber's counterpart is a synthetic handle → localized generic.
      'Jeeber viewer (no link)': 'Customer',
      'Longest content': 'Abdulrahman Al-Muhandis Al-Trabulsi',
      'Arabic requirement in EN UI': '٢ كيلو تفاح من سبينيس',
    },
  );

  group('OrderChatPinnedSummary preview specifics', () {
    testWidgets('the collapsed preview really opens collapsed', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderChatPinnedSummaryCollapsed);

      // The whole collapsed row: reference, status, amount.
      expect(find.text('ORD-23470'), findsOneWidget);
      expect(find.text('In transit'), findsOneWidget);
      expect(find.text(r'$12.00'), findsOneWidget);
      // Everything else is one tap away, not on screen.
      for (final String id in const <String>[
        'order_summary_eta',
        'order_summary_tier',
        'order_summary_cash_label',
        'order_summary_jeeber_name',
        'order_chat_request_description',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsNothing, reason: id);
      }
    });

    testWidgets('the expanded preview seeds a key the widget agrees with', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderChatPinnedSummaryExpanded);

      // If the preview file's `_expansionKeyFor` ever drifts from the widget's
      // own `_expansionKey`, the seed lands under a key nobody reads and this
      // is the assertion that catches it.
      for (final String id in const <String>[
        'order_summary_eta',
        'order_summary_tier',
        'order_summary_cash_label',
        'order_summary_jeeber_name',
        'order_chat_view_summary_link',
        'order_chat_request_description',
      ]) {
        expect(find.bySemanticsIdentifier(id), findsOneWidget, reason: id);
      }
      expect(find.text('Pay cash on delivery'), findsOneWidget);
    });

    testWidgets('the pending preview shows the run-22 fixed vocabulary', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderChatPinnedSummaryPending);

      // price + ETA + tier unresolved → three localized placeholders…
      expect(find.text('Pending'), findsNWidgets(3));
      // …and the status floors at the accepted stage.
      expect(find.text('Matched'), findsOneWidget);
      // THE run-22 defect: the screen title must appear nowhere on the strip.
      expect(find.text('Order summary'), findsNothing);
      // No empty requirement box and no "Pending" filler for it either.
      expect(
        find.bySemanticsIdentifier('order_chat_request_description'),
        findsNothing,
      );
    });

    testWidgets('the Jeeber preview drops the owner-scoped link and leaks no '
        'synthetic handle', (WidgetTester tester) async {
      await pumpPreview(tester, orderChatPinnedSummaryJeeberViewer);

      expect(
        find.bySemanticsIdentifier('order_chat_pinned_summary'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier('order_chat_view_summary_link'),
        findsNothing,
      );
      expect(find.text('View summary'), findsNothing);
      expect(find.textContaining('jeeb-'), findsNothing);
    });

    testWidgets('the longest-content preview clamps the requirement to two '
        'lines', (WidgetTester tester) async {
      await pumpPreview(tester, orderChatPinnedSummaryLongContent);

      final Text description = _descriptionText(tester);
      expect(description.maxLines, 2);
      expect(description.overflow, TextOverflow.ellipsis);
      // The long reference ellipsises rather than pushing the amount and the
      // expand control off the trailing edge.
      expect(find.text('ORD-2026-0801-BEIRUT-HAMRA-0042'), findsOneWidget);
      expect(find.text('1,250,000 L.L.'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('order_chat_summary_expand'),
        findsOneWidget,
      );
    });

    testWidgets('the Arabic requirement reads RTL inside the English UI', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, orderChatPinnedSummaryArabicDescription);

      expect(_descriptionText(tester).textDirection, TextDirection.rtl);
      // …while the strip itself stays LTR under the English locale.
      expect(
        Directionality.of(
          tester.element(find.bySemanticsIdentifier('order_chat_pinned_summary')),
        ),
        TextDirection.ltr,
      );
    });
  });
}
