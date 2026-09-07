import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../../core/widgets/jeeb/jeeb_navy_surface_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/availability_state.dart';
import '../../domain/entities/availability_status.dart';
import 'inactivity_warning_banner.dart';

/// Max visible lines for the status headline before it ellipsizes.
const int _kCompactOnlineTitleMaxLines = 2;

/// The dashboard's persistent availability strip (MIDNIGHT R16, tpl 940).
///
/// ONE shape for every state — presence dot, status headline, trailing control
/// — because a card that changes silhouette while a PUT is in flight reads as a
/// layout jump. Only the SURFACE changes: R16's caption is "the availability
/// card glows green when online", so online is a success-tinted glass strip and
/// every other state is the navy card. The trailing control swaps
/// (switch ↔ spinner) and the subtitle appears in the pre-auto-offline window.
class AvailabilityCard extends StatelessWidget {
  const AvailabilityCard({
    super.key,
    required this.view,
    required this.onToggle,
    this.onExtendActivity,
  });

  static const Key rootKey = Key('availability-card-root');

  /// Preserved from the legacy availability control for existing harnesses.
  static const Key toggleKey = Key('availability-toggle-root');
  static const Key spinnerKey = Key('availability-toggle-spinner');

  final AvailabilityViewState view;
  final VoidCallback onToggle;

  /// Resets the idle timer from the strip's inline `Extend` affordance. Left
  /// null by hosts that have no activity anchor to reset (bare widget tests);
  /// the warning row is then suppressed rather than shipped inert.
  final VoidCallback? onExtendActivity;

  bool get _isLit =>
      view.status.state == AvailabilityState.online && !view.isToggleInFlight;

  @override
  Widget build(BuildContext context) {
    // The gutter sits OUTSIDE the identified node so `availability_card`
    // measures the strip itself — the pinned "one-row control" height budget
    // (<= Sizes.sevenXLarge) is about the strip, not about the page margin.
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.medium,
        Spacing.xLarge,
        0,
      ),
      child: Semantics(
        key: rootKey,
        identifier: 'availability_card',
        container: true,
        explicitChildNodes: true,
        child: _StripSurface(
          isLit: _isLit,
          child: _StripRow(
            view: view,
            onToggle: onToggle,
            onExtendActivity: onExtendActivity,
            isLit: _isLit,
          ),
        ),
      ),
    );
  }
}

/// One geometry, two skins: success-tinted glass while online (R16's green
/// glow), the kit navy card in every other state.
class _StripSurface extends StatelessWidget {
  const _StripSurface({required this.isLit, required this.child});

  /// Measured off R16 tpl 940: the strip composites success at ~14% over the
  /// field, with the hairline at ~28%.
  static const double litFillAlpha = 0.14;
  static const double litBorderAlpha = 0.28;

  // The Material switch carries 8dp of its own vertical padding around its
  // 32dp track, so 8 here renders as the board's 14.
  static const EdgeInsetsGeometry padding = EdgeInsetsDirectional.symmetric(
    horizontal: Spacing.medium,
    vertical: Spacing.xSmall,
  );

  final bool isLit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isLit) {
      return JeebNavySurfaceCard(padding: padding, child: child);
    }
    final success = context.jeebRoles.success;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: success.withValues(alpha: litFillAlpha),
        borderRadius: BorderRadius.circular(JeebRadii.lg),
        border: Border.all(color: success.withValues(alpha: litBorderAlpha)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _StripRow extends StatelessWidget {
  const _StripRow({
    required this.view,
    required this.onToggle,
    required this.onExtendActivity,
    required this.isLit,
  });

  final AvailabilityViewState view;
  final VoidCallback onToggle;
  final VoidCallback? onExtendActivity;
  final bool isLit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PresenceDot(isLit: isLit),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusTitle(view: view),
              // Hoisted: `?_subtitle(context)` crashes CI's analyzer (its
              // use_build_context_synchronously has no NullAwareElement visit).
              if (_subtitle(context) case final Widget sub) sub,
            ],
          ),
        ),
        const SizedBox(width: Spacing.small),
        view.isToggleInFlight
            ? const _ToggleSpinner()
            : _AvailabilitySwitch(view: view, onToggle: onToggle),
      ],
    );
  }

  /// R16 draws "Achrafieh zone · Extend" under the headline and folds the
  /// auto-offline countdown into it. Both data slots are unavailable, and the
  /// resting `Extend` would ARM an auto-offline that is inert in production:
  ///
  /// TODO(midnight): omitted — service zone (the gateway parses none back),
  /// the auto-offline countdown (`lastActivityAt` is deliberately nulled) and
  /// therefore the resting `Extend`. Warning-window Extend below is real.
  Widget? _subtitle(BuildContext context) {
    if (view.isToggleInFlight) return null;
    final extend = onExtendActivity;
    if (view.warningVisible && extend != null) {
      return InactivityWarningBanner(onExtend: extend);
    }
    if (view.status.state != AvailabilityState.autoOffline) return null;
    final l10n = AppLocalizations.of(context);
    // OFF-29: idle is the only reason the client can produce, and the strip's
    // own switch is the go-online act — no second CTA here.
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Spacing.twoXSmall),
      child: JeebInfoNote.warning(
        title: l10n.availabilityAutoOfflineBannerTitle,
        text: l10n.availabilityAutoOfflineReasonIdle,
      ),
    );
  }
}

class _StatusTitle extends StatelessWidget {
  const _StatusTitle({required this.view});

  final AvailabilityViewState view;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTextStyle.merge(
      maxLines: _kCompactOnlineTitleMaxLines,
      overflow: TextOverflow.ellipsis,
      child: Text(
        _title(l10n),
        style: context.jeebText.cardTitle.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  /// The strip computes its own headline rather than mounting
  /// `AvailabilityStatusBlock`: that block also renders the active-deliveries
  /// and idle-hint lines, which the board does not draw and two pinned
  /// assertions require to stay absent.
  String _title(AppLocalizations l10n) {
    if (view.isToggleInFlight) return l10n.availabilityTransitioning;
    return switch (view.status.state) {
      // The counted form (`availabilityStatusOnlineUntil`) stays unwired: the
      // gateway nulls lastActivityAt, so the countdown has no anchor.
      AvailabilityState.online => l10n.availabilityStatusOnlineShort,
      AvailabilityState.offline => l10n.availabilityStatusOffline,
      AvailabilityState.autoOffline => l10n.availabilityStatusAutoOffline,
    };
  }
}

/// R16's Ø10 presence dot with its success glow (`JeebShadows.glowDotSuccess`).
/// 03-MOTION-NOTES §R16: zero animated elements — the dot does NOT pulse.
class _PresenceDot extends StatelessWidget {
  const _PresenceDot({required this.isLit});

  final bool isLit;

  @override
  Widget build(BuildContext context) {
    final color = isLit
        ? context.jeebRoles.success
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35);
    return Container(
      width: Sizes.small,
      height: Sizes.small,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: isLit ? JeebShadows.glowDotSuccess : null,
      ),
    );
  }
}

class _AvailabilitySwitch extends StatelessWidget {
  const _AvailabilitySwitch({required this.view, required this.onToggle});

  final AvailabilityViewState view;
  final VoidCallback onToggle;

  bool get _isOnline => view.status.state == AvailabilityState.online;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'availability_switch',
      container: true,
      toggled: _isOnline,
      label: _semanticLabel(l10n),
      child: Switch(
        key: AvailabilityCard.toggleKey,
        value: _isOnline,
        // The success ROLE, never the board's raw #3BB273: the palette is
        // frozen and a pinned assertion reads this back off the theme.
        activeTrackColor: context.jeebRoles.success,
        inactiveTrackColor: colorScheme.onSurface.withValues(alpha: 0.18),
        // R16 draws a white knob on both sides of the track.
        thumbColor: WidgetStatePropertyAll<Color>(colorScheme.onPrimary),
        // Allowed: `Colors.transparent` is the documented exemption. On navy
        // the M3 outline would draw a stray ring around the track.
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        onChanged: (_) => onToggle(),
      ),
    );
  }

  String _semanticLabel(AppLocalizations l10n) => switch (view.status.state) {
    AvailabilityState.online => l10n.availabilityIndicatorSemanticOnline,
    AvailabilityState.offline => l10n.availabilityIndicatorSemanticOffline,
    AvailabilityState.autoOffline =>
      l10n.availabilityIndicatorSemanticAutoOffline,
  };
}

/// In-flight: the switch is replaced outright (never a disabled switch) so the
/// PUT cannot be double-fired, and the strip keeps its height.
class _ToggleSpinner extends StatelessWidget {
  const _ToggleSpinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Sizes.fiveXLarge,
      height: Sizes.fourXLarge,
      child: Center(
        child: SizedBox(
          key: AvailabilityCard.spinnerKey,
          width: Sizes.large,
          height: Sizes.large,
          // Muted ink, never `primary`: on Midnight that is the accent orange.
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
