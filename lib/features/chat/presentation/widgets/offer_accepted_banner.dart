import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../domain/delivery_chat_message.dart';
import 'chat_fee_banner.dart';
import 'chat_message_bubble.dart';
import '../../../../core/previews/jeeb_preview.dart';

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [OfferAcceptedBanner] — run with

/// Frozen instant for every fixture, so the system notice's clock never drifts
/// between runs of the canvas.
final DateTime _offerAcceptedBannerFrozenAt = DateTime(2026, 6, 15, 9, 41);

/// The system notice that GATES the banner in production and supplies its
/// `jeeberName`. Without an `offerAccepted` message in the thread,
DeliveryChatMessage _offerAcceptedBannerAcceptedNotice(String jeeberName) =>
    DeliveryChatMessage.offerAccepted(
      id: 'sys-accepted-$jeeberName',
      sentAt: _offerAcceptedBannerFrozenAt,
      payload: SystemOfferPayload(
        offerId: 'offer-$jeeberName',
        jeeberId: 'j-$jeeberName',
        jeeberName: jeeberName,
      ),
    );

/// Builds the banner in its production stacking order: chrome above, the
/// gating system notice below.
Widget _offerAcceptedBannerHosted({
  required String jeeberName,
  bool dismissable = true,
  bool startDelivery = false,
  bool trackOrder = false,
  List<Widget> chrome = const <Widget>[],
  double? width,
}) {
  final Widget body = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      ...chrome,
      OfferAcceptedBanner(
        jeeberName: jeeberName,
        onDismiss: dismissable ? () {} : null,
        onStartActiveDelivery: startDelivery ? () {} : null,
        onTrackOrder: trackOrder ? () {} : null,
      ),
      ChatMessageBubble(message: _offerAcceptedBannerAcceptedNotice(jeeberName)),
    ],
  );
  if (width == null) return body;
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(width: width, child: body),
  );
}

/// The client's first reading of an accepted offer: no delivery id yet, so no
/// CTA — the state the G5 fix deliberately leaves CTA-less rather than shipping
@JeebPreview(group: 'chat', name: 'Client · no CTA yet', size: Size(390, 220))
Widget offerAcceptedBannerClientNoCta() => _offerAcceptedBannerHosted(jeeberName: 'Kamal Hajj');

/// The Jeeber leg, in its real chrome: the balance-deduction band sits directly
/// on top of this banner (`_ChatBody.header` emits `feeNotice` first), so two
@JeebPreview(group: 'chat', name: 'Jeeber · start delivery', size: Size(390, 340))
Widget offerAcceptedBannerJeeberStartDelivery() => _offerAcceptedBannerHosted(
      jeeberName: 'Rana',
      startDelivery: true,
      chrome: const <Widget>[ChatFeeBanner(amount: r'$0.50')],
    );

/// The client leg once the accept response surfaced a delivery id (G5): the
/// row becomes `icon · title · Track my order · ×`, and the supporting sentence
@JeebPreview(group: 'chat', name: 'Client · track order', size: Size(390, 200))
Widget offerAcceptedBannerClientTrackOrder() =>
    _offerAcceptedBannerHosted(jeeberName: 'Nour', trackOrder: true);

/// Small-phone width (320 dp), the narrowest width the app ships to, carrying
/// the longer of the two CTAs.
@JeebPreview(group: 'chat', name: 'Small phone 320dp', size: Size(320, 220))
Widget offerAcceptedBannerSmallPhone() => _offerAcceptedBannerHosted(
      jeeberName: 'Ziad',
      trackOrder: true,
      width: 320,
    );

/// The widest the row can get: icon, title, BOTH CTAs and the dismiss target.
/// Today's two hosts pick one CTA on role, so this combination is not reachable
@JeebPreview(group: 'chat', name: 'Both CTAs', size: Size(390, 240))
Widget offerAcceptedBannerBothCtas() => _offerAcceptedBannerHosted(
      jeeberName: 'Layla',
      startDelivery: true,
      trackOrder: true,
    );
