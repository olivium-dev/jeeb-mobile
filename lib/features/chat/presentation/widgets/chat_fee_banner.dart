import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/formatting/money_format.dart';
import '../../domain/delivery_chat_message.dart';
import '../chat_screen.dart' show kChatHeaderMaxViewportFraction;
import 'chat_message_bubble.dart';
import '../../../../core/previews/jeeb_preview.dart';

enum ChatFeeBannerTrailing {
  none,

  dismiss,

  orderPicked,
}

class ChatFeeBanner extends StatelessWidget {
  const ChatFeeBanner({
    super.key,
    required this.amount,
    this.trailing = ChatFeeBannerTrailing.none,
    this.onDismiss,
    this.onOrderPicked,
  });

  final String amount;

  final ChatFeeBannerTrailing trailing;

  final VoidCallback? onDismiss;

  final VoidCallback? onOrderPicked;

  static const Key bannerKey = Key('chat-fee-banner');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'chat_dm_fee_banner',
      explicitChildNodes: true,
      child: Container(
        key: bannerKey,
        width: double.infinity,
        color: colorScheme.secondaryContainer,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.xLarge,
          vertical: Spacing.medium,
        ),
        child: Row(
          children: [
            Expanded(child: _BannerText(amount: amount)),
            _TrailingControl(
              trailing: trailing,
              onDismiss: onDismiss,
              onOrderPicked: onOrderPicked,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrailingControl extends StatelessWidget {
  const _TrailingControl({
    required this.trailing,
    required this.onDismiss,
    required this.onOrderPicked,
  });

  final ChatFeeBannerTrailing trailing;
  final VoidCallback? onDismiss;
  final VoidCallback? onOrderPicked;

  @override
  Widget build(BuildContext context) {
    switch (trailing) {
      case ChatFeeBannerTrailing.none:
        return const SizedBox.shrink();
      case ChatFeeBannerTrailing.dismiss:
        return _BannerDismiss(onDismiss: onDismiss);
      case ChatFeeBannerTrailing.orderPicked:
        return _BannerOrderPicked(onOrderPicked: onOrderPicked);
    }
  }
}

class _BannerText extends StatelessWidget {
  const _BannerText({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      label: l10n.chatBalanceDeductionA11y(amount),
      child: Text(
        l10n.chatBalanceDeductionNotice(amount),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.start,
      ),
    );
  }
}

class _BannerDismiss extends StatelessWidget {
  const _BannerDismiss({required this.onDismiss});

  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'chat_dm_fee_banner_dismiss',
      button: true,
      container: true,
      label: l10n.chatBalanceDeductionDismissA11y,
      child: InkResponse(
        onTap: onDismiss,
        radius: Sizes.fourXLarge,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: Spacing.small),
          child: Icon(
            Icons.close,
            size: Sizes.large,
            color: colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}

class _BannerOrderPicked extends StatelessWidget {
  const _BannerOrderPicked({required this.onOrderPicked});

  final VoidCallback? onOrderPicked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: Spacing.small),
      child: Semantics(
        identifier: 'chat_dm_order_picked_button',
        button: true,
        container: true,
        label: l10n.chatDmOrderPickedAction,
        child: OmdsPrimaryButton(
          key: const Key('chat-fee-banner-order-picked'),
          text: l10n.chatDmOrderPickedAction,
          onTap: onOrderPicked ?? () {},
          backgroundColor: colorScheme.secondaryContainer,
          textColor: colorScheme.onPrimary,
          borderRadius: OmdsBorderRadius.pill,
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/chat/chat_fee_banner_preview_test.dart
// ===========================================================================

// Widget previews for [ChatFeeBanner] — run with
// `flutter widget-preview start`.
//
// The banner is a full-bleed navy band with ONE flexible child (the localized
// notice) and ONE non-flexible trailing control. Its whole behaviour therefore
// falls out of three inputs: the pre-formatted [ChatFeeBanner.amount] string,
// which [ChatFeeBannerTrailing] is mounted, and the WIDTH it is handed. Every
// preview below varies exactly those, at the widths the app actually ships to.
//
// Network-free by construction: the widget takes no cubit and no repository —
// `amount` is a plain string the gateway fee config pre-formats, and the UI
// never computes currency itself. The `$0.5` fixtures are the ones
// `test/chat_dm_states_test.dart` and `test/chat_dm_header_parity_test.dart`
// already use; the LBP fixture goes through the app's own [MoneyFormat].
//
// Production placement is `chat_screen.dart` (`_ChatBody.header`, via
// `_FeeBannerSlot`) — the FIRST chrome child above the thread, Jeeber-only,
// bounded by [kChatHeaderMaxViewportFraction]. Each preview pins an explicit
// device width so the heights quoted in the comments below are reproducible;
// the canvas box alone cannot do that, because [jeebPreviewHost] stretches the
// widget to the host.
//
// WHAT THE MATRIX EXPOSES (all measured, not guessed — see the render test):
// the `orderPicked` pill is laid out as a NON-FLEX child, so `RenderFlex`
// hands it unbounded width and it takes its full intrinsic size BEFORE the
// `Expanded` notice gets anything. At 390 dp / 1.0 the pill is 201.2 dp of a
// 390 dp band; at the 200% rendering it is 369.2 dp (452.0 dp in Arabic), the
// notice is allocated 0.0 dp, and the band grows to 1472 dp. Neither the
// dismiss nor the plain variant does this.

/// The widest phone the app targets, and the width every quoted height below
/// was measured at.
const double _chatFeeBannerPhoneWidth = 390;

/// The narrowest width the app ships to.
const double _chatFeeBannerSmallPhoneWidth = 320;

/// Frozen instant for the thread fixture, so the bubble clock never drifts
/// between runs of the canvas.
final DateTime _chatFeeBannerFrozenAt = DateTime(2026, 6, 1, 12, 30);

/// The banner at a real device width, laid out from the leading edge so the
/// trailing control sits where a phone would put it.
///
/// [width] is pinned rather than inherited because the preview host stretches
/// its child; without it the band would be as wide as the canvas and the notice
/// would never wrap, which is where every interesting failure lives.
Widget _chatFeeBannerHosted({
  required String amount,
  ChatFeeBannerTrailing trailing = ChatFeeBannerTrailing.none,
  double width = _chatFeeBannerPhoneWidth,
}) =>
    Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: width,
        child: ChatFeeBanner(
          amount: amount,
          trailing: trailing,
          onDismiss: () {},
          onOrderPicked: () {},
        ),
      ),
    );

/// The bare notice strip — `ChatFeeBannerTrailing.none`, Figma node 56539:906,
/// and the variant `dev_chat_preview_screen.dart` mounts for the plain `dm`
/// selector.
///
/// The baseline every other state is read against: 92 dp tall at 390 dp / 1.0,
/// 192 dp at the 200% rendering. With the whole row free to flex, the notice
/// gets the full 342 dp inside the padding and wraps cleanly — this is the
/// variant that behaves.
///
/// It is also the cleanest read of the DARK rendering: the band is
/// `colorScheme.secondaryContainer` and the copy is `colorScheme.onPrimary`,
/// which is white in the light theme but a dark navy in the dark theme.
@JeebPreview(group: 'chat', name: 'Plain notice', size: Size(_chatFeeBannerPhoneWidth, 220))
Widget chatFeeBannerPlainNotice() => _chatFeeBannerHosted(amount: r'$0.5');

/// The production default: `ChatFeeNotice.trailing` is
/// [ChatFeeBannerTrailing.dismiss], so this is the banner most Jeebers see.
///
/// Two things to look at. The × is padded with `EdgeInsetsDirectional.only(
/// start: …)`, so the AR RTL rendering must show it on the LEFT with the gap on
/// its inner side; if it stays on the right, the directional padding has been
/// swapped for a hardcoded `EdgeInsets`. And the control is small — the icon is
/// 20 dp and the whole `InkResponse` measures 32 × 20 dp, which is what the
/// user's thumb has to hit.
///
/// 92 dp at 1.0, 232 dp at the 200% rendering: the notice reflows and the band
/// grows, which is the correct degradation.
@JeebPreview(group: 'chat', name: 'Dismissible', size: Size(_chatFeeBannerPhoneWidth, 260))
Widget chatFeeBannerDismissible() => _chatFeeBannerHosted(
      amount: r'$0.75',
      trailing: ChatFeeBannerTrailing.dismiss,
    );

/// The `orderPicked` pill (Figma node 56560:1605) — and the state that breaks.
///
/// [_BannerOrderPicked] mounts an `OmdsPrimaryButton` whose `AnimatedContainer`
/// has `width: null`, as a NON-FLEXIBLE child of the banner's `Row`. A
/// `RenderFlex` lays non-flex children out with an unbounded main axis FIRST
/// and divides only the remainder among its flex children, so the pill claims
/// its full intrinsic width and the `Expanded` notice takes whatever is left:
///
/// * 390 dp / 1.0 → pill 201.2 dp, notice 128.8 dp, band 132 dp (5 lines for a
///   sentence that needs 3).
/// * 390 dp / 200% → pill 369.2 dp of a 390 dp band, notice **0.0 dp**, band
///   **1472 dp**, and the row reports *"A RenderFlex overflowed by 39 pixels on
///   the right"* — the pill itself runs off the trailing edge.
///
/// The 200% rendering of this preview cannot fit any sane canvas box; that it
/// does not fit is the finding, not a sizing mistake here.
@JeebPreview(group: 'chat', name: 'Order picked pill', size: Size(_chatFeeBannerPhoneWidth, 360))
Widget chatFeeBannerOrderPickedPill() => _chatFeeBannerHosted(
      amount: r'$1.25',
      trailing: ChatFeeBannerTrailing.orderPicked,
    );

/// The same pill at 320 dp — the narrowest width the app ships to, and the
/// width at which the squeeze is visible without touching the text scale.
///
/// The pill does not shrink: it is still 201.2 dp, so the notice is squeezed to
/// 58.8 dp and wraps to ten lines, taking the band from 92 dp to **232 dp** at
/// an ordinary 1.0 text scale. A notice strip that is 2.5× taller than its own
/// copy needs is already eating the message list's budget before the keyboard
/// is even up.
///
/// Worth reading in AR too: the Arabic label "تم استلام الطلب" makes the pill
/// WIDER than the English one (242.0 dp at 1.0, 452.0 dp at 200%), so Arabic
/// hits the starvation earlier than English at every width.
@JeebPreview(group: 'chat', name: 'Small phone 320dp', size: Size(_chatFeeBannerSmallPhoneWidth, 320))
Widget chatFeeBannerSmallPhoneOrderPicked() => _chatFeeBannerHosted(
      amount: r'$2.50',
      trailing: ChatFeeBannerTrailing.orderPicked,
      width: _chatFeeBannerSmallPhoneWidth,
    );

/// Longest plausible content: an LBP fee run through the app's own
/// [MoneyFormat] — `LBP 1,250,000.00`, four times the width of the `$0.5`
/// fixture, and the longest token the formatter can produce for a real fee.
///
/// Two reasons this state earns its place. It is the only one whose amount is
/// wrapped in a Unicode LTR isolate (U+2066…U+2069, JEBV4-98/F10), so the AR
/// rendering shows whether a Latin money token keeps its symbol placement
/// inside an Arabic sentence — the other fixtures are raw gateway strings like
/// `$0.5` and carry no isolate at all.
///
/// And it is the honest test of the claim in [ChatFeeBanner]'s own docs that
/// the copy "wraps and scales without clipping": with a flexible trailing slot
/// it does — 92 dp at 1.0, 272 dp at 200%, reflowing the whole way.
@JeebPreview(group: 'chat', name: 'Long LBP amount', size: Size(_chatFeeBannerPhoneWidth, 300))
Widget chatFeeBannerLongAmount() => _chatFeeBannerHosted(
      amount: MoneyFormat.format(1250000, currency: 'LBP'),
      trailing: ChatFeeBannerTrailing.dismiss,
    );

/// The production composition: the fee banner as the FIRST chrome child of
/// `_ChatBody`'s bounded header slot, above the thread.
///
/// This is where the height blow-ups above actually cost something. The chrome
/// is capped at [kChatHeaderMaxViewportFraction] of the body height (the b02
/// "BOTTOM OVERFLOWED BY 16 PIXELS" fix) and scrolls inside that cap; the body
/// here is 300 dp, as a small phone has once the app bar, composer and keyboard
/// are subtracted, which leaves the banner a 120 dp slot.
///
/// At 1.0 the 92 dp band sits inside the slot with room to spare, so the bound
/// is inert — that is the correct ordinary case. At the 200% rendering the band
/// exceeds the slot and the correct degradation is a SCROLL. If the canvas ever
/// shows a clipped band or an overflow stripe here instead, the bound has
/// regressed.
@JeebPreview(group: 'chat', name: 'Bounded header slot', size: Size(_chatFeeBannerPhoneWidth, 340))
Widget chatFeeBannerBoundedHeaderSlot() => Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: _chatFeeBannerPhoneWidth,
        height: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 300 * kChatHeaderMaxViewportFraction,
              ),
              child: SingleChildScrollView(
                child: ChatFeeBanner(
                  amount: r'$3.00',
                  trailing: ChatFeeBannerTrailing.dismiss,
                  onDismiss: () {},
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: <Widget>[
                  ChatMessageBubble(
                    message: DeliveryChatMessage.text(
                      id: 'm-1',
                      author: ChatAuthor.them,
                      sentAt: _chatFeeBannerFrozenAt,
                      status: MessageStatus.read,
                      text: 'Can you pick it up from Hamra before 6?',
                    ),
                  ),
                  ChatMessageBubble(
                    message: DeliveryChatMessage.text(
                      id: 'm-2',
                      author: ChatAuthor.me,
                      sentAt: _chatFeeBannerFrozenAt,
                      status: MessageStatus.read,
                      text: 'On my way, 5 min.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
