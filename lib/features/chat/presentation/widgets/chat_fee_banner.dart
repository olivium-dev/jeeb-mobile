import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Trailing affordance rendered at the end of a [ChatFeeBanner].
enum ChatFeeBannerTrailing {
  /// No trailing control (the plain notice strip, Figma node 56539:906).
  none,

  /// A close (×) icon that dismisses the banner (nodes 56618:2751 / 56618:2852).
  dismiss,

  /// An inline "Order picked" action pill (node 56560:1605).
  orderPicked,
}

/// Jeeber-only balance-deduction notice strip shown above the chat thread.
///
/// A full-bleed periwinkle band (`colorScheme.onSecondaryContainer` — the
/// Figma `#777FC0` "On Secondary Container" role) with white body copy and an
/// optional trailing control. The fee amount is supplied pre-formatted by the
/// gateway fee config; the banner never computes currency itself.
///
/// OMDS has no flat notice-strip primitive (`OMDSProgressBanner` is a
/// progress-ring card, not this band), so the band is composed from OMDS
/// tokens per the design spec's sanctioned fallback — it is NOT an edit to
/// the shared OMDS library.
class ChatFeeBanner extends StatelessWidget {
  const ChatFeeBanner({
    super.key,
    required this.amount,
    this.trailing = ChatFeeBannerTrailing.none,
    this.onDismiss,
    this.onOrderPicked,
  });

  /// Pre-formatted fee amount (e.g. `"$0.5"`) from the gateway.
  final String amount;

  /// Which trailing control to render.
  final ChatFeeBannerTrailing trailing;

  /// Dismiss handler for [ChatFeeBannerTrailing.dismiss].
  final VoidCallback? onDismiss;

  /// Action handler for [ChatFeeBannerTrailing.orderPicked].
  final VoidCallback? onOrderPicked;

  static const Key bannerKey = Key('chat-fee-banner');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'chat_dm_fee_banner',
      label: l10n.chatBalanceDeductionA11y(amount),
      container: true,
      child: Container(
        key: bannerKey,
        width: double.infinity,
        color: colorScheme.onSecondaryContainer,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.xLarge,
          vertical: Spacing.medium,
        ),
        child: Row(
          children: [
            Expanded(child: _BannerText(amount: amount)),
            _trailingControl(),
          ],
        ),
      ),
    );
  }

  Widget _trailingControl() {
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

/// White, body-medium notice copy that wraps and scales without clipping.
class _BannerText extends StatelessWidget {
  const _BannerText({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Text(
      l10n.chatBalanceDeductionNotice(amount),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onPrimary,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.start,
    );
  }
}

/// Trailing close (×) icon button with a ≥48dp hit target.
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

/// Inline navy "Order picked" action pill (Figma node 56560:1605).
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
