import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../domain/delivery_chat_message.dart';
import 'chat_fee_banner.dart';
import 'chat_message_bubble.dart';
import '../../../../core/previews/jeeb_preview.dart';

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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/chat/offer_accepted_banner_preview_test.dart
// ===========================================================================

// Widget previews for [OfferAcceptedBanner] — run with
// `flutter widget-preview start`.
//
// The banner is a pure-props widget: three nullable callbacks and a name. It
// holds no state, reads no cubit and touches no repository, so these previews
// are network-free by construction rather than by the guard in
// [jeebPreviewHost].
//
// It paints NO data of its own — every string it shows comes from the ARB
// ("Offer accepted!", the supporting sentence, and the two CTA labels), and
// `jeeberName` is never rendered. So the axes that can actually break it are
// the CALLBACK COMBINATION it is handed (which decides whether the supporting
// sentence has room to be painted, and how many 48 dp CTAs share the row), the
// WIDTH it is given, and the text scale — the last of which every
// [JeebPreview] renders for free.
//
// Production placement is `chat_screen.dart` (`_ChatBody.header`), gated on
// `phase == accepted && !dismissed && winnerName != null`, where the winner
// name is read back off the last `offerAccepted` system notice in the thread
// (`ChatScreen._extractWinnerName`). Every preview therefore carries that
// notice under the banner: it is the message that gates the banner, it is
// where `jeeberName` comes from, and it is the only place the Jeeber's name
// actually reaches the screen.
//
// The two CTAs are role-scoped and mutually exclusive in the two hosts that
// exist today (`chat_detail_screen.dart:1732-1740` picks one on `isJeeber`):
//
//   * `onStartActiveDelivery` — Jeeber only, pushes the active-delivery route.
//   * `onTrackOrder` — client only, and null until the accept response has
//     surfaced a delivery id, so the CTA is never a dead end (the G5 fix
//     asserted in `test/features/chat/offer_accept_track_test.dart`).
//
// Fixture names ('Kamal Hajj', 'Rana', 'Nour', 'Ziad', 'Layla') are the ones
// the existing chat widget tests already use; each state gets its own so a
// preview cannot silently render a neighbour's fixture.

/// Frozen instant for every fixture, so the system notice's clock never drifts
/// between runs of the canvas.
final DateTime _offerAcceptedBannerFrozenAt = DateTime(2026, 6, 15, 9, 41);

/// The system notice that GATES the banner in production and supplies its
/// `jeeberName`. Without an `offerAccepted` message in the thread,
/// `_extractWinnerName` returns the counterpart name (or null) and
/// `showAcceptedBanner` is false — so no preview omits it.
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
///
/// [width] constrains the whole stack to a device width. The canvas box alone
/// cannot do that and neither can the render tests — `pumpPreview` uses the
/// default 800x600 viewport and ignores `JeebPreview.size` — so a preview that
/// wants to prove anything about phone-width layout has to clamp itself.
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
/// a button that goes nowhere.
///
/// It is also the ONLY state that paints the supporting sentence: `showBody` is
/// `!hasCta`, so with no CTA sharing the line there is room for
/// "You are now chatting with your Jeeber." In every other state below that
/// sentence exists only on the row's accessible name — which is the half of the
/// b02 redesign a screenshot review cannot see and a screen reader can.
///
/// Measured with the real bundled Inter at 390 dp: the band is 64 dp on one
/// line and 120 dp at the 200% rendering, where the sentence takes its full
/// two-line clamp. The box below fits the whole stack (banner + notice) at 2x.
@JeebPreview(group: 'chat', name: 'Client · no CTA yet', size: Size(390, 220))
Widget offerAcceptedBannerClientNoCta() => _offerAcceptedBannerHosted(jeeberName: 'Kamal Hajj');

/// The Jeeber leg, in its real chrome: the balance-deduction band sits directly
/// on top of this banner (`_ChatBody.header` emits `feeNotice` first), so two
/// full-bleed bands share an edge.
///
/// This is the pairing the b02 redesign is about. The fee band is still the
/// saturated navy `secondaryContainer`; the banner underneath is now the
/// low-chroma success container, which is what stops the top of the thread
/// reading as one solid slab. If this preview ever shows two saturated bands
/// again, the role swap has been reverted.
///
/// The tallest state of the five: measured 156 dp of chrome at 1x and 316 dp at
/// the 200% rendering, because both bands grow independently.
@JeebPreview(group: 'chat', name: 'Jeeber · start delivery', size: Size(390, 340))
Widget offerAcceptedBannerJeeberStartDelivery() => _offerAcceptedBannerHosted(
      jeeberName: 'Rana',
      startDelivery: true,
      chrome: const <Widget>[ChatFeeBanner(amount: r'$0.50')],
    );

/// The client leg once the accept response surfaced a delivery id (G5): the
/// row becomes `icon · title · Track my order · ×`, and the supporting sentence
/// drops out of the paint to make room.
///
/// Worth looking at beside the state above: both are one 48 dp row (a 64 dp
/// band at 390 dp), but this one is the customer's only in-chat route into live
/// tracking, so its label is the one that has to survive the 200% rendering. It
/// is also the longest of the two CTA labels — 262 dp at 200%, against 239 dp
/// for "Start delivery" — which is why the small-phone state below is this CTA
/// and not the Jeeber's.
@JeebPreview(group: 'chat', name: 'Client · track order', size: Size(390, 200))
Widget offerAcceptedBannerClientTrackOrder() =>
    _offerAcceptedBannerHosted(jeeberName: 'Nour', trackOrder: true);

/// Small-phone width (320 dp), the narrowest width the app ships to, carrying
/// the longer of the two CTAs.
///
/// This is the width the `Wrap` in the banner exists for. The code comment
/// records the CTA dropping to a second line at text scale 1.3 on a 411 dp
/// phone; at 320 dp it happens at 1.0x already — measured, the band is 88 dp
/// here against 64 dp at 390 dp, i.e. two runs instead of one. The degradation
/// is a WRAP and not a `RenderFlex overflowed` stripe, and because the preview
/// clamps its own width the render test can assert that rather than trusting
/// the canvas.
///
/// It is also where the 200% rendering bites: the padding leaves each Wrap
/// child at most 320 − 16 − 4 − 48 = 252 dp, and this CTA wants 262 dp at 200%,
/// so the label ellipsises. That is the one thing to look at in this card.
@JeebPreview(group: 'chat', name: 'Small phone 320dp', size: Size(320, 220))
Widget offerAcceptedBannerSmallPhone() => _offerAcceptedBannerHosted(
      jeeberName: 'Ziad',
      trackOrder: true,
      width: 320,
    );

/// The widest the row can get: icon, title, BOTH CTAs and the dismiss target.
///
/// Today's two hosts pick one CTA on role, so this combination is not reachable
/// through them — but `ChatScreen` forwards both fields to the banner blindly,
/// and the banner's own contract accepts both, so it must degrade rather than
/// overflow. It is also the fastest regression guard for the `IntrinsicWidth`
/// around each CTA: `OmdsPrimaryButton` centres its content and claimed the
/// whole line (measured 343 dp) before that wrapper was added, so if it comes
/// off, this is the state where two full-width buttons collide first.
///
/// Measured at 390 dp: 116 dp at 1x and 160 dp at the 200% rendering — the CTAs
/// take a run of their own and the band roughly doubles, which is the correct
/// degradation, not an overflow.
@JeebPreview(group: 'chat', name: 'Both CTAs', size: Size(390, 240))
Widget offerAcceptedBannerBothCtas() => _offerAcceptedBannerHosted(
      jeeberName: 'Layla',
      startDelivery: true,
      trackOrder: true,
    );
