import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/availability_state.dart';
import '../../domain/entities/availability_status.dart';
import 'availability_status_block.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

const int _kCompactOnlineTitleMaxLines = 2;

class AvailabilityCard extends StatelessWidget {
  const AvailabilityCard({
    super.key,
    required this.view,
    required this.onToggle,
  });

  static const Key rootKey = Key('availability-card-root');

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Phone width; clears the two resting layouts at 200% text (112 px / 100 px).
/// Deliberately ONE box for both, so the compact/full pair is read at the same
const Size _availabilityCardRestingBox = Size(390, 130);

/// Phone width; clears the auto-offline section at 200% text (214 px).
const Size _availabilityCardHintBox = Size(390, 240);

/// Phone width; clears the bare progress frame at 200% text (92 px).
const Size _availabilityCardProgressBox = Size(390, 120);

/// Builds the card exactly the way `_JeeberHomeBody` does — the only
/// production caller — with a live `onToggle`, since the whole tile is the tap
Widget _availabilityCardHosted(
  AvailabilityState state, {
  int deliveries = 0,
  bool inFlight = false,
}) {
  return AvailabilityCard(
    view: AvailabilityViewState(
      loadPhase: AvailabilityLoadPhase.ready,
      status: AvailabilityStatus(
        state: state,
        activeDeliveryCount: deliveries,
      ),
      isToggleInFlight: inFlight,
    ),
    onToggle: () {},
  );
}

/// The state a working Jeeber sits in all day: online, at rest.
/// The deliberately compact branch — one `OmdsSwitchTile`, no
@JeebPreview(
  group: 'jeeber_home',
  name: 'Online · compact row',
  size: _availabilityCardRestingBox,
)
Widget availabilityCardOnline() =>
    _availabilityCardHosted(AvailabilityState.online);

/// Offline by the Jeeber's own choice — the full section, switch OFF.
/// The structural opposite of [availabilityCardOnline], in the same size box:
@JeebPreview(
  group: 'jeeber_home',
  name: 'Offline · full section',
  size: _availabilityCardRestingBox,
)
Widget availabilityCardOffline() =>
    _availabilityCardHosted(AvailabilityState.offline);

/// The system took them offline — §G2's non-dismissible explanation.
/// The only state that renders a *subtitle* under the switch title
@JeebPreview(
  group: 'jeeber_home',
  name: 'Auto-offline · with idle hint',
  size: _availabilityCardHintBox,
)
Widget availabilityCardAutoOffline() =>
    _availabilityCardHosted(AvailabilityState.autoOffline);

/// Mid-toggle: the `PUT /api/availability/toggle` is in flight.
/// The switch is **gone**, not disabled — `_AvailabilityProgress` replaces it
@JeebPreview(
  group: 'jeeber_home',
  name: 'Toggling · offline → online',
  size: _availabilityCardProgressBox,
)
Widget availabilityCardToggling() =>
    _availabilityCardHosted(AvailabilityState.offline, inFlight: true);

/// The densest state the card can reach: toggling OFF while online with work
/// already assigned.
@JeebPreview(
  group: 'jeeber_home',
  name: 'Toggling · online, 3 deliveries',
  size: Size(390, 230),
)
Widget availabilityCardTogglingWithDeliveries() => _availabilityCardHosted(
      AvailabilityState.online,
      deliveries: 3,
      inFlight: true,
    );
