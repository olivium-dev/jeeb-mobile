import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../cubit/request_feed_state.dart';
import '../data/request_feed_models.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

/// OMDS-styled card rendering one [DeliveryRequest] in the Jeeber feed.
///
/// The card is intentionally composed from OMDS primitives (Spacing, Sizes,
/// OmdsBorderRadius, OmdsPrimaryButton) rather than the salehly-lineage
/// `OmdsRequestCard`, because that card's fixed avatar/title/body shape
/// doesn't match the pickup/dropoff/tier/distance/earnings layout Jeeb
/// needs. Per JEEB-BOUNDARIES.md F8, raw Material widgets are still
/// forbidden — Material.Card and ColorScheme/TextTheme accesses are
/// theme-mediated and explicitly allowed by omds_theme.dart.
class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    required this.actionStatus,
    required this.secondsRemaining,
    required this.onAccept,
    required this.onDecline,
  });

  final DeliveryRequest request;
  final RequestActionStatus actionStatus;

  /// Seconds left on a server-supplied per-card deadline. `null` hides the
  /// countdown and leaves actions enabled until the snapshot drops the row.
  final int? secondsRemaining;

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: Key('requestFeed.card.${request.id}'),
      margin: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: _decoration(colorScheme),
      child: _CardBody(
        request: request,
        actionStatus: actionStatus,
        secondsRemaining: secondsRemaining,
        onAccept: onAccept,
        onDecline: onDecline,
      ),
    );
  }

  BoxDecoration _decoration(ColorScheme colorScheme) {
    return BoxDecoration(
      color: colorScheme.surface,
      borderRadius: OmdsBorderRadius.medium,
      border: Border.all(
        color: colorScheme.outlineVariant.withValues(
          alpha: UIConstants.opacityDisabled,
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.request,
    required this.actionStatus,
    required this.secondsRemaining,
    required this.onAccept,
    required this.onDecline,
  });

  final DeliveryRequest request;
  final RequestActionStatus actionStatus;
  final int? secondsRemaining;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  bool get _actionsLocked =>
      actionStatus != RequestActionStatus.idle ||
      (secondsRemaining != null && secondsRemaining! <= 0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (request.tier != null || secondsRemaining != null) ...[
          _CardHeader(tier: request.tier, secondsRemaining: secondsRemaining),
          const SizedBox(height: Spacing.medium),
        ],
        _CardSections(
          request: request,
          actionStatus: actionStatus,
          enabled: !_actionsLocked,
          onAccept: _actionsLocked ? () {} : onAccept,
          onDecline: _actionsLocked ? () {} : onDecline,
        ),
      ],
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.tier, required this.secondsRemaining});

  final JeeberRequestTier? tier;
  final int? secondsRemaining;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return _Header(
      tier: tier,
      secondsRemaining: secondsRemaining,
      colorScheme: colorScheme,
      textTheme: textTheme,
      l10n: l10n,
    );
  }
}

class _CardSections extends StatelessWidget {
  const _CardSections({
    required this.request,
    required this.actionStatus,
    required this.enabled,
    required this.onAccept,
    required this.onDecline,
  });

  final DeliveryRequest request;
  final RequestActionStatus actionStatus;
  final bool enabled;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Locations(request: request, l10n: l10n),
        const SizedBox(height: Spacing.medium),
        _Metadata(request: request, l10n: l10n),
        const SizedBox(height: Spacing.medium),
        _CardActions(
          request: request,
          actionStatus: actionStatus,
          onAccept: onAccept,
          onDecline: onDecline,
          enabled: enabled,
          l10n: l10n,
        ),
      ],
    );
  }
}

class _Locations extends StatelessWidget {
  const _Locations({required this.request, required this.l10n});

  final DeliveryRequest request;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LocationRow(
          icon: Icons.adjust,
          label: l10n.requestFeedPickupLabel,
          value: request.pickup.label,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(height: Spacing.xSmall),
        _LocationRow(
          icon: Icons.location_on_outlined,
          label: l10n.requestFeedDropoffLabel,
          value: request.dropoff.label,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
      ],
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.request, required this.l10n});

  final DeliveryRequest request;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return _MetadataRow(
      distanceLabel: l10n.requestFeedDistance(
        request.estimatedDistanceKm.toStringAsFixed(1),
      ),
      earningsLabel: l10n.requestFeedEarnings(
        request.potentialEarnings.toStringAsFixed(2),
        request.currency,
      ),
      colorScheme: colorScheme,
      textTheme: textTheme,
    );
  }
}

class _CardActions extends StatelessWidget {
  const _CardActions({
    required this.request,
    required this.actionStatus,
    required this.onAccept,
    required this.onDecline,
    required this.enabled,
    required this.l10n,
  });

  final DeliveryRequest request;
  final RequestActionStatus actionStatus;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool enabled;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isAccepting = actionStatus == RequestActionStatus.accepting;
    final isDeclining = actionStatus == RequestActionStatus.declining;
    return _Actions(
      acceptLabel: isAccepting ? l10n.requestFeedAccepting : l10n.requestFeedAccept,
      declineLabel:
          isDeclining ? l10n.requestFeedDeclining : l10n.requestFeedDecline,
      onAccept: onAccept,
      onDecline: onDecline,
      acceptEnabled: enabled,
      declineEnabled: enabled,
      requestId: request.id,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.tier,
    required this.secondsRemaining,
    required this.colorScheme,
    required this.textTheme,
    required this.l10n,
  });

  final JeeberRequestTier? tier;
  final int? secondsRemaining;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (tier case final knownTier?)
          _TierChip(
            tier: knownTier,
            colorScheme: colorScheme,
            textTheme: textTheme,
            l10n: l10n,
          ),
        if (tier != null && secondsRemaining != null) const Spacer(),
        if (secondsRemaining case final seconds?)
          _CountdownBadge(
            secondsRemaining: seconds,
            colorScheme: colorScheme,
            textTheme: textTheme,
            l10n: l10n,
          ),
      ],
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({
    required this.tier,
    required this.colorScheme,
    required this.textTheme,
    required this.l10n,
  });

  final JeeberRequestTier tier;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  String _label() => switch (tier) {
        JeeberRequestTier.light => l10n.requestFeedTierLight,
        JeeberRequestTier.standard => l10n.requestFeedTierStandard,
        JeeberRequestTier.bulk => l10n.requestFeedTierBulk,
        JeeberRequestTier.flash => l10n.requestFeedTierFlash,
      };

  Color _background() => switch (tier) {
        JeeberRequestTier.light => colorScheme.tertiaryContainer,
        JeeberRequestTier.standard => colorScheme.secondaryContainer,
        JeeberRequestTier.bulk => colorScheme.primaryContainer,
        JeeberRequestTier.flash => colorScheme.primaryContainer,
      };

  Color _foreground() => switch (tier) {
        JeeberRequestTier.light => colorScheme.onTertiaryContainer,
        JeeberRequestTier.standard => colorScheme.onSecondaryContainer,
        JeeberRequestTier.bulk => colorScheme.onPrimaryContainer,
        JeeberRequestTier.flash => colorScheme.onPrimaryContainer,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.twoXSmall,
      ),
      decoration: BoxDecoration(
        color: _background(),
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Text(
        _label(),
        key: const Key('requestFeed.card.tierChip'),
        style: textTheme.labelMedium?.copyWith(
          color: _foreground(),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CountdownBadge extends StatelessWidget {
  const _CountdownBadge({
    required this.secondsRemaining,
    required this.colorScheme,
    required this.textTheme,
    required this.l10n,
  });

  final int secondsRemaining;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.timer_outlined,
          size: Sizes.medium,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Text(
          l10n.requestFeedExpiresIn(secondsRemaining),
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: Sizes.large, color: colorScheme.primary),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: _LocationText(
            label: label,
            value: value,
            colorScheme: colorScheme,
            textTheme: textTheme,
          ),
        ),
      ],
    );
  }
}

class _LocationText extends StatelessWidget {
  const _LocationText({
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  final String label;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.distanceLabel,
    required this.earningsLabel,
    required this.colorScheme,
    required this.textTheme,
  });

  final String distanceLabel;
  final String earningsLabel;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _DistanceBadge(
          label: distanceLabel,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
        const SizedBox(width: Spacing.medium),
        _EarningsBadge(
          label: earningsLabel,
          colorScheme: colorScheme,
          textTheme: textTheme,
        ),
      ],
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  const _DistanceBadge({
    required this.label,
    required this.colorScheme,
    required this.textTheme,
  });

  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.route_outlined,
          size: Sizes.medium,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Text(
          label,
          key: const Key('requestFeed.card.distance'),
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _EarningsBadge extends StatelessWidget {
  const _EarningsBadge({
    required this.label,
    required this.colorScheme,
    required this.textTheme,
  });

  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.payments_outlined,
          size: Sizes.medium,
          color: colorScheme.primary,
        ),
        const SizedBox(width: Spacing.twoXSmall),
        Text(
          label,
          key: const Key('requestFeed.card.earnings'),
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.acceptLabel,
    required this.declineLabel,
    required this.onAccept,
    required this.onDecline,
    required this.acceptEnabled,
    required this.declineEnabled,
    required this.requestId,
  });

  final String acceptLabel;
  final String declineLabel;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool acceptEnabled;
  final bool declineEnabled;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DeclineButton(
            label: declineLabel,
            enabled: declineEnabled,
            onTap: onDecline,
            requestId: requestId,
          ),
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: _AcceptButton(
            label: acceptLabel,
            enabled: acceptEnabled,
            onTap: onAccept,
            requestId: requestId,
          ),
        ),
      ],
    );
  }
}

class _DeclineButton extends StatelessWidget {
  const _DeclineButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.requestId,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'request_feed_decline_$requestId',
      container: true,
      button: true,
      child: OmdsPrimaryButton(
        key: Key('requestFeed.card.decline.$requestId'),
        text: label,
        variant: OmdsButtonVariant.outlined,
        isEnabled: enabled,
        onTap: onTap,
      ),
    );
  }
}

class _AcceptButton extends StatelessWidget {
  const _AcceptButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.requestId,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'request_feed_accept_$requestId',
      container: true,
      button: true,
      child: OmdsPrimaryButton(
        key: Key('requestFeed.card.accept.$requestId'),
        text: label,
        isEnabled: enabled,
        onTap: onTap,
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
// Render tests: test/previews/jeeber_request_feed/request_card_preview_test.dart
// ===========================================================================

// Widget previews for [RequestCard] — run with
// `flutter widget-preview start`.
//
// [RequestCard] is a pure view over one [DeliveryRequest] plus two scalars the
// feed screen derives per frame: the request's [RequestActionStatus] and
// `secondsRemaining`. No cubit, no repository, no image fetch — every fixture
// below is a plain value object and both callbacks are no-ops, so these
// previews are network-free by construction, not merely by the guard in
// [jeebPreviewHost].
//
// Fixture values reuse `test/request_feed_cubit_test.dart` (`_req`: 3.4 km /
// 5.2 USD / Standard) and `DevJeeberFeedFixtures` ("Hamra, Beirut" →
// "Achrafieh, Beirut"), so the canvas and the existing tests describe the same
// card.
//
// ## What decides the card's shape
//
// Two independent gates, neither of them a property the caller passes
// directly:
//
// ```dart
// // _CardBody: the header row exists ONLY if one of these is non-null
// if (request.tier != null || secondsRemaining != null) ...
//
// // _CardBody: actions go dead on EITHER condition
// _actionsLocked => actionStatus != idle || (secondsRemaining ?? 1) <= 0
// ```
//
// The second is the G3 expired-linger rule made visual: at `0` the card stays
// on screen with its countdown reading "Expires in 0s" and both buttons inert,
// rather than vanishing under the Jeeber's thumb. Previews exist for both
// halves of each gate because nothing about the widget's own props announces
// them.
//
// ## Read the canvas knowing this: three things break at real phone width
//
// All figures measured at 390 pt, not guessed. The content column is
// `390 − 32` (margin) `− 2` (border) `− 32` (padding) **= 324 pt**, and that
// is the box every row below has to fit into.
//
// **1. The header `Row` (`request_card.dart:278`) overflows in Arabic at
// normal text scale.** Tier chip, `Spacer`, countdown badge — and *neither*
// child is flexible, so when the Arabic strings run long there is nothing to
// shrink and the countdown is clipped against the trailing edge. Only 9 pt,
// but it is a stripe on the default AR reading of a card the Jeeber sees
// dozens of times an hour.
//
// **2. The metadata `Row` (`request_card.dart:477`) has no flex either.** Two
// `MainAxisSize.min` badges and a fixed 16 pt gap; nothing ellipsizes. A
// six-figure LBP amount pushes it to 384 pt against 324 — 60 pt lost, in
// English, at normal text scale (see [requestCardLongContent]).
//
// **3. The action labels have 124 pt each and no `maxLines`.** Each
// `OmdsPrimaryButton` is `(324 − 12) / 2 = 156` pt wide, minus its own 32 pt of
// horizontal padding, inside a container pinned to `Sizes.fourXLarge` (48 pt).
// "Accept" measures 85×20 and fits; **"Accepting…" measures 124×40 — it
// already wraps to two lines at normal text scale**, and at 200% it is clamped
// to the 48 pt pill and cut off. `Center` reports no overflow, so none of this
// shows up as a stripe: the label just quietly loses its tail.
//
// | preview        | EN light      | AR RTL         | EN 200% text     |
// |----------------|--------------:|---------------:|-----------------:|
// | live/accepting |             — | **9 pt** (hdr) | 259 hdr, 184 mta |
// | declining      |             — |              — | 161 hdr, 184 mta |
// | expired        |             — |              — | 137 hdr, 184 mta |
// | no header      |             — |              — |          212 mta |
// | long content   | **60 pt** mta | 9 hdr, 59 mta  | 210 hdr, 382 mta |
//
// Nothing under `test/` sees any of it: widget tests pump into an 800×600
// viewport where the same column has 734 pt and everything fits with room to
// spare. That gap — real phone width vs test viewport — is the whole reason
// these previews are worth opening, so the `size:` boxes below are real phone
// widths rather than something roomy enough to look clean. The preview render
// tests inherit the same 800 pt viewport and stay green; the stripes are a
// canvas finding, not a test failure.
//
// ## Why the boxes are sized the way they are
//
// `_CardBody` is a default `Column` (`MainAxisSize.max`), so the card fills
// whatever height it is given. Production hands it unbounded height inside
// `ListView.builder` and it shrink-wraps; the preview host is a `Scaffold`
// body, which is bounded, so an oversized box would stretch the card's border
// into a shape production never draws. Each `size:` below is therefore the
// card's measured natural height at 390 pt. At 200% text the same cards want
// 402–458 pt and will overflow the box vertically — that is the accessibility
// finding, not a mis-sized preview.

/// Full card — header row + two one-line location rows + metadata + the 48 pt
/// action row. Measures **270 pt** at 390 pt wide (458 pt at 200% text).
const Size _requestCardBox = Size(390, 280);

/// The card minus its header row and that row's 16 pt gap: **230 pt**
/// (402 pt at 200% text). See [requestCardNoHeader].
const Size _requestCardHeaderlessBox = Size(390, 240);

/// Content ceiling: both location values wrap to their `maxLines: 2`, which is
/// 40 pt taller than the reference card — **310 pt**.
const Size _requestCardTallBox = Size(390, 320);

/// Builds the card exactly the way `request_feed_screen.dart` `_FeedListRow`
/// does: `secondsRemaining` already clamped to `>= 0` by the caller, and both
/// callbacks always non-null.
///
/// The card's own `_actionsLocked` gate is what decides whether those callbacks
/// can fire, so no preview here may fake a disabled button by passing a
/// different handler — the lock has to come from the state, as in production.
Widget _requestCardHosted({
  required String id,
  required String pickup,
  required String dropoff,
  JeeberRequestTier? tier = JeeberRequestTier.standard,
  RequestActionStatus actionStatus = RequestActionStatus.idle,
  int? secondsRemaining,
  double distanceKm = 3.4,
  double earnings = 5.2,
  String currency = 'USD',
}) =>
    RequestCard(
      request: DeliveryRequest(
        id: id,
        pickup: RequestLocation(
          label: pickup,
          latitude: 33.8959,
          longitude: 35.4797,
        ),
        dropoff: RequestLocation(
          label: dropoff,
          latitude: 33.8869,
          longitude: 35.5131,
        ),
        tier: tier,
        estimatedDistanceKm: distanceKm,
        potentialEarnings: earnings,
        currency: currency,
        // The card never reads `expiresAt` — the screen converts it into
        // `secondsRemaining` against the device clock. Pinned to a fixed
        // instant so no fixture can drift with wall-clock time.
        expiresAt: DateTime.utc(2026, 6, 11, 9, 41),
      ),
      actionStatus: actionStatus,
      secondsRemaining: secondsRemaining,
      onAccept: () {},
      onDecline: () {},
    );

/// The reference rendering: a live Standard request with a running countdown
/// and both actions armed. Every other state is read against this one.
///
/// It is also the card that exposes finding 1. The header is a bare `Row` —
/// chip, `Spacer`, countdown, no flex on either child — and in the AR RTL
/// rendering it overflows by **9 pt** while the EN rendering of the identical
/// card is clean. Check two things there: that the chip has moved to the right
/// and the timer to the left (a chip that stays left is an unmirrored row, not
/// a translation gap), and that the stripe is on the *left* edge, because that
/// is where "the trailing edge" is in RTL.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Standard · live countdown',
  size: _requestCardBox,
)
Widget requestCardLive() => _requestCardHosted(
      id: 'preview-live',
      pickup: 'Hamra, Beirut',
      dropoff: 'Achrafieh, Beirut',
      secondsRemaining: 45,
    );

/// Accept tapped, POST in flight.
///
/// Two things change at once and both matter: the accept label swaps to
/// "Accepting…" AND `_actionsLocked` disables BOTH buttons, so the Jeeber
/// cannot double-accept or decline out from under an in-flight accept. The
/// decline button keeps its idle label while disabled, which is the intended
/// asymmetry — only the acting button narrates.
///
/// This is finding 3's exhibit. "Accepting…" needs 124 pt and gets 124 pt, so
/// it wraps to two lines inside a pill whose height is pinned at 48 — at
/// **normal text scale, on a stock 390 pt phone**, not only at the 200%
/// ceiling. The Arabic label ("جارٍ القبول…") does the same. Nothing warns:
/// `Center` does not report overflow, so compare this card's accept button
/// against [requestCardLive]'s single-line "Accept" to see it.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Accepting · both locked',
  size: _requestCardBox,
)
Widget requestCardAccepting() => _requestCardHosted(
      id: 'preview-accepting',
      pickup: 'Verdun, Beirut',
      dropoff: 'Badaro, Beirut',
      actionStatus: RequestActionStatus.accepting,
      secondsRemaining: 12,
    );

/// The mirror case: decline in flight.
///
/// Worth its own preview rather than trusting symmetry, because the two labels
/// are wired through separate branches in `_CardActions` and the decline button
/// is the *outlined* variant. A disabled outlined button keeps a transparent
/// fill and only fades its 1.5 pt border to 45% — whereas the disabled accept
/// button dims a solid fill. Put the two side by side in the canvas: "this
/// button is dead" is a much weaker signal on the outlined one, and weaker
/// still in the dark AR rendering. That contrast question is a design decision,
/// not something the widget can fix on its own.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Declining · outlined disabled',
  size: _requestCardBox,
)
Widget requestCardDeclining() => _requestCardHosted(
      id: 'preview-declining',
      pickup: 'Mar Mikhael, Beirut',
      dropoff: 'Gemmayze, Beirut',
      tier: JeeberRequestTier.light,
      actionStatus: RequestActionStatus.declining,
      secondsRemaining: 8,
    );

/// G3 graceful exit, made visible: the deadline has passed but the row is still
/// listed during its linger window.
///
/// `secondsRemaining: 0` locks both actions while `actionStatus` is still
/// `idle`, which is the *only* combination that produces a dead card with live
/// labels — "Accept" and "Decline" both read normally and neither does
/// anything. The countdown reads "Expires in 0s" rather than disappearing,
/// because a card that silently vanishes mid-tap is the failure mode the linger
/// window was added to prevent.
///
/// What the canvas shows that the code does not: there is no *expired* styling.
/// Apart from the two button fills dimming and the timer reading zero, the dead
/// card is identical to the live one — same surface, same border, same tier
/// chip at full saturation. Whether that is enough of a signal at a glance,
/// mid-scroll, is worth a design decision.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Expired · 0s linger',
  size: _requestCardBox,
)
Widget requestCardExpired() => _requestCardHosted(
      id: 'preview-expired',
      pickup: 'Ras Beirut',
      dropoff: 'Furn el Chebbak',
      tier: JeeberRequestTier.bulk,
      secondsRemaining: 0,
    );

/// Degraded payload: the gateway sent neither a tier this app can label nor a
/// per-card deadline.
///
/// Both header children are absent, so `_CardBody` drops the entire header row
/// *and* its 16 pt gap — 230 pt instead of 270, the card shortening rather than
/// leaving a blank strip. Actions stay enabled: with no deadline the card is
/// live until a later snapshot stops listing it.
///
/// This is the shape an unknown tier degrades into (the model documents `null`
/// as "the gateway supplied an identifier this app cannot truthfully label"),
/// so it is a mid-deploy reality, not a defensive hypothetical. Two things to
/// read it for: a headerless card carries no urgency cue at all, and it is the
/// one state where the 200% rendering stripes on the metadata row *alone*
/// (212 pt) — proof that the metadata overflow is independent of the header,
/// not a knock-on effect of it.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'No tier, no countdown',
  size: _requestCardHeaderlessBox,
)
Widget requestCardNoHeader() => _requestCardHosted(
      id: 'preview-bare',
      pickup: 'Dbayeh Highway',
      dropoff: 'Jounieh Old Souk',
      tier: null,
      distanceKm: 12.7,
      earnings: 9.75,
    );

/// Content ceiling: the longest plausible addresses next to the longest
/// plausible earnings string.
///
/// Three limits meet here.
///
/// * Each location value is `maxLines: 2` + ellipsis inside an `Expanded`, so a
///   long address truncates instead of growing the card without bound. Both
///   wrap, which is the +40 pt that makes this [_requestCardTallBox]. In the AR
///   rendering both ellipses have to land on the *left*.
/// * The metadata row is finding 2's exhibit. "≈ 4500000.00 LBP" alone measures
///   248 pt; with the distance badge and the fixed gap the row wants 384 pt in
///   324 pt of column, and neither badge can ellipsize or wrap. **It stripes in
///   plain English at normal text scale** — a Lebanese-pound feed, which is the
///   home market, hits this on every card rather than in some edge case.
/// * `currency` is rendered as the raw ISO code the gateway sent, never
///   localized and never mapped to a symbol, so the Arabic rendering shows
///   Latin "LBP" spliced into RTL text.
@JeebPreview(
  group: 'jeeber_request_feed',
  name: 'Long addresses · LBP earnings',
  size: _requestCardTallBox,
)
Widget requestCardLongContent() => _requestCardHosted(
      id: 'preview-long',
      pickup: 'Pharmacie Centrale, Rue Sursock, near the Sursock Museum '
          'entrance, Achrafieh, Beirut',
      dropoff: 'Building 12, 4th floor, Rue Abdel Wahab El Inglizi, behind the '
          'Hotel Albergo, Achrafieh, Beirut',
      tier: JeeberRequestTier.flash,
      secondsRemaining: 120,
      distanceKm: 18.25,
      earnings: 4500000,
      currency: 'LBP',
    );
