import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_radii.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/cancellation_repository.dart';
import '../domain/cancellation_result.dart';
import 'cubit/cancellation_cubit.dart';
import 'cubit/cancellation_state.dart';
import 'widgets/cancellation_reason_group.dart';
import 'widgets/cancellation_success_sheet.dart';

/// Cancellation reason-picker and submission screen (T-MOB-024), for both the
/// client and the Jeeber. Emits the gateway result through a success sheet.
///
/// MIDNIGHT · M3-04 — the board never drew this screen; it is derived from R9
/// (the only single-select-then-confirm tile) with the destructive family
/// substituted wherever R9 spends its tile-drawn orange.
class CancellationScreen extends StatelessWidget {
  const CancellationScreen({
    super.key,
    required this.deliveryId,
    required this.isJeeber,
    this.repository,
    this.initialState,
    this.initialReason,
  });

  final String deliveryId;
  final bool isJeeber;

  /// Injectable for widget tests; production resolves via DI.
  final CancellationRepository? repository;

  /// DT-04 screen-catalog / test seam: preset the cubit's initial state so a
  /// mid-submit or terminal phase can be previewed. Null starts idle.
  final CancellationState? initialState;

  /// Same seam for the picker: pre-picks one reason code so the picked-row
  /// treatment is capturable. Null (production) opens with nothing chosen —
  /// a destructive act is never pre-selected.
  final String? initialReason;

  /// The `/orders/:id/cancel` builder passes no `repository` and no
  /// `Provider<CancellationRepository>` exists in the tree (it lives only in
  /// GetIt), so reading it from `context` threw on every open (P0-CANCEL-CRASH).
  CancellationRepository _resolveRepository() =>
      repository ?? sl<CancellationRepository>();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          CancellationCubit(_resolveRepository(), initialState: initialState),
      child: _CancellationView(
        deliveryId: deliveryId,
        isJeeber: isJeeber,
        initialReason: initialReason,
      ),
    );
  }
}

/// R9's measured body inset — 24 gutters, 12 under the top bar, 20 of air
/// before the docked footer.
const EdgeInsetsGeometry _bodyPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.small,
  Spacing.xLarge,
  Spacing.large,
);

/// The error strip shares the footer's 24 gutter and sits 12 above the pill.
const EdgeInsetsGeometry _errorStripPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  0,
  Spacing.xLarge,
  Spacing.small,
);

class _CancellationView extends StatefulWidget {
  const _CancellationView({
    required this.deliveryId,
    required this.isJeeber,
    this.initialReason,
  });

  final String deliveryId;
  final bool isJeeber;
  final String? initialReason;

  @override
  State<_CancellationView> createState() => _CancellationViewState();
}

class _CancellationViewState extends State<_CancellationView> {
  late String? _selectedReason = widget.initialReason;
  final _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  List<String> _reasons() {
    if (widget.isJeeber) {
      return [
        'cannot_complete',
        'vehicle_issue',
        'emergency',
        'prohibited_item',
        'other',
      ];
    }
    return ['changed_mind', 'wait_too_long', 'wrong_address', 'other'];
  }

  String _label(String reason, AppLocalizations l10n) {
    switch (reason) {
      case 'changed_mind':
        return l10n.cancellationReasonChangedMind;
      case 'wait_too_long':
        return l10n.cancellationReasonWaitTooLong;
      case 'wrong_address':
        return l10n.cancellationReasonWrongAddress;
      case 'cannot_complete':
        return l10n.cancellationReasonCantComplete;
      case 'vehicle_issue':
        return l10n.cancellationReasonVehicleIssue;
      case 'emergency':
        return l10n.cancellationReasonEmergency;
      case 'prohibited_item':
        return l10n.cancellationReasonProhibitedItem;
      default:
        return l10n.cancellationReasonOther;
    }
  }

  Future<void> _submit(BuildContext context) async {
    final reason = _selectedReason;
    if (reason == null) return;
    await context.read<CancellationCubit>().submit(
      deliveryId: widget.deliveryId,
      reason: reason,
      otherDetails: reason == 'other' ? _otherController.text : null,
    );
  }

  /// Only success leaves the screen. The 409 and 5xx lanes used to flash a
  /// snackbar and vanish; they are drawn states now.
  void _onStateChange(BuildContext context, CancellationState state) {
    if (state is CancellationSuccess) {
      _showSuccessSheet(context, state.result);
    }
  }

  void _showSuccessSheet(BuildContext context, CancellationResult result) {
    CancellationSuccessSheet.show(
      context: context,
      result: result,
      onDone: () {
        Navigator.of(context, rootNavigator: true).pop();
        context.pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reasons = _reasons();

    return BlocListener<CancellationCubit, CancellationState>(
      listener: _onStateChange,
      child: Semantics(
        identifier: 'cancellation_root',
        container: true,
        // R9's field: ONE orange radial at the top-start corner, no periwinkle
        // wash (R4/R9/R17 declare none), and the tile is STILL.
        child: JeebMidnightField(
          variant: JeebFieldVariant.content,
          glowPlacement: JeebFieldGlowPlacement.topStart,
          animateDecor: false,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  JeebTopBar.back(
                    identifier: 'cancellation_back',
                    title: l10n.cancellationTitle,
                  ),
                  Expanded(
                    child: BlocBuilder<CancellationCubit, CancellationState>(
                      builder: (context, state) => state is CancellationTooLate
                          ? _TooLateView(deliveryId: widget.deliveryId)
                          : _Body(
                              reasons: reasons,
                              selectedReason: _selectedReason,
                              otherController: _otherController,
                              label: (r) => _label(r, l10n),
                              onReasonChanged: (r) =>
                                  setState(() => _selectedReason = r),
                            ),
                    ),
                  ),
                  BlocBuilder<CancellationCubit, CancellationState>(
                    builder: (context, state) {
                      if (state is CancellationTooLate) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (state is CancellationError)
                            _ErrorStrip(kind: state.kind),
                          if (state.isTerminalRefusal)
                            JeebCtaFooter.single(
                              child: JeebCtaButton.primary(
                                identifier: 'cancellation_exit_cta',
                                label: l10n.actionBack,
                                onTap: () => context.canPop()
                                    ? context.pop()
                                    : context.go('/'),
                              ),
                            )
                          else
                            _SubmitFooter(
                              isEnabled: _selectedReason != null,
                              onSubmit: () => _submit(context),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.reasons,
    required this.selectedReason,
    required this.otherController,
    required this.label,
    required this.onReasonChanged,
  });

  final List<String> reasons;
  final String? selectedReason;
  final TextEditingController otherController;
  final String Function(String) label;
  final ValueChanged<String?> onReasonChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: _bodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PromptText(text: l10n.cancellationReasonPrompt),
          const SizedBox(height: Spacing.small),
          CancellationReasonGroup(
            reasons: reasons,
            selectedReason: selectedReason,
            labelOf: label,
            onChanged: onReasonChanged,
          ),
          if (selectedReason == 'other') ...[
            const SizedBox(height: Spacing.small),
            _OtherTextField(controller: otherController),
          ],
        ],
      ),
    );
  }
}

class _PromptText extends StatelessWidget {
  const _PromptText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    // `titleProminent` (17/w700), not `h2`: the top bar already owns the
    // screen's 20/w700 line, so the question reads as its section headline.
    return Text(
      text,
      style: context.jeebText.titleProminent.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class _OtherTextField extends StatelessWidget {
  const _OtherTextField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Identifier on a wrapping node so Maestro can locate the free-text "other"
    // reason input; the field owns its own editable semantics underneath.
    return Semantics(
      identifier: 'cancellation_other_field',
      textField: true,
      label: l10n.cancellationOtherHint,
      child: OmdsTextField(
        controller: controller,
        // R15/R17's Midnight recipe: a hint rather than a floating Material
        // label, with fill/border/hint ink from the Midnight OMDS token set.
        hintText: l10n.cancellationOtherHint,
        borderRadius: JeebRadii.lg,
        minLines: 3,
        maxLines: 4,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }
}

/// The 409 lane: the delivery is already moving, so the picker has nothing left
/// to offer. E3's night street is the only variant whose subject is a courier
/// on the road.
class _TooLateView extends StatelessWidget {
  const _TooLateView({required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A terminal kind gets a way ONWARD, never a Retry that cannot win: the
    // view was a dead end with no act at all.
    return Center(
      child: JeebEmptyState(
        variant: JeebEmptyStateVariant.street,
        identifier: 'cancellation_too_late',
        headline: l10n.cancellationTooLateHeadline,
        body: l10n.cancellationTooLateBody,
        reason: JeebEmptyStateReason.notFound,
        action: JeebCtaButton.primary(
          label: l10n.cancellationTooLateTrackCta,
          identifier: 'cancellation_too_late_track_cta',
          expand: false,
          onTap: () => context.go('/orders/$deliveryId/track'),
        ),
        secondaryAction: JeebCtaButton.text(
          label: l10n.escalateTitle,
          identifier: 'cancellation_too_late_escalate_cta',
          expand: false,
          onTap: () => context.go('/orders/$deliveryId/escalate'),
        ),
      ),
    );
  }
}

/// The 5xx lane, docked above the CTA so the selection stays live and a retry
/// is one tap away — R11's error-banner treatment.
class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip({required this.kind});

  final CancellationFailure? kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: _errorStripPadding,
      child: JeebInfoNote.error(
        identifier: 'cancellation_error_note',
        icon: Icons.error,
        text: _copy(l10n),
      ),
    );
  }

  String _copy(AppLocalizations l10n) => switch (kind) {
    CancellationFailure.reasonRequired => l10n.cancellationErrorReasonRequired,
    CancellationFailure.notAParty => l10n.cancellationErrorNotAParty,
    CancellationFailure.forbidden => l10n.errorForbiddenBody,
    CancellationFailure.network ||
    CancellationFailure.timeout => l10n.cancellationErrorNetwork,
    CancellationFailure.rateLimited => l10n.errorRateLimitedBody,
    CancellationFailure.tooLate => l10n.cancellationTooLateBody,
    CancellationFailure.server ||
    CancellationFailure.unknown ||
    null => l10n.cancellationErrorNote,
  };
}

class _SubmitFooter extends StatelessWidget {
  const _SubmitFooter({required this.isEnabled, required this.onSubmit});

  final bool isEnabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<CancellationCubit, CancellationState>(
      builder: (context, state) {
        final loading = state is CancellationLoading;
        return JeebCtaFooter.single(
          child: Semantics(
            identifier: 'cancellation_submit_cta',
            container: true,
            button: true,
            // NOT the accent pill: R9 spends orange on `Continue` because its
            // tile draws it, and no tile draws this destructive act at all.
            child: JeebCtaButton.outline(
              label: loading
                  ? l10n.deliveryActionCancellingLabel
                  : l10n.cancellationConfirmButton,
              isEnabled: isEnabled && !loading,
              onTap: onSubmit,
            ),
          ),
        );
      },
    );
  }
}
