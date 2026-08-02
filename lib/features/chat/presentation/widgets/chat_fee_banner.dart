import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

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
