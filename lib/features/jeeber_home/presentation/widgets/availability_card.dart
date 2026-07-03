import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/availability_state.dart';
import '../../domain/entities/availability_status.dart';
import 'availability_status_block.dart';

/// Compact "Availability" card — the M3 replacement for the legacy 168-px
/// glowing green disc (UX-AUDIT sprint-009 §G2).
///
/// Availability is a persistent binary *state*, not a momentary action, so
/// per Material 3 the control is a [Switch] with a label, a status chip, and
/// supporting text — never a jumbo filled CTA with a power glyph. All colors
/// resolve through the theme's semantic role layer (`context.jeebRoles.*`);
/// the old `availableNow*` raw greens (#22C55E family) are deleted.
///
/// The card renders in BOTH dashboard states — the no-requests view AND the
/// live feed — so the availability control never disappears exactly when the
/// Jeeber is busy (§SW-23).
///
/// Wiring is unchanged from the disc it replaces: the host passes the
/// [AvailabilityViewState] from `AvailabilityCubit` and a tap-through to
/// `AvailabilityCubit.toggle`. While a toggle PUT is in-flight the switch is
/// replaced by a spinner and stays tap-blocking so the Jeeber can't fire two
/// PUTs in a row.
class AvailabilityCard extends StatelessWidget {
  const AvailabilityCard({
    super.key,
    required this.view,
    required this.onToggle,
  });

  static const Key rootKey = Key('availability-card-root');

  /// Preserved from the legacy `AvailabilityToggle` so tests and flows that
  /// target the availability control by its long-standing key keep working.
  static const Key toggleKey = Key('availability-toggle-root');
  static const Key spinnerKey = Key('availability-toggle-spinner');
  static const Key statusChipKey = Key('availability-card-status-chip');

  /// Current availability snapshot from the cubit.
  final AvailabilityViewState view;

  /// Toggle callback. Wired to `AvailabilityCubit.toggle` by the host.
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'availability_card',
      container: true,
      child: Container(
        key: rootKey,
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: OmdsBorderRadius.large,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.availabilityCardTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _StatusChip(state: view.status.state),
              ],
            ),
            const SizedBox(height: Spacing.small),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: AvailabilityStatusBlock(view: view)),
                const SizedBox(width: Spacing.small),
                _AvailabilitySwitch(view: view, onToggle: onToggle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Non-interactive status chip: success container roles when online, neutral
/// surface roles when offline, warning container roles when the system forced
/// the Jeeber offline (attention state — mirrors the feed's offline banner).
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});

  final AvailabilityState state;

  @override
  Widget build(BuildContext context) {
    final roles = context.jeebRoles;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final (label, background, foreground) = switch (state) {
      AvailabilityState.online => (
          l10n.availabilityToggleOnline,
          roles.successContainer,
          roles.onSuccessContainer,
        ),
      AvailabilityState.offline => (
          l10n.availabilityToggleOffline,
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
      AvailabilityState.autoOffline => (
          l10n.availabilityIndicatorSemanticAutoOffline,
          roles.warningContainer,
          roles.onWarningContainer,
        ),
    };
    return OmdsChip(
      key: AvailabilityCard.statusChipKey,
      label: label,
      isSelected: true,
      selectedColor: background,
      selectedTextColor: foreground,
    );
  }
}

/// The M3 switch that owns the actual toggle interaction. Swapped for a
/// spinner (same key as the legacy disc's) while the PUT is in-flight so the
/// control stays visibly busy and tap-blocked.
class _AvailabilitySwitch extends StatelessWidget {
  const _AvailabilitySwitch({required this.view, required this.onToggle});

  final AvailabilityViewState view;
  final VoidCallback onToggle;

  bool get _isOnline => view.status.state == AvailabilityState.online;

  @override
  Widget build(BuildContext context) {
    if (view.isToggleInFlight) {
      return const SizedBox(
        // Keep the in-flight footprint no smaller than the a11y minimum so
        // the row doesn't jump and the touch target stays compliant.
        width: Sizes.fiveXLarge,
        height: Sizes.threeXLarge,
        child: Center(
          child: OmdsLoadingState(
            key: AvailabilityCard.spinnerKey,
            size: Sizes.large,
            padding: EdgeInsets.zero,
          ),
        ),
      );
    }
    final roles = context.jeebRoles;
    return Semantics(
      identifier: 'availability_switch',
      container: true,
      toggled: _isOnline,
      label: _semanticLabel(context),
      child: Switch(
        key: AvailabilityCard.toggleKey,
        value: _isOnline,
        activeTrackColor: roles.success,
        activeThumbColor: roles.onSuccess,
        onChanged: (_) => onToggle(),
      ),
    );
  }

  String _semanticLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (view.status.state) {
      AvailabilityState.online => l10n.availabilityIndicatorSemanticOnline,
      AvailabilityState.offline => l10n.availabilityIndicatorSemanticOffline,
      AvailabilityState.autoOffline =>
        l10n.availabilityIndicatorSemanticAutoOffline,
    };
  }
}
