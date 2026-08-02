import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/jeeber_delivery_status.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

/// Horizontal stepper showing the successful delivery stages for the Jeeber.
///
/// OMDS owns the stage circles, connectors, and completed/current/upcoming
/// colors through [OmdsStepIndicator]. This feature layer supplies only the
/// delivery-specific icons, labels, and accessibility copy.
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
    // JM-051: during the delivering phase (InTransit / AtDoor) the journey to
    // Done is owned by the MarkDeliveredPanel's `mark_delivered_cta` (it needs
    // the proof photo + the done→rating chain), so the stepper suppresses its
    // own advance button there. Earlier stages (Ordered → Picked → InTransit)
    // keep the inline advance button.
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
              // Accent PAINT, not a container fill — see the tone-pair note in
                // `app_theme.dart`. `tertiary` is the same #D73B00 this line
                // rendered before the palette fix.
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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests:
// test/previews/active_delivery_jeeber/delivery_status_stepper_preview_test.dart
// ===========================================================================
//
// Widget previews for [DeliveryStatusStepper] — run with
// `flutter widget-preview start`.
//
// The stepper takes three inputs and reads nothing else: a
// [JeeberDeliveryStatus], an `isTransitioning` flag, and an `onAdvance`
// callback. No cubit, no repository, no gateway — every preview below is a
// pure function of an enum value and a bool, which makes this section
// network-free by construction rather than by the guard in [jeebPreviewHost].
//
// The states that matter are therefore the STATUS the jeeber's delivery is
// parked on, because the widget changes shape three separate ways along that
// axis:
//
//   * `ordered` / `picked` — stepper **plus** an inline advance CTA.
//   * `inTransit` / `atDoor` — stepper only. JM-051 moved the journey to Done
//     into `MarkDeliveredPanel` (it needs the proof photo), so the stepper
//     suppresses its own button for the whole delivering phase.
//   * `cancelled` / `expired` / `disputed` — nothing at all
//     (`SizedBox.shrink`).
//
// Production placement is `active_delivery_jeeber_screen.dart` (`_ReadyView`):
// the stepper is the `content` of an `OMDSSectionCard(showDivider: false)`
// titled `activeDeliveryProgressTitle`, inside a `ListView` padded
// `Spacing.medium` on every side. Every preview rebuilds that exact frame, so
// the canvas shows the width the stepper really gets — 310 dp on a 390 dp
// phone, not the full canvas — and so the five stage labels are reviewed at
// the 62 dp per column they actually have to fit in. `pumpPreview` renders at
// the default 800x600 test viewport and ignores [JeebPreview.size], so a
// preview that wants to say anything about phone-width layout has to clamp
// itself; [_deliveryStatusStepperHosted] does.
//
// Fixture data is the enum itself — the same five stages
// `test/features/active_delivery_jeeber/delivery_status_stepper_test.dart`
// walks, plus the two unsuccessful terminals it asserts render nothing.

/// A stepper card with the inline advance CTA (`ordered`, `picked`): title +
/// stepper + labels + a 48 dp button.
///
/// Measured with the frame below: 220 dp tall in EN, 236 in AR, and 420 at the
/// 200% rendering — that last one does not fit this box, deliberately. Every
/// dimension in this section comes from the render test, which runs on the test
/// fallback font; its glyphs are wider than the bundled Inter, so these are
/// upper bounds, not promises about the shipped font.
const Size _deliveryStatusStepperWithCtaBox = Size(390, 240);

/// A stepper card with no CTA (`inTransit`, `atDoor`, `done`): 172 dp in EN,
/// 188 in AR, 372 at 200%.
const Size _deliveryStatusStepperOnlyBox = Size(390, 200);

/// The unsuccessful terminals, where the stepper paints nothing and only the
/// section title is left — 68 dp, all of it chrome. Deliberately short so an
/// accidental re-appearance of the stepper is obvious as an overflow rather
/// than as extra whitespace.
const Size _deliveryStatusStepperCollapsedBox = Size(390, 100);

/// Rebuilds the stepper's production frame from `_ReadyView`: a phone-width
/// box, the `ListView`'s `Spacing.medium` padding, and the `OMDSSectionCard`
/// that supplies both the title and the `OMDSSpacing.xl` side padding.
///
/// 390 − 2×16 (list) − 2×24 (card) = 310 dp of content, i.e. 62 dp per stage
/// column. That number is the whole reason this helper exists: reviewed at the
/// canvas's full width the labels never wrap and every state looks fine.
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
              // the canvas must do nothing at all.
              onAdvance: () {},
            ),
          ),
        ),
      ),
    ),
  );
}

/// Step 1 of 5 — the state a jeeber lands on the instant an offer is accepted.
///
/// The only stage where nothing is behind you: one accent circle, four pending
/// ones, and the CTA reading "Mark as Picked" (the label names the NEXT status,
/// not the current one — `_AdvanceButton` is handed `currentStatus.next`).
///
/// This is also the leftmost/rightmost-circle case for RTL: in Arabic the whole
/// stepper mirrors, so the active circle must sit on the RIGHT with the four
/// pending stages running away to the left. If the AR rendering shows the
/// accent on the left, the icon overlay [Row] and the [OmdsStepIndicator]
/// underneath it have stopped mirroring together and every icon is now sitting
/// on the wrong circle. Measured: the `ordered` icon's centre is 60 dp from the
/// LEADING edge in both directions, so today they mirror together — the render
/// test pins that equality.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Ordered · step 1 + CTA',
  size: _deliveryStatusStepperWithCtaBox,
)
Widget deliveryStatusStepperOrdered() =>
    _deliveryStatusStepperHosted(JeeberDeliveryStatus.ordered);

/// Step 2 of 5 — parcel in hand, carrying the LONGEST CTA in the set.
///
/// "Mark as In Transit" (18 chars) / "تحديد كـ: تم الاستلام" is the widest
/// label `_buttonLabel` can produce, so this is the card that decides whether
/// the button fits at the 200% rendering. It does not: `OmdsLoadingButton`
/// hard-codes `height: Sizes.fourXLarge` (48 dp) around a plain `Text`, so at
/// 200% the label wraps to two lines inside a box that is still 48 dp tall and
/// the second line is CLIPPED — no ellipsis, no growth, no overflow stripe to
/// warn you. Pinned by the render test; at 1x it fits on one line with room to
/// spare, which is why only the third rendering of the matrix shows it.
///
/// It also shows the first completed connector, which is the only place
/// `completedColor` (primary) and `activeColor` (tertiary #D73B00) are visible
/// side by side — the tone pair the widget's own comment warns about.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Picked · longest CTA',
  size: _deliveryStatusStepperWithCtaBox,
)
Widget deliveryStatusStepperPicked() =>
    _deliveryStatusStepperHosted(JeeberDeliveryStatus.picked);

/// The in-flight state: `isTransitioning`, i.e. the transition POST is on the
/// wire and has not come back.
///
/// `OmdsLoadingButton` swaps the label for an indeterminate spinner, so the CTA
/// loses its text entirely — compare against the card above, which is the same
/// status one frame earlier. Two things to check here: the button keeps its
/// full 48 dp height (a collapsing button makes the card jump), and the stepper
/// above it does NOT advance — the circles still say `picked`, because the
/// optimistic advance is the server's to confirm.
///
/// The CTA also goes INERT here — `OmdsLoadingButton` drops its `onTap`
/// (`canTap = isEnabled && !isLoading`) and the merged
/// `mark_delivered_advance_cta` node loses its tap action, so a second
/// `POST /v1/delivery/status/transition` cannot be fired for the same step by
/// double-tapping. Pinned by the render test, with the idle card as the
/// control. What survives is `isButton: true` on a node with nothing to do: a
/// screen reader still announces "button" for the duration of the request.
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
///
/// This is the status the jeeber seam seeds and the status the delivering-phase
/// flow asserts on first frame, so it is the single most-viewed state of this
/// widget. From here the journey to Done belongs to `MarkDeliveredPanel`
/// (`mark_delivered_cta`), which owns the proof photo and the done→rating
/// chain; a button re-appearing in this card means the two panels are now
/// offering two different ways to finish a delivery, and only one of them
/// attaches proof.
///
/// The card should read: two completed stages behind, the truck accent, two
/// pending ahead, and nothing below the labels.
///
/// It is also the cleanest card for the OTHER text ceiling: each stage label
/// gets a bare `Expanded`, i.e. 310 / 5 = 62 dp, with no `maxLines`, no
/// ellipsis and no `FittedBox`. "In Transit" needs more than that for a single
/// word at 200%, so the label breaks MID-WORD and the label row grows from 32
/// to 160 dp. Arabic hits the same wall one step earlier — "تم الاستلام" is
/// already on three lines at 1x in the render test's font.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'In transit · no CTA (JM-051)',
  size: _deliveryStatusStepperOnlyBox,
)
Widget deliveryStatusStepperInTransit() =>
    _deliveryStatusStepperHosted(JeeberDeliveryStatus.inTransit);

/// `atDoor` — the last stage before completion, and the one with a landmine
/// under it.
///
/// P6/B2: `atDoor.next` is `null` on purpose — `AtDoor → Done` is not an edge
/// on the plain status-patch path, it runs through the door OTP. The stepper's
/// `showAdvance` happens to exclude `atDoor` for a DIFFERENT reason (JM-051's
/// proof-photo hand-off), and those two guards are the only things standing
/// between this state and the `currentStatus.next!` null-assert inside
/// `_AdvanceButton`. Anyone "restoring" the inline button for the delivering
/// phase will find `ordered`, `picked` and `inTransit` all fine and this card
/// throwing — which is exactly why it gets its own preview instead of being
/// folded into the one above.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'At door · next is null',
  size: _deliveryStatusStepperOnlyBox,
)
Widget deliveryStatusStepperAtDoor() =>
    _deliveryStatusStepperHosted(JeeberDeliveryStatus.atDoor);

/// The successful terminal, and the state that reads wrong.
///
/// `done` is `isTerminal`, so the CTA is gone — correct. But `_stateAt` maps
/// `index == currentIndex` to `current`, and `done` IS the current index, so
/// the final stage renders in the ACTIVE styling (tertiary accent, `onSurface`
/// bold label) rather than the completed one. Combined with
/// `showCheckmark: false`, a finished delivery never shows a fully-completed
/// stepper: it shows four completed stages and a fifth that still looks like
/// work in progress. Read this card next to the `atDoor` one above — the only
/// difference is which circle is accented, not "in progress" versus "done".
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Done · last step still accented',
  size: _deliveryStatusStepperOnlyBox,
)
Widget deliveryStatusStepperDone() =>
    _deliveryStatusStepperHosted(JeeberDeliveryStatus.done);

/// The unsuccessful terminal: `cancelled` must paint NOTHING.
///
/// This is defence in depth rather than a reachable screen — `_ReadyView`
/// early-returns `_UnsuccessfulTerminalContent` before it ever builds this
/// section — and the guard is load-bearing: the private `stepIcon` and
/// `statusLabel` extensions both `throw StateError` for cancelled / expired /
/// disputed, so without the `isUnsuccessfulTerminal` shrink at the top of
/// `build` this state would not render badly, it would CRASH the jeeber's
/// active-delivery screen.
///
/// What the card should show is the section title and a 310 x 0 dp hole under
/// it. Anything else — a stage circle, a stray gap, a red overflow stripe —
/// means the shrink has been lost. (The empty titled card is what a future
/// caller that forgets the early return would ship; that is a screen-level
/// question, not this widget's.)
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Cancelled · paints nothing',
  size: _deliveryStatusStepperCollapsedBox,
)
Widget deliveryStatusStepperCancelled() =>
    _deliveryStatusStepperHosted(JeeberDeliveryStatus.cancelled);

