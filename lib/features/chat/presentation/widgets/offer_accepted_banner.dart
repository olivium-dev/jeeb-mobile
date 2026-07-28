import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';

/// Success banner that appears after the client accepts a Jeeber's offer.
///
/// Displayed above the message list when [ConversationPhase.accepted]
/// transitions in, and dismissable via the trailing [×].
///
/// When [onStartActiveDelivery] is non-null (the Jeeber variant of the thread),
/// a "Start delivery" CTA is rendered so the Jeeber can move from the
/// accepted-offer chat into the active-delivery screen. The callback is absent
/// (null) on the client variant, so the client never sees the CTA.
///
/// When [onTrackOrder] is non-null (the client variant, once the accept
/// surfaced a delivery id), a "Track order" CTA is rendered so the client can
/// move into live tracking. The callback is absent when no delivery id is
/// available, so the client never sees a dead CTA — this is the fix for the
/// accept→track dead-end (G5).
///
/// ## b02 chat-header redesign
///
/// This banner used to be a full-bleed slab of `secondaryContainer` — the deep
/// navy `#0B1351` — stacked directly under the pinned summary's full-bleed slab
/// of `primaryContainer`. Two saturated slabs, together consuming roughly the
/// top half of the screen with the keyboard open, is what the owner rejected.
///
/// What changed:
///
/// * **Role.** "Offer accepted" is a *success* event, so it now uses the
///   semantic success container ([JeebColorRoles.successContainer] /
///   `onSuccessContainer`) instead of the brand navy. That role is low-chroma
///   by construction in both themes and is already contrast-gated by
///   `test/core/theme/color_role_contrast_test.dart`. It also stops the banner
///   competing with the pinned summary: the summary is a neutral tonal surface,
///   the banner is a tinted success surface, and only the CTA is brand-coloured.
/// * **Height.** ONE row of 48 dp (the height of its own touch targets) plus
///   padding, instead of a text block with a full-width CTA stacked below it.
///   When a CTA is present the row is `icon · title · CTA · dismiss` and the
///   supporting sentence moves into the row's accessible name — the sentence is
///   context a screen-reader user needs and a sighted user already has (they
///   are looking at the thread). With no CTA there is room to render it, and it
///   is rendered.
/// * **Accessibility.** The dismiss control is a real 48×48 target (it was a
///   bare `GestureDetector` around a 16 dp icon), and the CTAs keep their
///   existing identifiers, keys, labels and callbacks **unchanged** —
///   `chat_start_active_delivery_cta` is the Jeeber's action on this screen
///   family and its behaviour is byte-for-byte the same.
/// * **Contrast.** The previous file asserted in a comment that
///   `onSecondaryContainer` (#777FC0) was "~3:1 on navy and fails WCAG 2.2 AA"
///   and used `onPrimary` instead. Measured, that pairing is **4.55:1** — it
///   passed, and the repo's own gate test asserts it does. The comment was
///   wrong; the workaround it justified is gone along with the navy.
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
    final roles = Theme.of(context).extension<JeebColorRoles>();
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final startDelivery = onStartActiveDelivery;
    final trackOrder = onTrackOrder;
    final hasCta = startDelivery != null || trackOrder != null;
    // `JeebColorRoles` is registered by `AppTheme`; a bare `MaterialApp` in a
    // widget test has no extension. Degrade to the M3 tertiary container rather
    // than crashing — never to the old navy slab.
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
                // A `Wrap`, not a `Row`: the message and the CTA share one line
                // when they fit and the CTA drops to a second line when they do
                // not (measured: text scale 1.3 on a 411 dp phone). A Row would
                // report a horizontal overflow instead.
                child: Wrap(
                  spacing: Spacing.xSmall,
                  runSpacing: Spacing.twoXSmall,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _OfferAcceptedText(
                      foreground: onContainer,
                      // With a CTA sharing the line there is no width for the
                      // supporting sentence; it rides on the semantics instead.
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

/// The title (+ supporting sentence when there is room for it).
///
/// The sentence is always in the accessible name, whether or not it is painted,
/// so a screen-reader user gets the same information in both layouts.
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

/// Trailing dismiss affordance — a real 48×48 target.
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

/// A banner CTA. Intrinsically sized (not full-width) so it shares the banner's
/// single row instead of adding a second one; 48 dp tall, so the row is exactly
/// one touch target high.
///
/// Behaviour is unchanged from the pre-redesign full-width button: same OMDS
/// primary button, same identifier, same [Key], same label, same callback.
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
      // `OmdsPrimaryButton` centres its content, and `Center` expands to its
      // constraints — dropped straight into the banner's `Wrap` the button
      // claimed the whole line (measured 343 dp wide). Tightening to the
      // intrinsic width makes it an inline CTA again, still clamped by the
      // incoming max so it cannot overflow.
      child: IntrinsicWidth(
        child: OmdsPrimaryButton(
          key: buttonKey,
          text: label,
          height: Sizes.fourXLarge,
          onTap: onTap,
          // Same content as the default `text` + `icon` layout, but with the
          // label allowed to ellipsise. `OmdsPrimaryButton`'s built-in content
          // uses an unbounded `Text`, which overflows once a large text scale
          // makes the label wider than the banner.
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
