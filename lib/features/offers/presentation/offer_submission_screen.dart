import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/offer_submission_cubit.dart';
import '../domain/offer_submission_repository.dart';

/// Jeeber offer-submission form (T-MOB-030).
///
/// Route: /jeeber/requests/:id/offer
/// Wired to POST /v1/offers (Mockoon :3055).
///
/// On 200 → [onSubmitted] is called with the conversationId so the
/// caller can navigate to chat.
/// On 409 → [onRequestGone] is called so the caller can pop back to feed.
class OfferSubmissionScreen extends StatelessWidget {
  const OfferSubmissionScreen({
    super.key,
    required this.requestId,
    required this.submissionService,
    required this.onWithdrawn,
    this.onSubmitted,
    this.onRequestGone,
    this.repository,
  });

  final String requestId;

  /// Legacy stub service — kept for router compatibility; ignored in favour
  /// of [repository] when provided.
  // ignore: avoid_annotating_with_dynamic
  final dynamic submissionService;

  final VoidCallback onWithdrawn;

  /// Called on success with the conversationId so the router opens chat.
  final void Function(String conversationId)? onSubmitted;

  /// Called when the server returns 409 (request gone / race). The host
  /// should navigate back to the feed and show a snack.
  final VoidCallback? onRequestGone;

  /// Injectable for tests. Production gets one from DI via the router.
  final OfferSubmissionRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository;
    if (repo == null) {
      return _Stub(requestId: requestId, onWithdrawn: onWithdrawn);
    }
    return BlocProvider<OfferFormCubit>(
      create: (_) => OfferFormCubit(repository: repo),
      child: _OfferForm(
        requestId: requestId,
        onWithdrawn: onWithdrawn,
        onSubmitted: onSubmitted,
        onRequestGone: onRequestGone,
      ),
    );
  }
}

/// Fallback stub rendered when no repository is injected (legacy router path).
class _Stub extends StatelessWidget {
  const _Stub({required this.requestId, required this.onWithdrawn});

  final String requestId;
  final VoidCallback onWithdrawn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: OMDSAppBar(
        title: 'Submit Offer',
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: onWithdrawn,
        ),
      ),
      body: Center(child: Text('Loading offer form for $requestId…')),
    );
  }
}

class _OfferForm extends StatefulWidget {
  const _OfferForm({
    required this.requestId,
    required this.onWithdrawn,
    this.onSubmitted,
    this.onRequestGone,
  });

  final String requestId;
  final VoidCallback onWithdrawn;
  final void Function(String conversationId)? onSubmitted;
  final VoidCallback? onRequestGone;

  @override
  State<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends State<_OfferForm> {
  final _priceController = TextEditingController();
  final _etaController = TextEditingController();
  final _noteController = TextEditingController();
  final _priceFocus = FocusNode();
  final _etaFocus = FocusNode();
  final _noteFocus = FocusNode();

  double? _price;
  int? _eta;

  @override
  void dispose() {
    _priceController.dispose();
    _etaController.dispose();
    _noteController.dispose();
    _priceFocus.dispose();
    _etaFocus.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OfferFormCubit, OfferFormState>(
      listener: _onStateChange,
      builder: _buildBody,
    );
  }

  void _onStateChange(BuildContext context, OfferFormState state) {
    if (state.mode == OfferFormMode.success && state.conversationId != null) {
      widget.onSubmitted?.call(state.conversationId!);
    }
    if (state.mode == OfferFormMode.requestGone) {
      _showRequestGoneAndPop(context);
    }
    if (state.mode == OfferFormMode.error && state.errorMessage != null) {
      _showErrorSnack(context, state.errorMessage!);
      context.read<OfferFormCubit>().acknowledgeError();
    }
  }

  void _showRequestGoneAndPop(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // EXEMPT: OMDS exports no standalone toast/snackbar widget; showOmdsSnackbar
    // is the approved fleet pattern for transient error feedback.
    showOmdsSnackbar(context, message: l10n.offerSubmitRequestGone);
    widget.onRequestGone?.call();
    widget.onWithdrawn();
  }

  void _showErrorSnack(BuildContext context, String message) {
    // EXEMPT: OMDS exports no standalone toast/snackbar widget; showOmdsSnackbar
    // is the approved fleet pattern for transient error feedback.
    showOmdsSnackbar(context, message: message);
  }

  Widget _buildBody(BuildContext context, OfferFormState state) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.offerSubmitTitle,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onWithdrawn,
          tooltip: l10n.offerSubmitWithdrawTooltip,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PriceField(
              controller: _priceController,
              focusNode: _priceFocus,
              nextFocus: _etaFocus,
              error: state.priceError,
              onChanged: (v) => setState(() => _price = double.tryParse(v)),
            ),
            const SizedBox(height: Spacing.medium),
            _EtaField(
              controller: _etaController,
              focusNode: _etaFocus,
              nextFocus: _noteFocus,
              error: state.etaError,
              onChanged: (v) => setState(() => _eta = int.tryParse(v)),
            ),
            const SizedBox(height: Spacing.medium),
            _NoteField(
              controller: _noteController,
              focusNode: _noteFocus,
            ),
            const SizedBox(height: Spacing.xLarge),
            _SubmitButton(
              isLoading: state.isSubmitting,
              onTap: () => _onSubmitTapped(context),
            ),
          ],
        ),
      ),
    );
  }

  void _onSubmitTapped(BuildContext context) {
    context.read<OfferFormCubit>().submit(
          requestId: widget.requestId,
          priceUsd: _price,
          etaMinutes: _eta,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.controller,
    required this.focusNode,
    required this.nextFocus,
    required this.onChanged,
    this.error,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode nextFocus;
  final void Function(String) onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsTextField(
      controller: controller,
      focusNode: focusNode,
      labelText: l10n.offerSubmitPriceLabel,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => nextFocus.requestFocus(),
      prefixIcon: const Icon(Icons.attach_money),
      errorText: error,
      onChanged: onChanged,
    );
  }
}

class _EtaField extends StatelessWidget {
  const _EtaField({
    required this.controller,
    required this.focusNode,
    required this.nextFocus,
    required this.onChanged,
    this.error,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode nextFocus;
  final void Function(String) onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsTextField(
      controller: controller,
      focusNode: focusNode,
      labelText: l10n.offerSubmitEtaLabel,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      onSubmitted: (_) => nextFocus.requestFocus(),
      prefixIcon: const Icon(Icons.timer),
      errorText: error,
      onChanged: onChanged,
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsTextField(
      controller: controller,
      focusNode: focusNode,
      labelText: l10n.offerSubmitNoteLabel,
      maxLines: 3,
      maxLength: 200,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.done,
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.offerSubmitButtonSemantics,
      button: true,
      child: OmdsLoadingButton(
        text: l10n.offerSubmitButton,
        isLoading: isLoading,
        onTap: onTap,
      ),
    );
  }
}
