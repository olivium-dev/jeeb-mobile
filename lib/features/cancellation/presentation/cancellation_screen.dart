import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/cancellation_repository.dart';
import '../domain/cancellation_result.dart';
import 'cubit/cancellation_cubit.dart';
import 'cubit/cancellation_state.dart';
import 'widgets/cancellation_reason_group.dart';
import 'widgets/cancellation_success_sheet.dart';

import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/cancellation_screen_fixtures.dart';

/// Reason-picker screen (T-MOB-024); accessible from active delivery menu.
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

  /// Injectable for tests; production resolves via GetIt.
  final CancellationRepository? repository;

  /// DT-04 test seam: preset cubit state for screen preview (e.g. mid-submit).
  final CancellationState? initialState;

  /// Resolves via explicit override (tests) or GetIt. Using GetIt because
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
          appBar: OMDSAppBar(
            title: l10n.cancellationTitle,
            showBackButton: true,
          ),
          body: _Body(
            reasons: reasons,
            selectedReason: _selectedReason,
            otherController: _otherController,
            label: (r) => _label(r, l10n),
            onReasonChanged: (r) => setState(() => _selectedReason = r),
            onSubmit: () => _submit(context),
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
    required this.onSubmit,
  });

  final List<String> reasons;
  final String? selectedReason;
  final TextEditingController otherController;
  final String Function(String) label;
  final ValueChanged<String?> onReasonChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.medium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PromptText(text: l10n.cancellationReasonPrompt),
            const SizedBox(height: Spacing.medium),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
              ),
            ),
            const SizedBox(height: Spacing.medium),
            _SubmitButton(
              isEnabled: selectedReason != null,
              onSubmit: onSubmit,
            ),
          ],
        ),
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
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _OtherTextField extends StatelessWidget {
  const _OtherTextField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'cancellation_other_field',
      textField: true,
      child: OmdsTextField(
        controller: controller,
        labelText: l10n.cancellationOtherHint,
        maxLines: 3,
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.isEnabled, required this.onSubmit});

  final bool isEnabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<CancellationCubit, CancellationState>(
      builder: (context, state) {
        final loading = state is CancellationLoading;
        return Semantics(
          identifier: 'cancellation_submit_cta',
          container: true,
          button: true,
          child: OmdsPrimaryButton(
            text: loading
                ? l10n.deliveryActionCancellingLabel
                : l10n.cancellationConfirmButton,
            isEnabled: isEnabled && !loading,
            onTap: onSubmit,
          ),
        );
      },
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
const Size _cancellationScreenPhoneBox = Size(390, 844);

/// The narrowest viewport the app supports.
const Size _cancellationScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
final class CancellationScreenCaptions {
  CancellationScreenCaptions._();

  /// Four client reasons, nothing selected, Confirm disabled.
  static const String clientPicker = 'preview · client · nothing selected';

  /// The five Jeeber reasons no in-app route can reach.
  static const String jeeberPicker = 'preview · jeeber · nothing selected';

  /// The same Jeeber list on the 320x568 viewport.
  static const String compact = 'preview · jeeber · 320x568 viewport';

  /// `POST /v1/deliveries/{id}/cancel` in flight.
  static const String submitting = 'preview · confirm in flight';

  /// A seeded `CancellationError` — and the picture is unchanged.
  static const String rejected = 'preview · 5xx seeded · nothing renders';

  /// A seeded `CancellationTooLate` — likewise.
  static const String tooLate = 'preview · 409 seeded · nothing renders';
}

/// The delivery hub the cancel screen is pushed from, and pops back to.
class _CancellationScreenOrderStandIn extends StatelessWidget {
  const _CancellationScreenOrderStandIn();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('preview stand-in')),
      body: Center(
        child: Text(
          'delivery hub',
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [CancellationScreen] and captions the state.
class _CancellationScreenHost extends StatefulWidget {
  const _CancellationScreenHost({required this.state, required this.caption});

  /// The designed state, shared with the Screen Catalog.
  final CancellationScreenDesignedState state;

  /// The line painted above the device frame — see note 3 in the prose.
  final String caption;

  @override
  State<_CancellationScreenHost> createState() =>
      _CancellationScreenHostState();
}

class _CancellationScreenHostState extends State<_CancellationScreenHost> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/orders/${widget.state.deliveryId}/cancel',
    routes: <RouteBase>[
      GoRoute(
        path: '/orders/:id',
        builder: (_, _) => const _CancellationScreenOrderStandIn(),
        routes: <RouteBase>[
          GoRoute(
            path: 'cancel',
            builder: (_, _) => CancellationScreen(
              deliveryId: widget.state.deliveryId,
              isJeeber: widget.state.isJeeber,
              repository: widget.state.repository,
              initialState: widget.state.initialState,
            ),
          ),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.small,
            vertical: Spacing.xSmall,
          ),
          child: Text(
            widget.caption,
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Router.withConfig(config: _router)),
      ],
    );
  }
}

Widget _cancellationScreenHosted(
  CancellationScreenDesignedState state,
  String caption,
) =>
    _CancellationScreenHost(state: state, caption: caption);

/// The state every client opens: four reasons, none selected, Confirm
@JeebPreview(
  group: 'cancellation',
  name: 'Client · nothing selected',
  size: _cancellationScreenPhoneBox,
  matrix: true,
)
Widget cancellationScreenClientPicker() => _cancellationScreenHosted(
      cancellationScreenClientPickerState,
      CancellationScreenCaptions.clientPicker,
    );

/// The Jeeber's five reasons — the same screen, a list the app cannot show.
@JeebPreview(
  group: 'cancellation',
  name: 'Jeeber · nothing selected',
  size: _cancellationScreenPhoneBox,
  matrix: true,
)
Widget cancellationScreenJeeberPicker() => _cancellationScreenHosted(
      cancellationScreenJeeberPickerState,
      CancellationScreenCaptions.jeeberPicker,
    );

/// The tallest list on the shortest supported device, 320x568.
@JeebPreview(
  group: 'cancellation',
  name: 'Jeeber · compact 320x568',
  size: _cancellationScreenCompactBox,
)
Widget cancellationScreenCompact() => _cancellationScreenHosted(
      cancellationScreenJeeberPickerState,
      CancellationScreenCaptions.compact,
    );

/// `POST /v1/deliveries/{id}/cancel` in flight.
@JeebPreview(
  group: 'cancellation',
  name: 'Submitting · confirm in flight',
  size: _cancellationScreenPhoneBox,
)
Widget cancellationScreenSubmitting() => _cancellationScreenHosted(
      cancellationScreenSubmittingState,
      CancellationScreenCaptions.submitting,
    );

/// A seeded `CancellationError` — and this is what it looks like: nothing.
@JeebPreview(
  group: 'cancellation',
  name: 'Rejected · 5xx (seeded)',
  size: _cancellationScreenPhoneBox,
)
Widget cancellationScreenRejected() => _cancellationScreenHosted(
      cancellationScreenRejectedState,
      CancellationScreenCaptions.rejected,
    );

/// A seeded `CancellationTooLate` — invisible for the same reason.
@JeebPreview(
  group: 'cancellation',
  name: 'Too late · 409 (seeded)',
  size: _cancellationScreenPhoneBox,
)
Widget cancellationScreenTooLate() => _cancellationScreenHosted(
      cancellationScreenTooLateState,
      CancellationScreenCaptions.tooLate,
    );
