import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';

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

  final VoidCallback? onStartActiveDelivery;

  final VoidCallback? onTrackOrder;

  @override
  Widget build(BuildContext context) {
    final roles = Theme.of(context).extension<JeebColorRoles>();
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final startDelivery = onStartActiveDelivery;
    final trackOrder = onTrackOrder;
    final hasCta = startDelivery != null || trackOrder != null;
    final container = roles?.successContainer ?? colors.tertiaryContainer;
    final onContainer = roles?.onSuccessContainer ?? colors.onTertiaryContainer;
    final divider = roles?.success ?? colors.outline;

    return Semantics(
      identifier: 'offer_accepted_banner',
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        key: const Key('offer-accepted-banner'),
        decoration: BoxDecoration(
          color: container,
          border: Border(
            bottom: BorderSide(color: divider, width: UIConstants.dividerWidth),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.medium,
            Spacing.xSmall,
            Spacing.twoXSmall,
            Spacing.xSmall,
          ),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: Spacing.xSmall,
                  runSpacing: Spacing.twoXSmall,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _OfferAcceptedText(
                      foreground: onContainer,
                      showBody: !hasCta,
                    ),
                    if (startDelivery != null)
                      _BannerCta(
                        identifier: 'chat_start_active_delivery_cta',
                        buttonKey: const Key('chat-start-active-delivery-cta'),
                        label: l10n.chatStartActiveDeliveryButton,
                        icon: Icons.local_shipping_outlined,
                        onTap: startDelivery,
                      ),
                    if (trackOrder != null)
                      _BannerCta(
                        identifier: 'offer_accepted_track_cta',
                        buttonKey: const Key('offer-accepted-track-cta'),
                        label: l10n.homeTrackOrderCta,
                        icon: Icons.location_on_outlined,
                        onTap: trackOrder,
                      ),
                  ],
                ),
              ),
              if (onDismiss != null)
                _OfferAcceptedDismiss(
                  onDismiss: onDismiss!,
                  foreground: onContainer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferAcceptedText extends StatelessWidget {
  const _OfferAcceptedText({required this.foreground, required this.showBody});

  final Color foreground;
  final bool showBody;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'offer_accepted_banner_text',
      container: true,
      label: '${l10n.chatOfferAcceptedBannerTitle} '
          '${l10n.chatOfferAcceptedBannerBody}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: foreground,
              size: Sizes.large,
            ),
            const SizedBox(width: Spacing.xSmall),
            Flexible(child: _TitleAndBody(foreground: foreground, showBody: showBody)),
          ],
        ),
      ),
    );
  }
}

class _TitleAndBody extends StatelessWidget {
  const _TitleAndBody({required this.foreground, required this.showBody});

  final Color foreground;
  final bool showBody;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.chatOfferAcceptedBannerTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelLarge?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (showBody)
          Text(
            l10n.chatOfferAcceptedBannerBody,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: foreground),
          ),
      ],
    );
  }
}

class _OfferAcceptedDismiss extends StatelessWidget {
  const _OfferAcceptedDismiss({
    required this.onDismiss,
    required this.foreground,
  });

  final VoidCallback onDismiss;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'offer_accepted_dismiss_cta',
      button: true,
      container: true,
      label: AppLocalizations.of(context).commonDismiss,
      child: InkWell(
        onTap: onDismiss,
        borderRadius: OmdsBorderRadius.pill,
        child: SizedBox(
          width: Sizes.fourXLarge,
          height: Sizes.fourXLarge,
          child: Icon(Icons.close, size: Sizes.large, color: foreground),
        ),
      ),
    );
  }
}

class _BannerCta extends StatelessWidget {
  const _BannerCta({
    required this.identifier,
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String identifier;
  final Key buttonKey;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: identifier,
      button: true,
      child: IntrinsicWidth(
        child: OmdsPrimaryButton(
          key: buttonKey,
          text: label,
          height: Sizes.fourXLarge,
          onTap: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: Sizes.medium,
                color: theme.colorScheme.onPrimary,
              ),
              const SizedBox(width: Spacing.xSmall),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
