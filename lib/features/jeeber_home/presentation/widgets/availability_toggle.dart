import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

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
///     tappable-blocking during this window so the Jeeber can't fire two
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

  static const double _diameter = 168;
  static const double _glowSpread = 28;
  static const double _ringWidth = 4;

  /// Current availability state (drives color).
  final AvailabilityState state;

  /// Whether a toggle PUT is in-flight (drives spinner + tap-block).
  final bool isInFlight;

  /// Tapped callback. Wired to the cubit by the screen.
  final VoidCallback onTap;

  bool get _isOnline => state == AvailabilityState.online;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final activeColor = _isOnline
        ? const Color(0xFF22C55E) // Green-500. Online is a brand-agnostic
        : colorScheme.surfaceContainerHighest;
    final ringColor = _isOnline
        ? const Color(0xFF16A34A) // Green-600
        : colorScheme.outlineVariant;
    final glowColor = _isOnline
        ? const Color(0xFF22C55E).withValues(alpha: 0.45)
        : Colors.transparent;
    final iconColor = _isOnline ? Colors.white : colorScheme.onSurfaceVariant;

    final semanticLabel = switch (state) {
      AvailabilityState.online => l10n.availabilityIndicatorSemanticOnline,
      AvailabilityState.offline => l10n.availabilityIndicatorSemanticOffline,
      AvailabilityState.autoOffline =>
        l10n.availabilityIndicatorSemanticAutoOffline,
    };

    return Semantics(
      key: rootKey,
      button: true,
      enabled: !isInFlight,
      toggled: _isOnline,
      label: semanticLabel,
      child: GestureDetector(
        onTap: isInFlight ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          width: _diameter,
          height: _diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activeColor,
            border: Border.all(color: ringColor, width: _ringWidth),
            boxShadow: [
              if (_isOnline)
                BoxShadow(
                  color: glowColor,
                  blurRadius: _glowSpread,
                  spreadRadius: _glowSpread / 2,
                ),
            ],
          ),
          child: Center(
            child: isInFlight
                ? SizedBox(
                    key: spinnerKey,
                    width: Sizes.xLarge,
                    height: Sizes.xLarge,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isOnline
                            ? Icons.power_settings_new
                            : Icons.power_settings_new_outlined,
                        size: 56,
                        color: iconColor,
                      ),
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        _isOnline
                            ? l10n.availabilityToggleOnline
                            : l10n.availabilityToggleOffline,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: iconColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
