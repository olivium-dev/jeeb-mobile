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

// Widget previews for [ChatFeeBanner] — run with

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
@JeebPreview(group: 'chat', name: 'Plain notice', size: Size(_chatFeeBannerPhoneWidth, 220))
Widget chatFeeBannerPlainNotice() => _chatFeeBannerHosted(amount: r'$0.5');

/// The production default: `ChatFeeNotice.trailing` is
/// [ChatFeeBannerTrailing.dismiss], so this is the banner most Jeebers see.
@JeebPreview(group: 'chat', name: 'Dismissible', size: Size(_chatFeeBannerPhoneWidth, 260))
Widget chatFeeBannerDismissible() => _chatFeeBannerHosted(
      amount: r'$0.75',
      trailing: ChatFeeBannerTrailing.dismiss,
    );

/// The `orderPicked` pill (Figma node 56560:1605) — and the state that breaks.
/// [_BannerOrderPicked] mounts an `OmdsPrimaryButton` whose `AnimatedContainer`
@JeebPreview(group: 'chat', name: 'Order picked pill', size: Size(_chatFeeBannerPhoneWidth, 360))
Widget chatFeeBannerOrderPickedPill() => _chatFeeBannerHosted(
      amount: r'$1.25',
      trailing: ChatFeeBannerTrailing.orderPicked,
    );

/// The same pill at 320 dp — the narrowest width the app ships to, and the
/// width at which the squeeze is visible without touching the text scale.
@JeebPreview(group: 'chat', name: 'Small phone 320dp', size: Size(_chatFeeBannerSmallPhoneWidth, 320))
Widget chatFeeBannerSmallPhoneOrderPicked() => _chatFeeBannerHosted(
      amount: r'$2.50',
      trailing: ChatFeeBannerTrailing.orderPicked,
      width: _chatFeeBannerSmallPhoneWidth,
    );

/// Longest plausible content: an LBP fee run through the app's own
/// [MoneyFormat] — `LBP 1,250,000.00`, four times the width of the `$0.5`
@JeebPreview(group: 'chat', name: 'Long LBP amount', size: Size(_chatFeeBannerPhoneWidth, 300))
Widget chatFeeBannerLongAmount() => _chatFeeBannerHosted(
      amount: MoneyFormat.format(1250000, currency: 'LBP'),
      trailing: ChatFeeBannerTrailing.dismiss,
    );

/// The production composition: the fee banner as the FIRST chrome child of
/// `_ChatBody`'s bounded header slot, above the thread.
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
