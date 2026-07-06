import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/friendly_reference.dart';
import '../../wallet/domain/wallet_repository.dart';
import '../application/offer_submission_cubit.dart';
import '../domain/offer_eta_band.dart';
import '../domain/offer_submission_repository.dart';
import 'offer_composer_l10n.dart';

/// Structured Offer Composer — JM-045 (blueprint `offer-composer`, economics
/// layer G3). Route `/jeeber/requests/:id/offer` (name `jeeber-offer-submission`).
///
/// Replaces the old plain price/ETA/note form with the D-decided economics
/// surface (root id `offer_composer_root`):
///   * `offer_composer_order_ref`   — "Your offer · ORD-…" header (AC3).
///   * `offer_composer_price_field` — the Jeeber's offer price.
///   * `offer_composer_fee_line`    — exact 10% platform fee (D37/D44).
///   * `offer_composer_net_line`    — "You earn (cash)" net-per-offer (D44).
///   * `offer_composer_reserve_note`— reserve/charge/release copy (D1).
///   * `offer_composer_eta_dropdown`— pickup ETA bounded by the tier SLA band
///     (D14), options `offer_composer_eta_option_<i>` — NOT free minutes.
///   * `offer_composer_send_cta`    — submit.
///
/// On send (`POST /v1/offers`, O1):
///   * 201 (sufficient) → 10% reserved → route to the jeeber feed
///     (`jeeber_feed_root`, the DELIVERY tab) via `context.go('/')` — NOT chat
///     (AC4; differs from the legacy T-MOB-030 chat hand-off).
///   * 402 (insufficient) → `insufficient_balance_sheet` (JM-046, AC5) — the
///     draft is preserved.
///   * 409 → request-gone snack + back to feed.
///
/// Money lines read the wallet (W1m via [WalletRepository], seam-driven). The
/// constructor signature is unchanged so the integrator-owned router builder
/// (`app_router.dart`) compiles untouched; [onSubmitted]/[onRequestGone] are
/// retained for back-compat but the screen now owns its feed navigation.
class OfferSubmissionScreen extends StatelessWidget {
  const OfferSubmissionScreen({
    super.key,
    required this.requestId,
    required this.submissionService,
    required this.onWithdrawn,
    this.onSubmitted,
    this.onRequestGone,
    this.repository,
    this.walletRepository,
    this.cubit,
  });

  final String requestId;

  /// Legacy stub service — kept for router compatibility; ignored in favour
  /// of [repository].
  // ignore: avoid_annotating_with_dynamic
  final dynamic submissionService;

  final VoidCallback onWithdrawn;

  /// Retained for back-compat (legacy chat hand-off). The composer now routes
  /// to the feed itself on success (AC4), so this is only invoked as a fallback
  /// when the host wants the conversationId.
  final void Function(String conversationId)? onSubmitted;

  /// Retained for back-compat. The screen handles the 409 snack + feed return.
  final VoidCallback? onRequestGone;

  /// Offer repository. Injectable for tests; resolved from DI when omitted.
  final OfferSubmissionRepository? repository;

  /// Wallet read-model for the money lines (W1m). Injectable for tests;
  /// resolved from DI when omitted.
  final WalletRepository? walletRepository;

  /// DT-04 catalog/test seam: an already-constructed cubit to host verbatim
  /// (via `BlocProvider.value`), bypassing [repository]/DI entirely. Lets a
  /// caller pre-drive [OfferFormCubit.submit] (e.g. into `submitting` or a
  /// validation-error mode) before the screen ever mounts. Additive-only —
  /// null in every existing call site, which keeps building their own cubit
  /// from [repository] exactly as before.
  final OfferFormCubit? cubit;

  OfferSubmissionRepository _resolveOfferRepo() {
    if (repository != null) return repository!;
    // The integrator-owned router builder always passes `repository`; this
    // resolves it from DI for any host that omits the override.
    return sl<OfferSubmissionRepository>();
  }

  WalletRepository? _resolveWalletRepo() {
    if (walletRepository != null) return walletRepository;
    return sl.isRegistered<WalletRepository>() ? sl<WalletRepository>() : null;
  }

  @override
  Widget build(BuildContext context) {
    final providedCubit = cubit;
    final composer = _OfferComposer(
      requestId: requestId,
      walletRepository: _resolveWalletRepo(),
      onWithdrawn: onWithdrawn,
      onSubmitted: onSubmitted,
      onRequestGone: onRequestGone,
    );
    if (providedCubit != null) {
      return BlocProvider<OfferFormCubit>.value(
        value: providedCubit,
        child: composer,
      );
    }
    return BlocProvider<OfferFormCubit>(
      create: (_) => OfferFormCubit(repository: _resolveOfferRepo()),
      child: composer,
    );
  }
}

class _OfferComposer extends StatefulWidget {
  const _OfferComposer({
    required this.requestId,
    required this.walletRepository,
    required this.onWithdrawn,
    this.onSubmitted,
    this.onRequestGone,
  });

  final String requestId;
  final WalletRepository? walletRepository;
  final VoidCallback onWithdrawn;
  final void Function(String conversationId)? onSubmitted;
  final VoidCallback? onRequestGone;

  @override
  State<_OfferComposer> createState() => _OfferComposerState();
}

class _OfferComposerState extends State<_OfferComposer> {
  final _priceController = TextEditingController();

  /// Optional free-text offer description (wire field `note`). The trim /
  /// empty→null normalization happens at send time ([_onSendTapped]); the raw
  /// text lives here so the draft survives a 402 "keep editing" round-trip.
  final _noteController = TextEditingController();

  /// The tier SLA band (D14). Without the request's tier on the feed payload we
  /// use the widest catalog band so the picker is still bounded, not free-form.
  final OfferEtaBand _etaBand = OfferEtaBand.defaultBand();

  double? _price;
  int? _selectedEta;

  /// Wallet snapshot for the money lines (W1m). Best-effort: a fetch failure
  /// degrades the available-balance context to null (the lines still render
  /// from the entered price); it never blocks the composer (D35 is enforced by
  /// the cubit's network failure path, not here).
  WalletBalance? _wallet;
  bool _insufficientShown = false;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final repo = widget.walletRepository;
    if (repo == null) return;
    try {
      final balance = await repo.fetchBalance();
      if (mounted) setState(() => _wallet = balance);
    } catch (_) {
      // Best-effort — leave _wallet null; money lines fall back to price-only.
    }
  }

  @override
  void dispose() {
    _priceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Reserve held against this offer = exactly 10% of the offer price (D1/D37).
  double? get _reserve => _price == null ? null : (_price! * 0.10);

  /// The currency the money lines render in — the wallet's, else USD (the O1
  /// default; 42_GUARDRAILS_MOCK W1m).
  String get _currency => _wallet?.currency ?? 'USD';

  String _fmt(double v) => v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OfferFormCubit, OfferFormState>(
      listenWhen: (p, n) => p.mode != n.mode,
      listener: _onStateChange,
      builder: _buildBody,
    );
  }

  void _onStateChange(BuildContext context, OfferFormState state) {
    final l10n = OfferComposerL10n.of(context);
    switch (state.mode) {
      case OfferFormMode.success:
        // AC4: 10% reserved → route to the jeeber feed (jeeber_feed_root, the
        // DELIVERY tab) — NOT chat. `go('/')` re-roots the role-aware shell; a
        // jeeber lands on the DELIVERY (Dashboard) tab feed.
        widget.onSubmitted?.call(state.conversationId ?? widget.requestId);
        context.go('/');
      case OfferFormMode.requestGone:
        _snack(context, l10n.requestGone);
        widget.onRequestGone?.call();
        widget.onWithdrawn();
      case OfferFormMode.insufficientBalance:
        _showInsufficientSheet(context, state.insufficientBalance);
      case OfferFormMode.error:
        _snack(context, state.errorMessage ?? l10n.errorGeneric);
        context.read<OfferFormCubit>().acknowledgeError();
      case OfferFormMode.idle:
      case OfferFormMode.submitting:
        break;
    }
  }

  void _snack(BuildContext context, String message) {
    // EXEMPT: OMDS exports no standalone toast/snackbar widget; showOmdsSnackbar
    // is the approved fleet pattern for transient feedback (40_GUARDRAILS §8).
    showOmdsSnackbar(context, message: message);
  }

  Widget _buildBody(BuildContext context, OfferFormState state) {
    final l10n = OfferComposerL10n.of(context);
    return Semantics(
      identifier: 'offer_composer_root',
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.title,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onWithdrawn,
            tooltip: l10n.closeTooltip,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OrderRefHeader(reference: _displayRef),
              const SizedBox(height: Spacing.medium),
              _PriceField(
                controller: _priceController,
                error: state.priceError,
                onChanged: (v) => setState(() => _price = double.tryParse(v)),
              ),
              const SizedBox(height: Spacing.medium),
              _EtaDropdown(
                band: _etaBand,
                selected: _selectedEta,
                error: state.etaError,
                onPick: (m) => setState(() => _selectedEta = m),
              ),
              const SizedBox(height: Spacing.medium),
              _NoteField(controller: _noteController),
              const SizedBox(height: Spacing.large),
              _EconomicsCard(
                reserve: _reserve,
                price: _price,
                currency: _currency,
                fmt: _fmt,
              ),
              const SizedBox(height: Spacing.xLarge),
              _SendButton(
                isLoading: state.isSubmitting,
                onTap: () => _onSendTapped(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A human "ORD-…" reference derived from the requestId (the feed payload
  /// does not carry a separate order ref today — JM-045 route note). When the
  /// id already looks like an order ref it is shown verbatim; otherwise it is
  /// shortened to a glanceable `ORD-<6>` tail instead of echoing the full UUID
  /// (sprint-009 audit §T5: the composer heading leaked a raw `ORD-9C37B6AF-…`).
  String get _displayRef {
    final id = widget.requestId;
    if (id.trim().isEmpty) return 'ORD-—';
    if (id.toUpperCase().startsWith('ORD')) return id.toUpperCase();
    return friendlyReference(id, prefix: 'ORD-');
  }

  void _onSendTapped(BuildContext context) {
    _insufficientShown = false;
    final note = _noteController.text.trim();
    context.read<OfferFormCubit>().submit(
      requestId: widget.requestId,
      priceUsd: _price,
      etaMinutes: _selectedEta,
      note: note.isEmpty ? null : note,
    );
  }

  Future<void> _showInsufficientSheet(
    BuildContext context,
    InsufficientBalanceInfo? info,
  ) async {
    if (_insufficientShown) return;
    _insufficientShown = true;

    // Prefer the 402's figures; fall back to the wallet snapshot / computed
    // reserve so the sheet always shows a needed-vs-available pair.
    final needed = info?.needed ?? _reserve ?? 0.0;
    final available = info?.available ?? _wallet?.availableBalance ?? 0.0;
    final currency = info?.currency ?? _currency;

    await _InsufficientBalanceSheet.show(
      context,
      needed: needed,
      available: available,
      currency: currency,
      fmt: _fmt,
    );

    // Sheet dismissed (top-up routed away, or keep-editing) — clear the cubit's
    // sheet mode so a re-send re-opens it. Draft (controllers) is untouched.
    if (!mounted || !context.mounted) return;
    _insufficientShown = false;
    context.read<OfferFormCubit>().acknowledgeInsufficientBalance();
  }
}

/// `offer_composer_order_ref` — "Your offer · ORD-…" header (AC3).
class _OrderRefHeader extends StatelessWidget {
  const _OrderRefHeader({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    final l10n = OfferComposerL10n.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'offer_composer_order_ref',
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.orderRef(reference),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Spacing.twoXSmall),
          Text(
            l10n.intro,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Max length of the optional offer note — mirrors the gateway `MaxNoteLength`
/// (`CreateOfferBody.note`, 500 chars). Enforced client-side so the character
/// counter stops the Jeeber before the gateway would 400 on note-too-long.
const int kOfferNoteMaxLength = 500;

/// The note input grows from [_kNoteFieldMinLines] up to [_kNoteFieldMaxLines]
/// visible lines before it scrolls internally.
const int _kNoteFieldMinLines = 2;
const int _kNoteFieldMaxLines = 4;

/// `offer_composer_note_field` — the optional free-text offer description the
/// Jeeber attaches to the bid (wire field `note`). Multiline OMDS text field,
/// bounded at [kOfferNoteMaxLength] chars; label/hint are localized (EN/AR,
/// RTL-safe) via [OfferComposerL10n]. The trim / empty→null normalization
/// happens at [_OfferComposerState._onSendTapped], so this widget stays dumb.
class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = OfferComposerL10n.of(context);
    return Semantics(
      identifier: 'offer_composer_note_field',
      textField: true,
      child: OmdsTextField(
        controller: controller,
        labelText: l10n.noteLabel,
        hintText: l10n.noteHint,
        maxLength: kOfferNoteMaxLength,
        minLines: _kNoteFieldMinLines,
        maxLines: _kNoteFieldMaxLines,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }
}

/// `offer_composer_price_field` — the Jeeber's offer price.
class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.controller,
    required this.onChanged,
    this.error,
  });

  final TextEditingController controller;
  final void Function(String) onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = OfferComposerL10n.of(context);
    return Semantics(
      identifier: 'offer_composer_price_field',
      textField: true,
      child: OmdsTextField(
        controller: controller,
        labelText: l10n.priceLabel,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        textInputAction: TextInputAction.done,
        prefixIcon: const Icon(Icons.attach_money),
        errorText: error,
        onChanged: onChanged,
      ),
    );
  }
}

/// `offer_composer_eta_dropdown` — pickup ETA bounded by the tier SLA band
/// (D14). Tapping it opens a modal whose options each carry
/// `offer_composer_eta_option_<i>` (NOT free-form integer minutes).
class _EtaDropdown extends StatelessWidget {
  const _EtaDropdown({
    required this.band,
    required this.selected,
    required this.onPick,
    this.error,
  });

  final OfferEtaBand band;
  final int? selected;
  final ValueChanged<int> onPick;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = OfferComposerL10n.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final label = selected == null
        ? l10n.etaPlaceholder
        : l10n.etaOption(selected!);

    return Semantics(
      identifier: 'offer_composer_eta_dropdown',
      button: true,
      child: InkWell(
        borderRadius: OmdsBorderRadius.medium,
        onTap: () => _openPicker(context),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: l10n.etaLabel,
            prefixIcon: const Icon(Icons.timer_outlined),
            suffixIcon: const Icon(Icons.arrow_drop_down),
            errorText: error,
            border: const OutlineInputBorder(),
          ),
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: selected == null
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final l10n = OfferComposerL10n.of(context);
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.medium,
                  vertical: Spacing.small,
                ),
                child: Text(
                  l10n.etaSheetTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: band.options.length,
                  itemBuilder: (itemContext, i) {
                    final minutes = band.options[i];
                    return Semantics(
                      identifier: 'offer_composer_eta_option_$i',
                      button: true,
                      child: ListTile(
                        title: Text(l10n.etaOption(minutes)),
                        trailing: minutes == selected
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () => Navigator.of(itemContext).pop(minutes),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null) onPick(picked);
  }
}

/// The economics block: fee (10%), net-per-offer, and the reserve note. Each
/// line carries its own Semantics identifier (AC1).
class _EconomicsCard extends StatelessWidget {
  const _EconomicsCard({
    required this.reserve,
    required this.price,
    required this.currency,
    required this.fmt,
  });

  final double? reserve;
  final double? price;
  final String currency;
  final String Function(double) fmt;

  @override
  Widget build(BuildContext context) {
    final l10n = OfferComposerL10n.of(context);
    final theme = Theme.of(context);
    final hasPrice = price != null && price! > 0;

    final feeText = hasPrice
        ? l10n.feeLine(fmt(reserve!), currency)
        : l10n.feeLinePending;
    final netText = hasPrice
        ? l10n.netLine(fmt(price!), currency)
        : l10n.netLinePending;
    final reserveText = hasPrice
        ? l10n.reserveNote(fmt(reserve!), currency)
        : l10n.reserveNotePending;

    return OMDSSectionCard(
      title: l10n.title,
      showDivider: false,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            identifier: 'offer_composer_fee_line',
            child: _EconLine(
              icon: Icons.percent,
              text: feeText,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: Spacing.small),
          Semantics(
            identifier: 'offer_composer_net_line',
            child: _EconLine(
              icon: Icons.payments_outlined,
              text: netText,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: Spacing.small),
          Semantics(
            identifier: 'offer_composer_reserve_note',
            child: _EconLine(
              icon: Icons.lock_clock_outlined,
              text: reserveText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EconLine extends StatelessWidget {
  const _EconLine({required this.icon, required this.text, this.style});

  final IconData icon;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: Spacing.medium,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: Spacing.xSmall),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}

/// `offer_composer_send_cta` — submit the offer.
class _SendButton extends StatelessWidget {
  const _SendButton({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = OfferComposerL10n.of(context);
    return Semantics(
      identifier: 'offer_composer_send_cta',
      button: true,
      child: OmdsLoadingButton(
        text: l10n.sendCta,
        isLoading: isLoading,
        onTap: onTap,
      ),
    );
  }
}

/// `insufficient_balance_sheet` — JM-046. Shows needed-vs-available, a top-up
/// CTA (→ wallet-charge-info, D92/D93) and a keep-editing CTA (dismiss, draft
/// preserved). A modal bottom sheet, not a route (40_GUARDRAILS §5).
class _InsufficientBalanceSheet extends StatelessWidget {
  const _InsufficientBalanceSheet({
    required this.needed,
    required this.available,
    required this.currency,
    required this.fmt,
  });

  final double needed;
  final double available;
  final String currency;
  final String Function(double) fmt;

  static Future<void> show(
    BuildContext context, {
    required double needed,
    required double available,
    required String currency,
    required String Function(double) fmt,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _InsufficientBalanceSheet(
        needed: needed,
        available: available,
        currency: currency,
        fmt: fmt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = OfferComposerL10n.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'insufficient_balance_sheet',
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.medium,
          Spacing.xSmall,
          Spacing.medium,
          Spacing.large,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.insufficientTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Spacing.xSmall),
            Text(
              l10n.insufficientBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.medium),
            Semantics(
              identifier: 'insufficient_balance_needed_amount',
              child: _AmountRow(
                icon: Icons.lock_clock_outlined,
                text: l10n.insufficientNeeded(fmt(needed), currency),
                emphasize: true,
              ),
            ),
            const SizedBox(height: Spacing.xSmall),
            Semantics(
              identifier: 'insufficient_balance_available_amount',
              child: _AmountRow(
                icon: Icons.account_balance_wallet_outlined,
                text: l10n.insufficientAvailable(fmt(available), currency),
              ),
            ),
            const SizedBox(height: Spacing.large),
            Semantics(
              identifier: 'insufficient_topup_cta',
              button: true,
              child: OmdsPrimaryButton(
                text: l10n.insufficientTopUpCta,
                // EDGE: insufficient-balance → wallet-charge-info (D92/D93,
                // JM-046 AC2). Pop the sheet first so a back from charge-info
                // returns to the composer with the draft intact.
                onTap: () {
                  Navigator.of(context).pop();
                  context.goNamed('wallet-charge-info');
                },
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'insufficient_keep_editing_cta',
              button: true,
              child: OmdsPrimaryButton(
                text: l10n.insufficientKeepEditingCta,
                variant: OmdsButtonVariant.outlined,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.icon,
    required this.text,
    this.emphasize = false,
  });

  final IconData icon;
  final String text;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: Spacing.medium, color: theme.colorScheme.primary),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
