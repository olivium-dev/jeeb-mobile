import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_system_chip.dart';
import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../domain/delivery_chat_message.dart';
import 'chat_fee_banner.dart';
import 'chat_message_bubble.dart';
import '../../../../core/previews/jeeb_preview.dart';

/// MIDNIGHT (Pattern D — demoted). This used to be a full-bleed **green**
/// success band: an off-palette `successContainer` slab that the board never
/// draws and that repeated a fact the thread already states as its
/// `Offer accepted · 9:12` timeline chip.
///
/// It is now that same quiet chip, centred over the thread, with the CTA and
/// the dismiss target kept beside it — because the CTA is the Jeeber's primary
/// action during a live delivery and the frozen `offer_accepted_*` identifiers
/// (plus `Key('offer-accepted-banner')`) are Maestro-pinned, so the chrome is
/// demoted rather than deleted.
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
    final l10n = AppLocalizations.of(context);
    final startDelivery = onStartActiveDelivery;
    final trackOrder = onTrackOrder;

    return Semantics(
      identifier: 'offer_accepted_banner',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        key: const Key('offer-accepted-banner'),
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.xLarge,
          Spacing.xSmall,
          Spacing.twoXSmall,
          Spacing.xSmall,
        ),
        child: Row(
          children: [
            Expanded(
              // With no action beside it the chip is the tile's own centred
              // timeline note; with one it shares the run and sits inline.
              child: startDelivery == null && trackOrder == null
                  ? const _OfferAcceptedText(center: true)
                  : Wrap(
                      spacing: Spacing.xSmall,
                      runSpacing: Spacing.twoXSmall,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const _OfferAcceptedText(),
                        if (startDelivery != null)
                          _BannerCta(
                            identifier: 'chat_start_active_delivery_cta',
                            buttonKey: const Key(
                              'chat-start-active-delivery-cta',
                            ),
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
            if (onDismiss != null) _OfferAcceptedDismiss(onDismiss: onDismiss!),
          ],
        ),
      ),
    );
  }
}

/// The settled fact, in the thread's own timeline-chip language.
class _OfferAcceptedText extends StatelessWidget {
  const _OfferAcceptedText({this.center = false});

  /// True centres the chip in its slot; false lets the Wrap position it (the
  /// kit's own `Align` would otherwise eat the whole run).
  final bool center;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // The supporting sentence is no longer PAINTED — a timeline chip is one
    // line by construction — but it is still announced, so nothing is lost to
    // a screen reader.
    return Semantics(
      identifier: 'offer_accepted_banner_text',
      container: true,
      label:
          '${l10n.chatOfferAcceptedBannerTitle} '
          '${l10n.chatOfferAcceptedBannerBody}',
      child: ExcludeSemantics(
        child: JeebSystemChip.filled(
          label: l10n.chatOfferAcceptedBannerTitle,
          center: center,
        ),
      ),
    );
  }
}

class _OfferAcceptedDismiss extends StatelessWidget {
  const _OfferAcceptedDismiss({required this.onDismiss});

  final VoidCallback onDismiss;

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
          child: Icon(
            Icons.close,
            size: Sizes.large,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}

/// The one action the demoted chip keeps beside it — a navy kit pill, not the
/// orange CTA: R20's orange budget is spent on the outgoing bubbles and the
/// composer's send circle.
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
    // `expand: false` only drops the infinite width; the pill's inner `Center`
    // still fills a loose slot, so the intrinsic pass is what keeps it a pill.
    return IntrinsicWidth(
      child: JeebCtaButton.primary(
        key: buttonKey,
        label: label,
        leadingIcon: icon,
        onTap: onTap,
        identifier: identifier,
        height: Sizes.fourXLarge,
        labelStyle: context.jeebText.bodySmall,
        expand: false,
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
      ChatMessageBubble(
        message: _offerAcceptedBannerAcceptedNotice(jeeberName),
      ),
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
Widget offerAcceptedBannerClientNoCta() =>
    _offerAcceptedBannerHosted(jeeberName: 'Kamal Hajj');

/// The Jeeber leg, in its real chrome: the balance-deduction band sits directly
/// on top of this banner (`_ChatBody.header` emits `feeNotice` first), so two
@JeebPreview(
  group: 'chat',
  name: 'Jeeber · start delivery',
  size: Size(390, 340),
)
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
