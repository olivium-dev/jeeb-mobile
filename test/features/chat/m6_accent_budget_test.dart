/// M6 accent-budget guards for `chat/`.
///
/// Every row here reads a colour off the widget, because the golden gate is
/// blind to token changes: `_TolerantGoldenComparator` accepts 5% pixel diff
/// and a real ink swap moves ~0.1%. Each expectation was proved discriminating
/// by reverting the production value and watching it go red.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_scrim.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/features/chat/domain/delivery_chat_message.dart';
import 'package:jeeb_mobile/features/chat/domain/order_chat_summary.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/chat_header_expansion_store.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/confirm_delivery_action_sheet.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/delivery_confirm_illustration.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/offer_card_bubble.dart';
import 'package:jeeb_mobile/features/chat/presentation/widgets/order_chat_pinned_summary.dart';
import 'package:omds/omds.dart';

import 'chat_header_support.dart';

final JeebSemanticColors _tokens = JeebSemanticColors.midnight();
const ColorScheme _scheme = AppTheme.midnightScheme;

/// The `BoxDecoration` of the nearest [Container] ancestor of [of].
BoxDecoration _decorationAbove(WidgetTester tester, Finder of) =>
    tester
        .widget<Container>(
          find.ancestor(of: of, matching: find.byType(Container)).first,
        )
        .decoration! as BoxDecoration;

const OrderChatSummary _summary = OrderChatSummary(
  deliveryId: '9acb579d-1c2e-4f3a-b8d1-77aa10cc42e6',
  orderRef: 'ORD-23470',
  priceLabel: r'$12.00',
  jeeberName: 'Kamal Hajj',
  statusId: 'in_transit',
);

DeliveryChatMessage _offerMessage() => DeliveryChatMessage.offerCard(
      id: 'm-1',
      author: ChatAuthor.them,
      sentAt: DateTime(2026, 6, 1, 9, 41),
      status: MessageStatus.delivered,
      payload: const OfferCardPayload(
        offerId: 'offer-1',
        jeeberId: 'j-1',
        jeeberName: 'Kamal Hajj',
        fee: 35,
        currency: 'USD',
        etaMinutes: 30,
        rating: 4.6,
      ),
    );

void main() {
  setUpAll(loadArb);
  setUp(ChatHeaderExpansionStore.instance.reset);

  testWidgets('the pinned strip Track pill is glass, not a white slab',
      (WidgetTester tester) async {
    await tester.pumpWidget(themedHost(Scaffold(
      body: OrderChatPinnedSummary(
        summary: _summary,
        counterpartName: 'Kamal Hajj',
        onViewSummary: () {},
        onTrack: () {},
      ),
    )));
    await tester.pump();

    final Finder label = find.text('Track order');
    final BoxDecoration pill = _decorationAbove(tester, label);

    // Was `onPrimary` fill + `primary` ink: an orange-on-WHITE pill inside the
    // navy strip, and the loudest thing on the whole thread.
    expect(pill.color, _tokens.glassFillEmphasis);
    expect(pill.color, isNot(_scheme.onPrimary));
    expect((pill.border! as Border).top.color, _tokens.glassBorder);
    expect(tester.widget<Text>(label).style?.color, _scheme.onPrimary);
    expect(tester.widget<Text>(label).style?.color, isNot(_scheme.primary));
  });

  testWidgets('the confirm-delivery grabber and heading spend no accent',
      (WidgetTester tester) async {
    await tester.pumpWidget(themedHost(Scaffold(
      body: ConfirmDeliveryActionSheet(
        kind: DeliveryConfirmKind.picking,
        onConfirm: () {},
      ),
    )));
    await tester.pump();

    final BoxDecoration grabber = tester
        .widget<Container>(
          find.descendant(
            of: find.bySemanticsIdentifier('confirm_delivery_drag_handle'),
            matching: find.byType(Container),
          ),
        )
        .decoration! as BoxDecoration;
    expect(grabber.color, _tokens.glassBorderVivid);
    expect(grabber.color, isNot(_scheme.primary));

    final Text title = tester.widget<Text>(
      find.descendant(
        of: find.bySemanticsIdentifier('confirm_delivery_title'),
        matching: find.byType(Text),
      ),
    );
    expect(title.style?.color, _scheme.onSurface);
    expect(title.style?.color, isNot(_scheme.primary));
  });

  testWidgets('the confirm illustration inks periwinkle, not raised navy',
      (WidgetTester tester) async {
    await tester.pumpWidget(themedHost(const Scaffold(
      body: SizedBox(width: 271, child: DeliveryConfirmIllustration()),
    )));
    await tester.pump();

    final BuildContext context =
        tester.element(find.byType(DeliveryConfirmIllustration));
    expect(DeliveryConfirmIllustration.strokeOf(context),
        _scheme.onSurfaceVariant);
    expect(
      DeliveryConfirmIllustration.strokeOf(context),
      isNot(_scheme.secondaryContainer),
      reason: 'raised navy on card navy is 1.2:1 — invisible line art',
    );
    expect(
      contrastRatio(
        DeliveryConfirmIllustration.strokeOf(context),
        _scheme.surface,
      ),
      greaterThanOrEqualTo(kAaLargeTextAndNonText),
    );
  });

  testWidgets('offer-card stars are amber and the name is white',
      (WidgetTester tester) async {
    await tester.pumpWidget(themedHost(Scaffold(
      body: OfferCardBubble(message: _offerMessage(), onAccept: (_) {}),
    )));
    await tester.pump();

    final OmdsStarRatingDisplay stars =
        tester.widget<OmdsStarRatingDisplay>(
      find.byType(OmdsStarRatingDisplay),
    );
    expect(stars.activeColor, _tokens.amber);
    expect(stars.activeColor, isNot(_scheme.tertiary));

    final Text name = tester.widget<Text>(find.text('Kamal Hajj'));
    expect(name.style?.color, _scheme.onSurface);
    expect(name.style?.color, isNot(_scheme.primary));
  });

  test('the sheet barrier is black-based, never pale periwinkle', () {
    // `onSecondaryContainer` at `opacityHigh` is #B9C0F0 at 87% — a veil that
    // LIGHTENS the field. The scheme scrim is the only sanctioned black.
    expect(JeebScrim.barrierAlpha, 0.55);
    final Color barrier =
        _scheme.scrim.withValues(alpha: JeebScrim.barrierAlpha);
    expect(barrier.computeLuminance(), lessThan(0.01));
    expect(
      _scheme.onSecondaryContainer.computeLuminance(),
      greaterThan(barrier.computeLuminance()),
    );
  });
}
