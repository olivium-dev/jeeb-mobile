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
///
/// When [onTrackOrder] is non-null (the client variant, once the accept
/// surfaced a delivery id), a primary "Track order" CTA is rendered below the
/// strip so the client can move from the accepted-offer chat into live
/// tracking. The callback is absent (null) when no delivery id is available,
/// so the client never sees a dead CTA — this is the fix for the accept→track
/// dead-end (G5).
class OfferAcceptedBanner extends StatelessWidget {
  const OfferAcceptedBanner({
    super.key,
    required this.jeeberName,
    this.onDismiss,
    this.onStartActiveDelivery,
    this.onTrackOrder,
  });

  final String jeeberName;
  final VoidCallback? onDismiss;

  /// Jeeber-only entry point into the active-delivery screen. Null on the
  /// client variant (hides the CTA).
  final VoidCallback? onStartActiveDelivery;

  /// Client-only entry point into live tracking. Null until the accept
  /// response surfaced a delivery id (hides the CTA so it is never a dead end).
  final VoidCallback? onTrackOrder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final startDelivery = onStartActiveDelivery;
    final trackOrder = onTrackOrder;
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
          if (trackOrder != null) ...[
            const SizedBox(height: Spacing.small),
            _TrackOrderCta(onTap: trackOrder),
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
          // The banner background is the navy `secondaryContainer`; use the
          // high-contrast on-navy token (`onPrimary`, white) so the icon is
          // legible. `onSecondaryContainer` (#777FC0) is ~3:1 on navy and
          // fails WCAG 2.2 AA.
          color: colorScheme.onPrimary,
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
            // High-contrast on-navy token (white); the navy
            // `secondaryContainer` background makes `onSecondaryContainer`
            // (#777FC0) fail WCAG 2.2 AA.
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          l10n.chatOfferAcceptedBannerBody,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onPrimary,
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
      identifier: 'offer_accepted_dismiss_cta',
      button: true,
      container: true,
      label: AppLocalizations.of(context).commonDismiss,
      child: GestureDetector(
        onTap: onDismiss,
        child: Icon(
          Icons.close,
          size: Sizes.medium,
          // High-contrast on-navy token (white) so the dismiss affordance is
          // legible on the navy `secondaryContainer` banner.
          color: colorScheme.onPrimary,
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

/// Client-only "Track order" CTA that opens the live-tracking screen for the
/// accepted delivery.
///
/// Carries a stable Semantics identifier (`offer_accepted_track_cta`) + Key so
/// Maestro/QA can target it in the offer-accepted → live-tracking flow. Reuses
/// the existing `homeTrackOrderCta` localization ("Track my order" / "تتبّع
/// طلبي") rather than introducing a new key.
class _TrackOrderCta extends StatelessWidget {
  const _TrackOrderCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'offer_accepted_track_cta',
      button: true,
      child: OmdsPrimaryButton(
        key: const Key('offer-accepted-track-cta'),
        text: l10n.homeTrackOrderCta,
        icon: const Icon(Icons.location_on_outlined),
        onTap: onTap,
      ),
    );
  }
}
