import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/friendly_reference.dart';
import '../../../core/jeeb_commission.dart';
import '../../wallet/domain/wallet_repository.dart';
import '../application/offer_submission_cubit.dart';
import '../domain/offer_eta_band.dart';
import '../domain/offer_submission_repository.dart';
import 'offer_composer_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../devtool/catalog/fixtures/offer_submission_screen_fixtures.dart';
import '../../../core/previews/jeeb_preview.dart';

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

  /// Reserve held against this offer = exactly the platform commission on the
  /// offer price (D1/D37) — flat 10%, per owner ruling Q-001.
  ///
  /// The rate is [kJeebCommissionRate], not a literal. This line used to spell
  /// `0.10` itself, which made it a second copy of a number the gateway is the
  /// authority on: `CommissionCalculator.FlatRate`. It is the copy that would
  /// have hurt most, too — it is what a Jeeber reads BEFORE deciding what to
  /// bid, so a stale rate here misprices the offer at the moment of commitment.
  double? get _reserve =>
      _price == null ? null : (_price! * kJeebCommissionRate);

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
        _snack(context, _errorText(l10n, state));
        context.read<OfferFormCubit>().acknowledgeError();
      case OfferFormMode.idle:
      case OfferFormMode.submitting:
        break;
    }
  }

  /// Localized error-snack copy. The offer-cap literal has no localized copy
  /// yet so it rides [OfferFormState.errorMessage]; everything else localizes
  /// off [OfferFormState.errorReason] so the ready Arabic copy isn't shadowed
  /// by a hardcoded English string (JEBV4-246).
  String _errorText(OfferComposerL10n l10n, OfferFormState state) {
    final literal = state.errorMessage;
    if (literal != null) return literal;
    return switch (state.errorReason) {
      OfferSubmissionFailure.network => l10n.errorNetwork,
      _ => l10n.errorGeneric,
    };
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
          leading: Semantics(
            identifier: 'offer_composer_close_cta',
            button: true,
            container: true,
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onWithdrawn,
              tooltip: l10n.closeTooltip,
            ),
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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/offers/offer_submission_screen_preview_test.dart
// ===========================================================================
//
// [OfferSubmissionScreen] is the JM-045 structured offer composer: an order-ref
// heading, a price field, a tier-bounded ETA picker, an optional 500-char note,
// the D37/D44/D1 economics card and one send CTA.
//
// The collaborators, the wallet snapshots and the cubit pre-drives are NOT
// declared here. They live in
// `lib/devtool/catalog/fixtures/offer_submission_screen_fixtures.dart`, shared
// with the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_07_entries.dart`), so the designer's in-app
// browser and this canvas cannot drift into showing two different "designed
// states". Nothing there can reach the network: every answer is a const value,
// a typed failure, or a `Completer` that is never completed.
//
// Four things about this harness are worth knowing before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and this
//    screen's `Scaffold + OMDSAppBar` paints inside it. Same nesting the Screen
//    Catalog produces.
//  * **The frame is pinned in the TREE, not just in `size:`.**
//    [_offerSubmissionScreenFramed] pins the same box the annotation asks for,
//    so a render test measures a phone rather than the 800x600 test surface.
//    The body scrolls, so only the WIDTH is load-bearing.
//  * **The price and the note are unreachable.** Both live in
//    `TextEditingController`s owned by the private `_OfferComposerState`, with
//    no ctor seam, so `_price` is null in every state that can be built without
//    typing — which is every state a static fixture can build. Consequence: the
//    fee / net / reserve lines render their PENDING copy on every card below,
//    and the wallet currency never appears. The economics layer this screen
//    exists for is only reviewable through the JM-046 sheet, which takes its
//    figures as arguments.
//  * **Four of the six `OfferFormMode`s have no still frame.** `success`,
//    `requestGone` and `error` are driven by the `BlocConsumer` *listener*, not
//    the builder — they route away or raise a snack and then
//    `acknowledgeError()` returns the composer to idle, so a cubit seeded into
//    one of them before mount renders pixel-for-pixel the idle composer (the
//    listener does not fire for an initial state). `insufficientBalance` opens
//    a modal, and that one IS worth looking at, so it is previewed as the sheet
//    itself rather than as a screen that cannot be made to show it.
//
// The states are the three the Screen Catalog names plus three it does not:
//
//   * **The 402 sheet** — the JM-046 surface, and the only place on this screen
//     where a real amount and a currency are rendered at all.
//   * **The order-ref pair** — the sprint-009 §T5 regression, both halves. One
//     card shows the shortening working; the compact ceiling shows the branch
//     it does not cover.
//   * **The compact 320 ceiling** — the longest heading the screen accepts, on
//     the narrowest phone the app supports.

/// The phone this screen is designed against.
const Size _offerSubmissionScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports (iPhone SE 1st-gen class), and
/// roughly what an Android multi-window split leaves a foreground app.
const Size _offerSubmissionScreenCompactBox = Size(320, 568);

/// A sheet is measured by how much of the phone it covers, not by a device.
const Size _offerSubmissionScreenSheetBox = Size(390, 520);

/// Pins [child] to a device-sized frame inside whatever box the host gives it.
Widget _offerSubmissionScreenFramed(Widget child, Size box) => Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: box.width, height: box.height, child: child),
    );

/// Mounts the composer the way `app_router.dart` mounts it, with the shared
/// fixtures standing in for both collaborators.
///
/// Passing [cubit] takes the `BlocProvider.value` branch and the `repository`
/// below is never resolved — it is supplied anyway so a future edit that drops
/// the pre-drive degrades to the idle composer instead of reaching DI.
Widget _offerSubmissionScreenHosted({
  required String requestId,
  OfferFormCubit? cubit,
  Size box = _offerSubmissionScreenPhoneBox,
}) =>
    _offerSubmissionScreenFramed(
      OfferSubmissionScreen(
        requestId: requestId,
        submissionService: const Object(),
        onWithdrawn: OfferSubmissionScreenPreviewFixtures.noop,
        onRequestGone: OfferSubmissionScreenPreviewFixtures.noop,
        repository: OfferSubmissionScreenPreviewFixtures.idleRepository,
        walletRepository: OfferSubmissionScreenPreviewFixtures.walletRepository,
        cubit: cubit,
      ),
      box,
    );

/// The composer's own money formatter — two decimals, no grouping, no symbol.
String _offerSubmissionScreenAmount(double value) => value.toStringAsFixed(2);

/// The reference reading: a fresh composer with nothing filled in.
///
/// This is what a jeeber lands on from the feed. Everything is at its
/// placeholder — the price field empty, the ETA reading "Select pickup ETA",
/// the note field showing its 0/500 counter — and the whole economics card is
/// in its pending phrasing because no price has been entered yet.
///
/// It is one of the two cards the matrix is for. The economics block is three
/// stacked icon+text rows whose copy is a full sentence each ("… reserved now
/// from your wallet · charged only if you win · released if you don't"), the AR
/// translations are longer than the EN, and at 200% they are most of the first
/// viewport. Read the AR RTL and 200% renderings — the English one stays
/// plausible long after the other two have stopped fitting.
@JeebPreview(
  group: 'offers',
  name: 'Idle · empty draft',
  size: _offerSubmissionScreenPhoneBox,
  matrix: true,
)
Widget offerSubmissionScreenIdle() => _offerSubmissionScreenHosted(
      requestId: OfferSubmissionScreenPreviewFixtures.requestId,
    );

/// `POST /requests/{id}/offers` in flight.
///
/// The send CTA swaps its label for a spinner and stops accepting taps; nothing
/// else on the screen changes. The price field, the ETA picker and the note
/// stay fully editable while the offer is being sent, and there is no way to
/// cancel — `OfferFormCubit.submit` has no timeout, so a request that never
/// answers leaves the composer here indefinitely. That is exactly what this
/// fixture holds still.
///
/// Note the economics card: it still reads "Platform fee: 10% of your offer"
/// even though a 15.00 offer is on the wire. That is the missing draft seam
/// described in the header, not a bug in the card — in production the jeeber
/// typed the price, so `_price` is set.
///
/// This is also the one preview whose render test cannot use `pumpAndSettle`:
/// the spinner is an indefinite animation, so the harness's settle would time
/// out. See the dedicated pump-once group in
/// `test/previews/offers/offer_submission_screen_preview_test.dart`.
@JeebPreview(
  group: 'offers',
  name: 'Submitting',
  size: _offerSubmissionScreenPhoneBox,
)
Widget offerSubmissionScreenSubmitting() => _offerSubmissionScreenHosted(
      requestId: OfferSubmissionScreenPreviewFixtures.submittingRequestId,
      cubit: OfferSubmissionScreenPreviewFixtures.submittingCubit(),
    );

/// Send pressed on an empty form: both inline validation errors at once.
///
/// `submit()` rejects a null price and a null ETA client-side and stays in
/// `idle`, so this is a *field* state rather than a mode — the price field
/// turns red under the label and the ETA `InputDecorator` grows an error line.
///
/// The strings are the reason this state is previewed rather than left to the
/// catalog. They are hardcoded English in `OfferFormCubit._validatePrice` /
/// `_validateEta`, so the AR rendering shows an Arabic form with two English
/// errors in it — the same class of defect JEBV4-246 fixed for the error snack
/// and did not fix here.
@JeebPreview(
  group: 'offers',
  name: 'Validation errors',
  size: _offerSubmissionScreenPhoneBox,
)
Widget offerSubmissionScreenValidationErrors() => _offerSubmissionScreenHosted(
      requestId: OfferSubmissionScreenPreviewFixtures.validationRequestId,
      cubit: OfferSubmissionScreenPreviewFixtures.validationErrorCubit(),
    );

/// The sprint-009 §T5 guard, made visible.
///
/// The feed hands this screen a raw gateway UUID, and the audit graded the
/// composer heading an F for echoing it. `_displayRef` now shortens anything
/// that is not already a human reference to a glanceable `ORD-<6>` tail, so
/// `9c37b6af-…-1f2a3b4c5d6e` reads as **ORD-4C5D6E**. If this card ever renders
/// the full identifier again, that fix has regressed.
///
/// Compare with [offerSubmissionScreenCompactCeiling], which feeds the same
/// identifier through the branch the fix does not cover.
@JeebPreview(
  group: 'offers',
  name: 'Order ref · opaque id (§T5)',
  size: _offerSubmissionScreenPhoneBox,
)
Widget offerSubmissionScreenOpaqueOrderRef() => _offerSubmissionScreenHosted(
      requestId: OfferSubmissionScreenPreviewFixtures.opaqueRequestId,
    );

/// `insufficient_balance_sheet` — the JM-046 402 surface (D92/D93).
///
/// The wallet cannot cover the 10% reserve, so the gateway answers 402 with
/// `{needed, available, currency}` and the composer opens this modal instead of
/// raising an error snack. The draft is preserved behind it: "Keep editing"
/// pops back to a filled composer, "Top up" routes to `wallet-charge-info`.
///
/// The sheet BODY is rendered here rather than driven through
/// `_showInsufficientSheet`, deliberately. The modal is reached only from the
/// `BlocConsumer` listener, which does not fire for a state a cubit already
/// carries at mount, so driving it would mean a preview that mutates itself
/// after the first frame — and `showModalBottomSheet` would push onto whatever
/// `Navigator` happens to be above the card, escaping the pinned frame. The
/// widget, its figures and its two CTAs are identical either way.
///
/// This is the only card on this screen that renders a real amount and a
/// currency at all — see the header on why the fee / net / reserve lines
/// cannot.
@JeebPreview(
  group: 'offers',
  name: 'Insufficient balance sheet · 402',
  size: _offerSubmissionScreenSheetBox,
  matrix: true,
)
Widget offerSubmissionScreenInsufficientBalance() {
  const InsufficientBalanceInfo info =
      OfferSubmissionScreenPreviewFixtures.shortfall;
  return _offerSubmissionScreenFramed(
    Align(
      alignment: Alignment.bottomCenter,
      child: _InsufficientBalanceSheet(
        needed: info.needed,
        available: info.available,
        currency: info.currency,
        fmt: _offerSubmissionScreenAmount,
      ),
    ),
    _offerSubmissionScreenSheetBox,
  );
}

/// The layout ceiling: the longest heading this screen accepts, at 320 pt.
///
/// `_displayRef` returns any id starting with `ORD` **verbatim** — the
/// shortening branch is never reached — so an already-prefixed reference is
/// rendered in full. `_OrderRefHeader` sets no `maxLines` and no `overflow`, so
/// a 40-character reference simply wraps, and at 320 pt with the AR copy and
/// 200% text it pushes the price field, the ETA picker and the economics card
/// down the scroll view.
///
/// This is the half of sprint-009 §T5 the fix does not cover:
/// [offerSubmissionScreenOpaqueOrderRef] carries the SAME identifier bare and
/// shortens it to `ORD-4C5D6E`; prefix it with `ORD-` and the raw reference is
/// back in the heading. Read the two side by side.
@JeebPreview(
  group: 'offers',
  name: 'Longest content · compact 320',
  size: _offerSubmissionScreenCompactBox,
  matrix: true,
)
Widget offerSubmissionScreenCompactCeiling() => _offerSubmissionScreenHosted(
      requestId: OfferSubmissionScreenPreviewFixtures.prefixedRequestId,
      box: _offerSubmissionScreenCompactBox,
    );
