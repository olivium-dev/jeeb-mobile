import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/availability_status.dart';

/// Big circular online/offline toggle that lives at the top of the
/// Jeeber home screen.
///
/// Visual:
///   - Green-glow ring + filled green disc when [state] is
///     [AvailabilityState.online].
///   - Outlined grey disc when offline or auto-offline.
///   - Spinner overlay while [isInFlight] is true. The toggle stays
///     tap-blocking during this window so the Jeeber can't fire two
///     PUTs in a row.
class AvailabilityToggle extends StatelessWidget {
  const AvailabilityToggle({
    super.key,
    required this.state,
    required this.isInFlight,
    required this.onTap,
  });

  static const Key rootKey = Key('availability-toggle-root');
  static const Key spinnerKey = Key('availability-toggle-spinner');

  // Composed from OMDS Sizes tokens — there is no single-token match for the
  // 168-px tap target in the JEEB design, so we compose it explicitly:
  //   eightXLarge (80) * 2 + xSmall (8) = 168.
  // Glow spread is xLarge (24) + twoXSmall (4) = 28.
  // Ring width is twoXSmall (4) — the divider/stroke scale.
  static const double diameter = Sizes.eightXLarge * 2 + Sizes.xSmall;
  static const double glowSpread = Sizes.xLarge + Sizes.twoXSmall;
  static const double ringWidth = Sizes.twoXSmall;

  /// Current availability state (drives color).
  final AvailabilityState state;

  /// Whether a toggle PUT is in-flight (drives spinner + tap-block).
  final bool isInFlight;

  /// Tapped callback. Wired to the cubit by the screen.
  final VoidCallback onTap;

  bool get _isOnline => state == AvailabilityState.online;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: rootKey,
      button: true,
      enabled: !isInFlight,
      toggled: _isOnline,
      label: _semanticLabel(context),
      child: GestureDetector(
        onTap: isInFlight ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: _ToggleDisc(
          isOnline: _isOnline,
          isInFlight: isInFlight,
          state: state,
        ),
      ),
    );
  }

  String _semanticLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (state) {
      AvailabilityState.online => l10n.availabilityIndicatorSemanticOnline,
      AvailabilityState.offline => l10n.availabilityIndicatorSemanticOffline,
      AvailabilityState.autoOffline =>
        l10n.availabilityIndicatorSemanticAutoOffline,
    };
  }
}

/// Colors resolved for the toggle disc — pulled into a value object so the
/// surface and content widgets share one source of truth.
@immutable
class _ToggleColors {
  const _ToggleColors({
    required this.fill,
    required this.ring,
    required this.glow,
    required this.icon,
  });

  factory _ToggleColors.resolve(BuildContext context, {required bool isOnline}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantics = theme.extension<JeebSemanticColors>()!;
    final fill = isOnline
        ? semantics.availableNow
        : colorScheme.surfaceContainerHighest;
    final ring = isOnline
        ? semantics.availableNowRing
        : colorScheme.outlineVariant;
    final glow = isOnline
        ? semantics.availableNow.withValues(alpha: UIConstants.opacityDisabled)
        : Colors.transparent;
    final icon = isOnline ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;
    return _ToggleColors(fill: fill, ring: ring, glow: glow, icon: icon);
  }

  final Color fill;
  final Color ring;
  final Color glow;
  final Color icon;
}

class _ToggleDisc extends StatelessWidget {
  const _ToggleDisc({
    required this.isOnline,
    required this.isInFlight,
    required this.state,
  });

  final bool isOnline;
  final bool isInFlight;
  final AvailabilityState state;

  @override
  Widget build(BuildContext context) {
    final colors = _ToggleColors.resolve(context, isOnline: isOnline);
    return AnimatedContainer(
      duration: UIConstants.animationFast,
      curve: Curves.easeInOut,
      width: AvailabilityToggle.diameter,
      height: AvailabilityToggle.diameter,
      decoration: _decoration(colors),
      child: Center(
        child: isInFlight
            ? _ToggleSpinner(color: colors.icon)
            : _ToggleContent(isOnline: isOnline, color: colors.icon),
      ),
    );
  }

  BoxDecoration _decoration(_ToggleColors colors) {
    return BoxDecoration(
      shape: BoxShape.circle,
      color: colors.fill,
      border: Border.all(color: colors.ring, width: AvailabilityToggle.ringWidth),
      boxShadow: [
        if (isOnline)
          BoxShadow(
            color: colors.glow,
            blurRadius: AvailabilityToggle.glowSpread,
            spreadRadius: AvailabilityToggle.glowSpread / 2,
          ),
      ],
    );
  }
}

class _ToggleSpinner extends StatelessWidget {
  const _ToggleSpinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return OmdsLoadingState(
      key: AvailabilityToggle.spinnerKey,
      size: Sizes.xLarge,
      color: color,
      padding: EdgeInsets.zero,
    );
  }
}

class _ToggleContent extends StatelessWidget {
  const _ToggleContent({required this.isOnline, required this.color});

  final bool isOnline;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isOnline ? Icons.power_settings_new : Icons.power_settings_new_outlined,
          size: Sizes.fiveXLarge,
          color: color,
        ),
        const SizedBox(height: Spacing.twoXSmall),
        Text(
          isOnline ? l10n.availabilityToggleOnline : l10n.availabilityToggleOffline,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
