import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Success banner that appears after the client accepts a Jeeber's offer.
///
/// Displayed at the top of the message list when [ConversationPhase.accepted]
/// transitions in. Shows a green confirmation strip with title + body text.
/// The banner is dismissable via the trailing [×] icon so it doesn't
/// permanently occupy screen real estate.
///
/// When [onStartActiveDelivery] is non-null (the Jeeber variant of the
/// thread), a primary "Start delivery" CTA is rendered below the strip so the
/// Jeeber can move from the accepted-offer chat into the active-delivery
/// screen. The callback is absent (null) on the client variant, so the client
/// never sees the CTA.
class OfferAcceptedBanner extends StatelessWidget {
  const OfferAcceptedBanner({
    super.key,
    required this.jeeberName,
    this.onDismiss,
    this.onStartActiveDelivery,
  });

  final String jeeberName;
  final VoidCallback? onDismiss;

  /// Jeeber-only entry point into the active-delivery screen. Null on the
  /// client variant (hides the CTA).
  final VoidCallback? onStartActiveDelivery;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final startDelivery = onStartActiveDelivery;
    return Container(
      key: const Key('offer-accepted-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      color: colorScheme.secondaryContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _OfferAcceptedRow(onDismiss: onDismiss),
          if (startDelivery != null) ...[
            const SizedBox(height: Spacing.small),
            _StartActiveDeliveryCta(onTap: startDelivery),
          ],
        ],
      ),
    );
  }
}

/// The confirmation strip: success icon, title + body, optional dismiss icon.
class _OfferAcceptedRow extends StatelessWidget {
  const _OfferAcceptedRow({this.onDismiss});

  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          Icons.check_circle_outline,
          color: colorScheme.onSecondaryContainer,
          size: Sizes.large,
        ),
        const SizedBox(width: Spacing.small),
        const Expanded(child: _OfferAcceptedText()),
        if (onDismiss != null) _OfferAcceptedDismiss(onDismiss: onDismiss!),
      ],
    );
  }
}

/// The title + body text column of the accepted banner.
class _OfferAcceptedText extends StatelessWidget {
  const _OfferAcceptedText();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.chatOfferAcceptedBannerTitle,
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          l10n.chatOfferAcceptedBannerBody,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSecondaryContainer,
          ),
        ),
      ],
    );
  }
}

/// Trailing dismiss affordance for the accepted banner.
class _OfferAcceptedDismiss extends StatelessWidget {
  const _OfferAcceptedDismiss({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Dismiss',
      child: GestureDetector(
        onTap: onDismiss,
        child: Icon(
          Icons.close,
          size: Sizes.medium,
          color: colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Jeeber-only "Start delivery" CTA that opens the active-delivery screen.
///
/// Carries a stable Semantics identifier (`chat_start_active_delivery_cta`)
/// so Maestro can target it in the offer-accepted → active-delivery flow.
class _StartActiveDeliveryCta extends StatelessWidget {
  const _StartActiveDeliveryCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'chat_start_active_delivery_cta',
      button: true,
      child: OmdsPrimaryButton(
        key: const Key('chat-start-active-delivery-cta'),
        text: l10n.chatStartActiveDeliveryButton,
        icon: const Icon(Icons.local_shipping_outlined),
        onTap: onTap,
      ),
    );
  }
}
