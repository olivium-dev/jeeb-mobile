import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/cancellation_repository.dart';
import '../domain/cancellation_result.dart';
import 'cubit/cancellation_cubit.dart';
import 'cubit/cancellation_state.dart';
import 'widgets/cancellation_reason_group.dart';
import 'widgets/cancellation_success_sheet.dart';

/// Cancellation reason-picker and submission screen (T-MOB-024).
///
/// Accessible from the active delivery menu for both client and Jeeber roles.
/// Emits [onCancelled] with the result when the gateway returns 200.
///
/// redesign-2026-08 (unrendered screen, neighbour = 10 request-summary): a
/// re-skin onto the Jeeb kit, not a redesign. Same cubit, same reasons, same
/// submit, same copy — but the Material app bar becomes an in-body
/// [JeebTopBar], the reason radio-rows become selectable Jeeb cards (white +
/// 1.5px outline → navy fill when picked, the board's single-select language),
/// and the submit button docks in a [JeebCtaFooter] on the 24px gutter.
class CancellationScreen extends StatelessWidget {
  const CancellationScreen({
    super.key,
    required this.deliveryId,
    required this.isJeeber,
    this.repository,
    this.initialState,
  });

  final String deliveryId;
  final bool isJeeber;

  /// Injectable for widget tests; production resolves via DI.
  final CancellationRepository? repository;

  /// DT-04 screen-catalog / test seam: preset the cubit's initial state (e.g.
  /// [CancellationLoading]) so the screen can be previewed mid-submit. Null
  /// (default, production) starts idle exactly as before.
  final CancellationState? initialState;

  /// Resolves the repo: an explicit override (tests) → the GetIt-registered
  /// [DioCancellationRepository]. The `/orders/:id/cancel` route builder passes
  /// no `repository` and no `Provider<CancellationRepository>` exists in the
  /// widget tree (it lives only in GetIt), so reading it from `context`
  /// threw ProviderNotFoundException on every open (P0-CANCEL-CRASH). Resolve
  /// via `sl` — the same pattern SearchResultsScreen/NotificationsListScreen
  /// use for a DI-only repository.
  CancellationRepository _resolveRepository() =>
      repository ?? sl<CancellationRepository>();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CancellationCubit(
        _resolveRepository(),
        initialState: initialState,
      ),
      child: _CancellationView(
        deliveryId: deliveryId,
        isJeeber: isJeeber,
      ),
    );
  }
}

class _CancellationView extends StatefulWidget {
  const _CancellationView({
    required this.deliveryId,
    required this.isJeeber,
  });

  final String deliveryId;
  final bool isJeeber;

  @override
  State<_CancellationView> createState() => _CancellationViewState();
}

class _CancellationViewState extends State<_CancellationView> {
  String? _selectedReason;
  final _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  List<String> _reasons(AppLocalizations l10n) {
    if (widget.isJeeber) {
      return [
        'cannot_complete',
        'vehicle_issue',
        'emergency',
        'prohibited_item',
        'other',
      ];
    }
    return [
      'changed_mind',
      'wait_too_long',
      'wrong_address',
      'other',
    ];
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

  void _onStateChange(BuildContext context, CancellationState state) {
    if (state is CancellationSuccess) {
      _showSuccessSheet(context, state.result);
    } else if (state is CancellationTooLate) {
      showOmdsSnackbar(
        context,
        message: AppLocalizations.of(context).cancellationTooLate,
      );
    } else if (state is CancellationError) {
      showOmdsSnackbar(
        context,
        message: AppLocalizations.of(context).cancellationGenericError,
      );
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
    final reasons = _reasons(l10n);

    return BlocListener<CancellationCubit, CancellationState>(
      listener: _onStateChange,
      child: Semantics(
        identifier: 'cancellation_root',
        container: true,
        child: Scaffold(
          // The board's header is an in-body row, not a Material app bar, so
          // it shares the body's 24px gutter with the content beneath it.
          body: SafeArea(
            child: Column(
              children: [
                JeebTopBar.back(
                  identifier: 'cancellation_back',
                  title: l10n.cancellationTitle,
                ),
                Expanded(
                  child: _Body(
                    reasons: reasons,
                    selectedReason: _selectedReason,
                    otherController: _otherController,
                    label: (r) => _label(r, l10n),
                    onReasonChanged: (r) => setState(() => _selectedReason = r),
                  ),
                ),
                _SubmitFooter(
                  isEnabled: _selectedReason != null,
                  onSubmit: () => _submit(context),
                ),
              ],
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
      // 24px gutters; 16 under the top bar, 24 of breathing room before the
      // docked footer.
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.medium,
        Spacing.xLarge,
        Spacing.xLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PromptText(text: l10n.cancellationReasonPrompt),
          const SizedBox(height: Spacing.medium),
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
    return Text(
      text,
      // `titleProminent` (17/w700), not `h2`: the top bar already owns the
      // screen's 20/w700 line, so the question reads as its section headline.
      style: context.jeebText.titleProminent,
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
      child: OmdsTextField(
        controller: controller,
        labelText: l10n.cancellationOtherHint,
        maxLines: 3,
        // Aligns the field with the 16px reason-card radius rather than
        // OMDS's 12px default (§4.4).
        borderRadius: UIConstants.borderRadiusLarge,
      ),
    );
  }
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
          // The frozen id keeps its own node; the kit button's InkWell already
          // exposes the button role, so `button: true` stays on this wrapper
          // exactly as it shipped.
          child: Semantics(
            identifier: 'cancellation_submit_cta',
            container: true,
            button: true,
            child: JeebCtaButton.primary(
              // Copy is unchanged: the in-flight label is the existing
              // "Cancelling…" string, not the kit's label-replacing spinner.
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
