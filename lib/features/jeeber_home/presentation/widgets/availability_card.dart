import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_shadows.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_navy_surface_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/availability_state.dart';
import '../../domain/entities/availability_status.dart';
import 'inactivity_warning_banner.dart';

/// Max visible lines for the status headline before it ellipsizes.
const int _kCompactOnlineTitleMaxLines = 2;

/// The dashboard's persistent availability strip (redesign-2026-08 §5 #4).
///
/// ONE shape for every state — navy surface, presence dot, status headline,
/// trailing control — because the board draws one strip and a card that
/// changes silhouette while a PUT is in flight reads as a layout jump. Only
/// the trailing control swaps (switch ↔ spinner) and the subtitle appears
/// (auto-offline hint / the inline Extend row).
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

  bool get _isOnline => view.status.state == AvailabilityState.online;

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
        child: JeebNavySurfaceCard(
          shadow: JeebShadows.ctaNavy,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
            // The Material switch carries 8dp of its own vertical padding
            // around its 32dp track, so 8 here renders as the board's 14.
            vertical: Spacing.xSmall,
          ),
          child: _StripRow(
            view: view,
            onToggle: onToggle,
            onExtendActivity: onExtendActivity,
            isOnline: _isOnline,
          ),
        ),
      ),
    );
  }
}

class _StripRow extends StatelessWidget {
  const _StripRow({
    required this.view,
    required this.onToggle,
    required this.onExtendActivity,
    required this.isOnline,
  });

  final AvailabilityViewState view;
  final VoidCallback onToggle;
  final VoidCallback? onExtendActivity;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PresenceDot(
          isOnline: isOnline,
          isToggleInFlight: view.isToggleInFlight,
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusTitle(view: view),
              ?_subtitle(context),
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

  /// Settled online / settled offline carry NO subtitle — the headline already
  /// says everything and the pinned assertions require the idle hint to stay
  /// absent in both. Only auto-offline explains itself, and only the pre-
  /// auto-offline window offers the inline Extend.
  Widget? _subtitle(BuildContext context) {
    if (view.isToggleInFlight) return null;
    final extend = onExtendActivity;
    if (view.warningVisible && extend != null) {
      return InactivityWarningBanner(onExtend: extend);
    }
    if (view.status.state != AvailabilityState.autoOffline) return null;
    return Text(
      AppLocalizations.of(context).availabilityAutoOfflineHint,
      style: context.jeebText.bodySmall.copyWith(color: _mutedInk(context)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
          color: Theme.of(context).colorScheme.onPrimary,
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
      AvailabilityState.online => l10n.availabilityStatusOnline,
      AvailabilityState.offline => l10n.availabilityStatusOffline,
      AvailabilityState.autoOffline => l10n.availabilityStatusAutoOffline,
    };
  }
}

/// The board's Ø10 presence dot with its 4px halo. Built from size tokens
/// (Ø12 + a spread-only shadow) so it stays direction-free and gate-clean.
class _PresenceDot extends StatelessWidget {
  const _PresenceDot({required this.isOnline, required this.isToggleInFlight});

  final bool isOnline;
  final bool isToggleInFlight;

  @override
  Widget build(BuildContext context) {
    final color = isOnline && !isToggleInFlight
        ? context.jeebRoles.success
        : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.35);
    return Container(
      width: Sizes.small,
      height: Sizes.small,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            spreadRadius: Sizes.twoXSmall,
          ),
        ],
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
        inactiveTrackColor: colorScheme.onPrimary.withValues(alpha: 0.18),
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
        child: OmdsLoadingState(
          key: AvailabilityCard.spinnerKey,
          size: Sizes.large,
          color: Theme.of(context).colorScheme.onPrimary,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

/// Periwinkle — the board's subtitle ink on navy. Read defensively so a bare
/// `ThemeData.light()` harness does not crash.
Color _mutedInk(BuildContext context) =>
    (Theme.of(context).extension<JeebSemanticColors>() ??
            JeebSemanticColors.light())
        .mutedText;
