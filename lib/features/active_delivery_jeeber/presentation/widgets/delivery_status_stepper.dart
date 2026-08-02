import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/jeeber_delivery_status.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class DeliveryStatusStepper extends StatelessWidget {
  const DeliveryStatusStepper({
    super.key,
    required this.currentStatus,
    required this.isTransitioning,
    required this.onAdvance,
  });

  final JeeberDeliveryStatus currentStatus;
  final bool isTransitioning;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    if (currentStatus.isUnsuccessfulTerminal) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final showAdvance =
        !currentStatus.isTerminal &&
        currentStatus != JeeberDeliveryStatus.inTransit &&
        currentStatus != JeeberDeliveryStatus.atDoor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DeliveryProgress(currentStatus: currentStatus, l10n: l10n),
        const SizedBox(height: Spacing.large),
        if (showAdvance)
          _AdvanceButton(
            nextStatus: currentStatus.next!,
            isLoading: isTransitioning,
            onAdvance: onAdvance,
            l10n: l10n,
          ),
      ],
    );
  }
}

class _DeliveryProgress extends StatelessWidget {
  const _DeliveryProgress({required this.currentStatus, required this.l10n});

  final JeeberDeliveryStatus currentStatus;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final currentIndex = jeeberDeliveryProgressStages.indexOf(currentStatus);
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            OmdsStepIndicator(
              currentStep: currentIndex + 1,
              totalSteps: jeeberDeliveryProgressStages.length,
              completedColor: colors.primary,
                activeColor: colors.tertiary,
              pendingColor: colors.surfaceContainerHighest,
              lineColor: colors.outlineVariant,
              stepSize: Sizes.threeXLarge,
              lineHeight: Sizes.threeXSmall,
              showNumbers: false,
              showCheckmark: false,
            ),
            ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (
                    var index = 0;
                    index < jeeberDeliveryProgressStages.length;
                    index++
                  )
                    _StageIcon(
                      status: jeeberDeliveryProgressStages[index],
                      state: _stateAt(index, currentIndex),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.small),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (
              var index = 0;
              index < jeeberDeliveryProgressStages.length;
              index++
            )
              Expanded(
                child: _StageLabel(
                  status: jeeberDeliveryProgressStages[index],
                  state: _stateAt(index, currentIndex),
                  l10n: l10n,
                ),
              ),
          ],
        ),
      ],
    );
  }

  _DeliveryStageState _stateAt(int index, int currentIndex) {
    if (index < currentIndex) return _DeliveryStageState.completed;
    if (index == currentIndex) return _DeliveryStageState.current;
    return _DeliveryStageState.upcoming;
  }
}

enum _DeliveryStageState { completed, current, upcoming }

class _StageIcon extends StatelessWidget {
  const _StageIcon({required this.status, required this.state});

  final JeeberDeliveryStatus status;
  final _DeliveryStageState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (state) {
      _DeliveryStageState.completed => colors.onPrimary,
      _DeliveryStageState.current => colors.onPrimaryContainer,
      _DeliveryStageState.upcoming => colors.onSurfaceVariant,
    };
    return SizedBox.square(
      key: ValueKey<String>(
        'active_delivery_stage_${status.name.toLowerCase()}_${state.name}',
      ),
      dimension: Sizes.threeXLarge,
      child: Icon(status.stepIcon, size: Sizes.large, color: color),
    );
  }
}

class _StageLabel extends StatelessWidget {
  const _StageLabel({
    required this.status,
    required this.state,
    required this.l10n,
  });

  final JeeberDeliveryStatus status;
  final _DeliveryStageState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label = status.statusLabel(l10n);
    return Semantics(
      identifier: 'active_delivery_stage_${status.name.toLowerCase()}',
      container: true,
      label: '$label, ${_stateLabel(l10n)}',
      child: ExcludeSemantics(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: _textStyle(context),
        ),
      ),
    );
  }

  String _stateLabel(AppLocalizations l10n) => switch (state) {
    _DeliveryStageState.completed => l10n.activeDeliveryStageCompletedState,
    _DeliveryStageState.current => l10n.activeDeliveryStageCurrentState,
    _DeliveryStageState.upcoming => l10n.activeDeliveryStageUpcomingState,
  };

  TextStyle? _textStyle(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return switch (state) {
      _DeliveryStageState.completed => theme.textTheme.labelSmall?.copyWith(
        color: colors.primary,
        fontWeight: FontWeight.w600,
      ),
      _DeliveryStageState.current => theme.textTheme.labelSmall?.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w700,
      ),
      _DeliveryStageState.upcoming => theme.textTheme.labelSmall?.copyWith(
        color: colors.onSurfaceVariant,
        fontWeight: FontWeight.w400,
      ),
    };
  }
}

class _AdvanceButton extends StatelessWidget {
  const _AdvanceButton({
    required this.nextStatus,
    required this.isLoading,
    required this.l10n,
    required this.onAdvance,
  });

  final JeeberDeliveryStatus nextStatus;
  final bool isLoading;
  final AppLocalizations l10n;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final label = _buttonLabel(nextStatus, l10n);
    return Semantics(
      identifier: 'mark_delivered_advance_cta',
      container: true,
      button: true,
      child: OmdsLoadingButton(
        text: label,
        isLoading: isLoading,
        onTap: onAdvance,
      ),
    );
  }

  String _buttonLabel(JeeberDeliveryStatus status, AppLocalizations l10n) {
    switch (status) {
      case JeeberDeliveryStatus.ordered:
        return l10n.activeDeliveryStatusOrdered;
      case JeeberDeliveryStatus.picked:
        return l10n.activeDeliveryMarkPicked;
      case JeeberDeliveryStatus.inTransit:
        return l10n.activeDeliveryMarkInTransit;
      case JeeberDeliveryStatus.atDoor:
        return l10n.activeDeliveryMarkAtDoor;
      case JeeberDeliveryStatus.done:
        return l10n.activeDeliveryMarkDone;
      case JeeberDeliveryStatus.cancelled:
      case JeeberDeliveryStatus.expired:
      case JeeberDeliveryStatus.disputed:
        throw StateError('Terminal deliveries cannot be advanced');
    }
  }
}

extension on JeeberDeliveryStatus {
  IconData get stepIcon {
    switch (this) {
      case JeeberDeliveryStatus.ordered:
        return Icons.receipt_long_outlined;
      case JeeberDeliveryStatus.picked:
        return Icons.inventory_2_outlined;
      case JeeberDeliveryStatus.inTransit:
        return Icons.local_shipping_outlined;
      case JeeberDeliveryStatus.atDoor:
        return Icons.home_outlined;
      case JeeberDeliveryStatus.done:
        return Icons.check_circle_outline;
      case JeeberDeliveryStatus.cancelled:
      case JeeberDeliveryStatus.expired:
      case JeeberDeliveryStatus.disputed:
        throw StateError('Terminal deliveries are not progress stages');
    }
  }

  String statusLabel(AppLocalizations l10n) {
    switch (this) {
      case JeeberDeliveryStatus.ordered:
        return l10n.activeDeliveryStatusOrdered;
      case JeeberDeliveryStatus.picked:
        return l10n.activeDeliveryStatusPicked;
      case JeeberDeliveryStatus.inTransit:
        return l10n.activeDeliveryStatusInTransit;
      case JeeberDeliveryStatus.atDoor:
        return l10n.activeDeliveryStatusAtDoor;
      case JeeberDeliveryStatus.done:
        return l10n.activeDeliveryStatusDone;
      case JeeberDeliveryStatus.cancelled:
      case JeeberDeliveryStatus.expired:
      case JeeberDeliveryStatus.disputed:
        throw StateError('Terminal deliveries are not progress stages');
    }
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// A stepper card with the inline advance CTA (`ordered`, `picked`): title +
/// stepper + labels + a 48 dp button.
const Size _deliveryStatusStepperWithCtaBox = Size(390, 240);

/// A stepper card with no CTA (`inTransit`, `atDoor`, `done`): 172 dp in EN,
/// 188 in AR, 372 at 200%.
const Size _deliveryStatusStepperOnlyBox = Size(390, 200);

/// The unsuccessful terminals, where the stepper paints nothing and only the
/// section title is left — 68 dp, all of it chrome. Deliberately short so an
const Size _deliveryStatusStepperCollapsedBox = Size(390, 100);

/// Rebuilds the stepper's production frame from `_ReadyView`: a phone-width
/// box, the `ListView`'s `Spacing.medium` padding, and the `OMDSSectionCard`
Widget _deliveryStatusStepperHosted(
  JeeberDeliveryStatus status, {
  bool isTransitioning = false,
  double deviceWidth = 390,
}) {
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(
      width: deviceWidth,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Builder(
          builder: (BuildContext context) => OMDSSectionCard(
            title: AppLocalizations.of(context).activeDeliveryProgressTitle,
            showDivider: false,
            content: DeliveryStatusStepper(
              currentStatus: status,
              isTransitioning: isTransitioning,
              // Inert: the real callback POSTs a status transition. Tapping in
              onAdvance: () {},
            ),
          ),
        ),
      ),
    ),
  );
}

/// Step 1 of 5 — the state a jeeber lands on the instant an offer is accepted.
/// The only stage where nothing is behind you: one accent circle, four pending
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Ordered · step 1 + CTA',
  size: _deliveryStatusStepperWithCtaBox,
)
Widget deliveryStatusStepperOrdered() =>
    _deliveryStatusStepperHosted(JeeberDeliveryStatus.ordered);

/// Step 2 of 5 — parcel in hand, carrying the LONGEST CTA in the set.
/// "Mark as In Transit" (18 chars) / "تحديد كـ: تم الاستلام" is the widest
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Picked · longest CTA',
  size: _deliveryStatusStepperWithCtaBox,
)
Widget deliveryStatusStepperPicked() =>
    _deliveryStatusStepperHosted(JeeberDeliveryStatus.picked);

/// The in-flight state: `isTransitioning`, i.e. the transition POST is on the
/// wire and has not come back.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Picked · transitioning',
  size: _deliveryStatusStepperWithCtaBox,
)
Widget deliveryStatusStepperPickedTransitioning() =>
    _deliveryStatusStepperHosted(
      JeeberDeliveryStatus.picked,
      isTransitioning: true,
    );

/// JM-051 regression guard, made visible: `inTransit` renders **no CTA**.
/// This is the status the jeeber seam seeds and the status the delivering-phase
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'In transit · no CTA (JM-051)',
  size: _deliveryStatusStepperOnlyBox,
)
Widget deliveryStatusStepperInTransit() =>
    _deliveryStatusStepperHosted(JeeberDeliveryStatus.inTransit);

/// `atDoor` — the last stage before completion, and the one with a landmine
/// under it.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'At door · next is null',
  size: _deliveryStatusStepperOnlyBox,
)
Widget deliveryStatusStepperAtDoor() =>
    _deliveryStatusStepperHosted(JeeberDeliveryStatus.atDoor);

/// The successful terminal, and the state that reads wrong.
/// `done` is `isTerminal`, so the CTA is gone — correct. But `_stateAt` maps
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Done · last step still accented',
  size: _deliveryStatusStepperOnlyBox,
)
Widget deliveryStatusStepperDone() =>
    _deliveryStatusStepperHosted(JeeberDeliveryStatus.done);

/// The unsuccessful terminal: `cancelled` must paint NOTHING.
/// This is defence in depth rather than a reachable screen — `_ReadyView`
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Cancelled · paints nothing',
  size: _deliveryStatusStepperCollapsedBox,
)
Widget deliveryStatusStepperCancelled() =>
    _deliveryStatusStepperHosted(JeeberDeliveryStatus.cancelled);
