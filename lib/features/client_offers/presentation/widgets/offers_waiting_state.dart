import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/countdown_format.dart';
import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../../l10n/app_localizations.dart';
import 'offer_window_timer.dart';

/// E2 · "Empty ≠ dead" — the waiting-for-offers surface of the offer-review
/// list, and the same block in its loading and load-failed forms.
///
/// [JeebEmptyStateVariant.radar] is the tile: three orange rings pulsing
/// inward, the request broadcasting from the still core, and three jeeber discs
/// fading in and out of range on the kit's brightness ladder. The failure form
/// swaps that core for a no-signal disc; the kit danger-tints the rest itself.
class OffersWaitingState extends StatelessWidget {
  const OffersWaitingState({
    super.key,
    required this.blockKey,
    this.status = JeebEmptyStateStatus.empty,
    this.headline,
    this.body,
    this.windowRemaining,
    this.action,
  });

  /// Key on the composed block — the per-state anchor the screen tests find
  /// (`offer-empty-state`, `offer-loading-state`, `offer-load-error`).
  final Key blockKey;

  /// Empty (waiting), loading (skeleton) or error (danger-tinted centre).
  final JeebEmptyStateStatus status;

  /// Overrides the waiting headline — the error form passes the failure copy.
  /// Setting it also hands [body] over: null then means "no second line".
  final String? headline;

  /// Second line, honoured only alongside [headline].
  final String? body;

  /// Time left on the offer window. Null draws no countdown chip — the state
  /// has no honest deadline to show (closed / expired / failed).
  final Duration? windowRemaining;

  /// Replaces the countdown chip, for the error form's Retry CTA.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final remaining = windowRemaining;
    final override = headline;
    return JeebEmptyState(
      key: blockKey,
      identifier: 'offer_review_empty_state',
      variant: JeebEmptyStateVariant.radar,
      status: status,
      // TODO(midnight): l10n-queued — the board headlines the live reach
      // ("Broadcasting to 12 Jeebers…"); no reach count is on the wire, so the
      // count is omitted, not faked.
      headline: override ?? l10n.offersEmptyTitle,
      body: override == null ? l10n.offersEmptyBody : body,
      // Waiting keeps the kit's own broadcast core (bloom ring + `(·)` glyph);
      // only the failure form overrides it. Discs default to the tile's K/N/R.
      center: status == JeebEmptyStateStatus.error
          ? const _BroadcastLostDisc()
          : null,
      action:
          action ??
          (remaining == null ? null : _WindowChip(remaining: remaining)),
      headlineIdentifier: 'offer_review_empty_title',
      bodyIdentifier: 'offer_review_empty_body',
    );
  }
}

/// Glyph inside the failure core, sized off the radar's Ø58 core slot.
const double _kLostGlyph = 28;

/// The failure form's centre: the request is no longer reaching anyone, so the
/// core goes danger and drops the bloom the live broadcast earns.
class _BroadcastLostDisc extends StatelessWidget {
  const _BroadcastLostDisc();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[scheme.onErrorContainer, scheme.error],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.cloud_off_outlined,
          size: _kLostGlyph,
          color: scheme.onError,
        ),
      ),
    );
  }
}

/// The glass countdown capsule under the body copy — "Window closes in 4:12".
class _WindowChip extends StatelessWidget {
  const _WindowChip({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final roles = context.jeebRoles;
    return JeebGlassCard(
      radius: JeebRadii.pill,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.xSmall,
      ),
      identifier: 'offer_review_waiting_window_chip',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OfferWindowDot(color: roles.accent),
          const SizedBox(width: Spacing.xSmall),
          Text(
            // TODO(midnight): l10n-queued — the board's chip is the bare
            // "Window closes in {time}" (`offersWaitingWindowChip`).
            l10n.offersWindowStrip(0, CountdownFormat.format(remaining)),
            style: context.jeebText.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
