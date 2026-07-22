import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/availability_state.dart';
import '../../domain/entities/availability_status.dart';
import 'availability_status_block.dart';

/// Max visible lines for the compact online-state copy before it ellipsizes.
const int _kCompactOnlineTitleMaxLines = 2;

/// Persistent dashboard availability control.
///
/// The common ONLINE state is intentionally one compact OMDS switch row: its
/// only copy is "online — receiving requests", so it consumes at most one or
/// two wrapped lines on a phone. OFFLINE, auto-offline, and in-flight states use
/// the full OMDS section because they need more explanation or progress feedback.
class AvailabilityCard extends StatelessWidget {
  const AvailabilityCard({
    super.key,
    required this.view,
    required this.onToggle,
  });

  static const Key rootKey = Key('availability-card-root');

  /// Preserved from the legacy availability control for existing harnesses.
  static const Key toggleKey = Key('availability-toggle-root');
  static const Key spinnerKey = Key('availability-toggle-spinner');

  final AvailabilityViewState view;
  final VoidCallback onToggle;

  bool get _isCompactOnline =>
      view.status.state == AvailabilityState.online && !view.isToggleInFlight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: rootKey,
      identifier: 'availability_card',
      container: true,
      explicitChildNodes: true,
      child: _isCompactOnline
          ? _CompactOnlineAvailability(onToggle: onToggle)
          : _FullAvailabilitySection(view: view, onToggle: onToggle),
    );
  }
}

class _CompactOnlineAvailability extends StatelessWidget {
  const _CompactOnlineAvailability({required this.onToggle});

  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'availability_switch',
      container: true,
      toggled: true,
      label: l10n.availabilityIndicatorSemanticOnline,
      child: DefaultTextStyle.merge(
        maxLines: _kCompactOnlineTitleMaxLines,
        overflow: TextOverflow.ellipsis,
        child: OmdsSwitchTile(
          key: AvailabilityCard.toggleKey,
          title: l10n.availabilityStatusOnline,
          value: true,
          activeColor: context.jeebRoles.success,
          dense: true,
          contentPadding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.xSmall,
          ),
          onChanged: (_) => onToggle(),
        ),
      ),
    );
  }
}

class _FullAvailabilitySection extends StatelessWidget {
  const _FullAvailabilitySection({required this.view, required this.onToggle});

  final AvailabilityViewState view;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OMDSSectionCard(
      title: l10n.availabilityCardTitle,
      horizontalPadding: Spacing.medium,
      spacing: Spacing.twoXSmall,
      showDivider: false,
      content: view.isToggleInFlight
          ? _AvailabilityProgress(view: view)
          : _AvailabilitySwitchRow(view: view, onToggle: onToggle),
    );
  }
}

class _AvailabilitySwitchRow extends StatelessWidget {
  const _AvailabilitySwitchRow({required this.view, required this.onToggle});

  final AvailabilityViewState view;
  final VoidCallback onToggle;

  bool get _isOnline => view.status.state == AvailabilityState.online;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'availability_switch',
      container: true,
      toggled: _isOnline,
      label: _semanticLabel(l10n),
      child: OmdsSwitchTile(
        key: AvailabilityCard.toggleKey,
        title: _title(l10n),
        subtitle: view.status.state == AvailabilityState.autoOffline
            ? l10n.availabilityAutoOfflineHint
            : null,
        value: _isOnline,
        activeColor: context.jeebRoles.success,
        contentPadding: EdgeInsets.zero,
        onChanged: (_) => onToggle(),
      ),
    );
  }

  String _title(AppLocalizations l10n) => switch (view.status.state) {
    AvailabilityState.online => l10n.availabilityStatusOnline,
    AvailabilityState.offline => l10n.availabilityStatusOffline,
    AvailabilityState.autoOffline => l10n.availabilityStatusAutoOffline,
  };

  String _semanticLabel(AppLocalizations l10n) => switch (view.status.state) {
    AvailabilityState.online => l10n.availabilityIndicatorSemanticOnline,
    AvailabilityState.offline => l10n.availabilityIndicatorSemanticOffline,
    AvailabilityState.autoOffline =>
      l10n.availabilityIndicatorSemanticAutoOffline,
  };
}

class _AvailabilityProgress extends StatelessWidget {
  const _AvailabilityProgress({required this.view});

  final AvailabilityViewState view;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: AvailabilityStatusBlock(view: view)),
        const SizedBox(width: Spacing.small),
        const SizedBox(
          width: Sizes.fiveXLarge,
          height: Sizes.threeXLarge,
          child: Center(
            child: OmdsLoadingState(
              key: AvailabilityCard.spinnerKey,
              size: Sizes.large,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}
