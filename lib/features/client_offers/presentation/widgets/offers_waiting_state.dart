import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/formatting/countdown_format.dart';
import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../../l10n/app_localizations.dart';
import 'offer_window_timer.dart';

/// E2 · "Empty ≠ dead" — the waiting-for-offers surface of the offer-review
/// list, and the same block in its loading and load-failed forms.
///
/// The tile draws a live radar: the request broadcasting at the centre of the
/// ring set while Jeeber discs fade in and out of range. It is composed from
/// [JeebEmptyState] — the sanctioned empty family — with the broadcast disc in
/// the `center` slot and person medallions on the ring anchors.
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
      status: status,
      // TODO(midnight): l10n-queued — the board headlines the live reach
      // ("Broadcasting to 12 Jeebers…"); no reach count is on the wire, so the
      // count is omitted, not faked.
      headline: override ?? l10n.offersEmptyTitle,
      body: override == null ? l10n.offersEmptyBody : body,
      center: _BroadcastDisc(status: status),
      medallions: _kJeeberMedallions,
      action:
          action ??
          (remaining == null ? null : _WindowChip(remaining: remaining)),
      headlineIdentifier: 'offer_review_empty_title',
      bodyIdentifier: 'offer_review_empty_body',
    );
  }
}

/// The three Jeeber discs the tile fades in and out of range. They are people,
/// not subjects: no name is known while the request is still broadcasting, so a
/// person glyph stands in rather than a fabricated initial.
const List<JeebEmptyMedallion> _kJeeberMedallions = <JeebEmptyMedallion>[
  JeebEmptyMedallion(icon: Icons.person),
  JeebEmptyMedallion(icon: Icons.person),
  JeebEmptyMedallion(icon: Icons.person),
];

/// Diameter of the broadcast disc inside the illustration's 94dp centre slot.
const double _kBroadcastDisc = 66;

/// Glyph inside it.
const double _kBroadcastGlyph = 34;

/// The request itself, broadcasting — the orange disc at the centre of the
/// radar (the tile's `(·)` mark over the accent gradient and its bloom).
class _BroadcastDisc extends StatelessWidget {
  const _BroadcastDisc({required this.status});

  final JeebEmptyStateStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roles = context.jeebRoles;
    final semantics =
        theme.extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight();
    // The kit danger-tints the layers it paints; the centre is ours, so it has
    // to follow or the failure reads as a live broadcast.
    final bool danger = status == JeebEmptyStateStatus.error;
    final Color top = danger
        ? theme.colorScheme.onErrorContainer
        : semantics.orangeBright;
    final Color bottom = danger ? theme.colorScheme.error : roles.accent;
    return Center(
      child: SizedBox.square(
        dimension: _kBroadcastDisc,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[top, bottom],
            ),
            boxShadow: danger ? null : JeebShadows.glowRest,
          ),
          child: Icon(
            danger ? Icons.cloud_off_outlined : Icons.wifi_tethering,
            size: _kBroadcastGlyph,
            color: danger ? theme.colorScheme.onError : roles.onAccent,
          ),
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
