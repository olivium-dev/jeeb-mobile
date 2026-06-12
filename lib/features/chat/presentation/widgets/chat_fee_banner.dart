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
    final colorScheme = Theme.of(context).colorScheme;
    // NB: NOT a merging container. A `Semantics(container: true, label: …)`
    // here would absorb the descendant "Order picked" pill / dismiss button,
    // hiding their ids from the accessibility tree (the Maestro selector gap
    // the prior round flagged). The host id stays addressable for the flow,
    // while the notice text carries the a11y label and each trailing control
    // keeps its own independently-targetable button node (mirrors the QA-B1
    // confirm-sheet fix).
    return Semantics(
      identifier: 'chat_dm_fee_banner',
      explicitChildNodes: true,
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

/// Trailing slot of the fee banner — nothing, a dismiss (×), or the
/// "Order picked" action pill, depending on [trailing].
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

/// White, body-medium notice copy that wraps and scales without clipping.
class _BannerText extends StatelessWidget {
  const _BannerText({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // The notice copy carries the banner's a11y label (the wrapper no longer
    // merges, so the descriptive text lives on this non-merging leaf node).
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

/// Inline navy "Order picked" action pill (Figma node 56560:1605).
class _BannerOrderPicked extends StatelessWidget {
  const _BannerOrderPicked({required this.onOrderPicked});

  final VoidCallback? onOrderPicked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    // Independently-targetable button node: `button: true` + explicit `label`
    // + `container: true` give the pill its OWN semantics node carrying the
    // stable id and a tap action, so Maestro/TalkBack can find and drive it
    // (the banner wrapper no longer merges it away — QA-B1-class fix).
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
