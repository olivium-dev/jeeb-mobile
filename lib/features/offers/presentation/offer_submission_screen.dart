import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/friendly_reference.dart';
import '../../../core/jeeb_commission.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_money_breakdown.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../wallet/domain/wallet_repository.dart';
import '../application/offer_submission_cubit.dart';
import '../domain/offer_eta_band.dart';
import '../domain/offer_submission_repository.dart';
import 'offer_composer_l10n.dart';
import 'widgets/jeeb_money_field.dart';

/// Structured Offer Composer — JM-045 (blueprint `offer-composer`, economics
/// layer G3). Route `/jeeber/requests/:id/offer` (name `jeeber-offer-submission`).
///
/// Replaces the old plain price/ETA/note form with the D-decided economics
/// surface (root id `offer_composer_root`), rebuilt on the redesign-2026-08
/// board (screen 17): in-body [JeebTopBar], money field with `±1` steppers,
/// three inline ETA pills, placeholder-only note, an untitled money breakdown,
/// the wallet strip and a docked CTA that restates what the Jeeber keeps.
///   * `offer_composer_order_ref`   — "ORD-…" header subtitle (AC3).
///   * `offer_composer_price_field` — the Jeeber's offer price.
///   * `offer_composer_offer_line`  — the bid, echoed in the breakdown.
///   * `offer_composer_fee_line`    — exact 10% platform fee (D37/D44).
///   * `offer_composer_net_line`    — **"You keep" = price − platform fee**
///     (redesign C2; it used to read "You earn (cash)" = the full price. The
///     cash the customer hands over is still the full offer — the fee is taken
///     from the prepaid wallet — but the net is now framed the way the board
///     and `netPerOffer` (`earnings_summary.dart:170`) already frame it, so the
///     composer and Earnings no longer disagree).
///   * `offer_composer_reserve_note`— reserve/charge/release copy (D1).
///   * `offer_composer_eta_dropdown`— the ETA row, bounded by the tier SLA band
///     (D14); inline options `offer_composer_eta_option_<i>` +
///     `offer_composer_eta_more_cta` → the full band as
///     `offer_composer_eta_sheet_option_<i>` — NOT free minutes.
///   * `offer_composer_wallet_strip`/`_wallet_topup_cta` — the balance strip.
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
  /// Digits and one decimal point — the gateway takes a decimal amount, and a
  /// keypad-typed `,` would fail `double.tryParse`.
  static final List<TextInputFormatter> _priceFormatters =
      <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];

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

  /// A price is only "entered" once it is a positive number — the CTA label,
  /// the breakdown and the `−1` floor all key off this.
  bool get _hasPrice => _price != null && _price! > 0;

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
        body: SafeArea(
          child: Column(
            children: [
              // TODO(redesign-24): the board's subtitle is
              // `ORD-… · Pharmacy run · ⚡ Flash`. This route carries only `:id`
              // (both call sites push pathParameters alone), so the items
              // summary and the tier are omitted rather than faked — see
              // wiring request WR-6.
              JeebTopBar.close(
                title: l10n.title,
                subtitle: _displayRef,
                subtitleIdentifier: 'offer_composer_order_ref',
                identifier: 'offer_composer_close_cta',
                leadingTooltip: l10n.closeTooltip,
                onLeadingPressed: widget.onWithdrawn,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    Spacing.xLarge,
                    Spacing.large,
                    Spacing.xLarge,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      JeebSectionLabel(l10n.priceSectionLabel),
                      const SizedBox(height: Spacing.small),
                      JeebMoneyField(
                        controller: _priceController,
                        currencyMark: l10n.currencyMark(_currency),
                        placeholder: l10n.pricePlaceholder,
                        errorText: state.priceError,
                        inputFormatters: _priceFormatters,
                        canDecrement: _hasPrice,
                        onChanged: (v) =>
                            setState(() => _price = double.tryParse(v)),
                        onStep: _stepPrice,
                        identifier: 'offer_composer_price_field',
                        decrementIdentifier: 'offer_composer_price_decrement',
                        incrementIdentifier: 'offer_composer_price_increment',
                        decrementSemanticLabel: l10n.priceDecrementLabel,
                        incrementSemanticLabel: l10n.priceIncrementLabel,
                      ),
                      const SizedBox(height: Spacing.medium),
                      JeebSectionLabel(
                        l10n.etaSectionLabel,
                        hint: l10n.etaCeilingHint(_etaBand.options.last),
                      ),
                      const SizedBox(height: Spacing.small),
                      _buildEtaRow(context, l10n, state),
                      const SizedBox(height: Spacing.medium),
                      _NoteField(controller: _noteController),
                      const SizedBox(height: Spacing.medium),
                      _buildBreakdown(l10n),
                      // JEBV4-176: no wallet snapshot → no strip. Never render
                      // a $0.00 balance the Jeeber might act on.
                      if (_wallet != null) ...[
                        const SizedBox(height: Spacing.small),
                        _buildWalletStrip(context, l10n, _wallet!),
                      ],
                    ],
                  ),
                ),
              ),
              JeebCtaFooter.single(
                child: JeebCtaButton.primary(
                  label: _sendLabel(l10n),
                  height: JeebCtaButton.primaryHeightTall,
                  isLoading: state.isSubmitting,
                  onTap: () => _onSendTapped(context),
                  identifier: 'offer_composer_send_cta',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `offer_composer_eta_dropdown` — the bounded ETA row (D14).
  ///
  /// The band's [OfferEtaBand.quickOptions] are drawn inline as
  /// `offer_composer_eta_option_<i>`; when the band is wider than those three a
  /// fourth pill opens the full list (and then renders the picked value, so a
  /// sheet-picked ETA stays visible).
  Widget _buildEtaRow(
    BuildContext context,
    OfferComposerL10n l10n,
    OfferFormState state,
  ) {
    final quick = _etaBand.quickOptions;
    final hasMore = _etaBand.options.length > quick.length;
    final showsPicked =
        hasMore && _selectedEta != null && !quick.contains(_selectedEta);

    final pills = <Widget>[
      for (var i = 0; i < quick.length; i++)
        JeebSelectChip(
          role: JeebChipRole.choice,
          label: l10n.etaOption(quick[i]),
          selected: quick[i] == _selectedEta,
          onTap: () => setState(() => _selectedEta = quick[i]),
          identifier: 'offer_composer_eta_option_$i',
        ),
      if (hasMore)
        JeebSelectChip(
          role: JeebChipRole.choice,
          label: showsPicked ? l10n.etaOption(_selectedEta!) : l10n.etaOther,
          selected: showsPicked,
          onTap: () => _openEtaPicker(context),
          identifier: 'offer_composer_eta_more_cta',
        ),
    ];

    // Equal-width pills are the board's shape, but a `choice` chip does not
    // ellipsize inside a tight Expanded — at large text scales four of them
    // cannot hold "40 min" / "٤٠ دقيقة". Past ~130% the row keeps the pills at
    // their natural width and scrolls instead (still a non-lazy Row, so every
    // identifier stays findable).
    final isTight = _isTightText(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          identifier: 'offer_composer_eta_dropdown',
          container: true,
          explicitChildNodes: true,
          // The frozen flows tap the row itself before tapping an option. With
          // four pills the row's centre falls in an 8px gap, so the container
          // must stay hit-testable for that tap to be a real no-op instead of a
          // hit-test failure. Colors.transparent is the one sanctioned literal.
          child: ColoredBox(
            color: Colors.transparent,
            child: isTight
                ? JeebChipRow.scrollable(children: pills)
                : JeebChipRow.expanded(children: pills),
          ),
        ),
        if (state.etaError != null) ...[
          const SizedBox(height: Spacing.xSmall),
          _EtaError(message: state.etaError!),
        ],
      ],
    );
  }

  /// The economics card. Before a price is entered the rows render explanatory
  /// sentences (no amounts) so the card reads as deliberate, never blank.
  Widget _buildBreakdown(OfferComposerL10n l10n) {
    if (!_hasPrice) {
      return JeebMoneyBreakdown(
        rows: [
          JeebMoneyLine(
            label: l10n.feeLinePending,
            identifier: 'offer_composer_fee_line',
          ),
        ],
        total: JeebMoneyLine(
          label: l10n.netLinePending,
          identifier: 'offer_composer_net_line',
        ),
        footnote: l10n.reserveNotePending,
        footnoteIdentifier: 'offer_composer_reserve_note',
      );
    }

    final price = _price!;
    final fee = _reserve!;
    final currency = _currency;
    return JeebMoneyBreakdown(
      rows: [
        JeebMoneyLine(
          label: l10n.offerRowLabel,
          value: l10n.money(price, currency),
          identifier: 'offer_composer_offer_line',
        ),
        JeebMoneyLine(
          label: l10n.feeRowLabel,
          value: l10n.negativeMoney(fee, currency),
          identifier: 'offer_composer_fee_line',
        ),
      ],
      total: JeebMoneyLine(
        label: l10n.keepRowLabel,
        value: l10n.money(price - fee, currency),
        identifier: 'offer_composer_net_line',
      ),
      footnote: l10n.reserveNote(l10n.money(fee, currency)),
      footnoteIdentifier: 'offer_composer_reserve_note',
    );
  }

  /// `offer_composer_wallet_strip` — the only orange on this screen is its
  /// `Top up` link (D92/D93 → wallet-charge-info). The snapshot is not
  /// re-fetched after a top-up round-trip; the 402 path stays authoritative.
  Widget _buildWalletStrip(
    BuildContext context,
    OfferComposerL10n l10n,
    WalletBalance wallet,
  ) {
    // The strip's trailing link takes its natural width, so at large text
    // scales the balance + link stop fitting the board's 12/16 inset. Tighten
    // the inset and the gap rather than dropping either half of the row.
    final isTight = _isTightText(context);
    return JeebInfoNote.accent(
      icon: Icons.account_balance_wallet,
      text: l10n.walletStrip(
        l10n.money(wallet.availableBalance, wallet.currency),
      ),
      linkLabel: l10n.walletTopUpCta,
      onLink: () => context.goNamed('wallet-charge-info'),
      padding: isTight
          ? const EdgeInsetsDirectional.all(Spacing.small)
          : null,
      gap: isTight ? Spacing.xSmall : null,
      identifier: 'offer_composer_wallet_strip',
      linkIdentifier: 'offer_composer_wallet_topup_cta',
    );
  }

  /// True when the ambient text scale has outgrown the board's single-line
  /// rows (~130%). Read from the `choice` pill size, the smallest of the two
  /// rows that break first.
  bool _isTightText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(_kEtaPillFontSize) >
          _kEtaPillFontSize * 1.3;

  /// The CTA restates what the Jeeber keeps once a price exists (board
  /// `tpl 1031`); before that it is the plain submit label.
  String _sendLabel(OfferComposerL10n l10n) {
    if (!_hasPrice) return l10n.sendCta;
    return l10n.sendCtaWithNet(l10n.money(_price! - _reserve!, _currency));
  }

  /// `±1` from the stepper pills. Floors at 0 — clearing the field rather than
  /// showing a zero bid; there is no ceiling (the gateway validates `> 0` only,
  /// so inventing one here would fabricate a product rule).
  void _stepPrice(int delta) {
    final next = (_price ?? 0) + delta;
    if (next <= 0) {
      setState(() => _price = null);
      _priceController.clear();
      return;
    }
    setState(() => _price = next);
    final text = _fmt(next);
    // Set the whole value (not just `.text`) so the caret lands after the
    // digits instead of collapsing to an invalid offset.
    _priceController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// The full band (D14) — every legal bid, not just the three inline pills.
  /// Rows carry `offer_composer_eta_sheet_option_<i>`: a distinct prefix,
  /// because the sheet opens over the inline pills and reusing `_option_<i>`
  /// would make both `find.bySemanticsIdentifier` and Maestro ambiguous.
  Future<void> _openEtaPicker(BuildContext context) async {
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
                padding: const EdgeInsetsDirectional.symmetric(
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
                  itemCount: _etaBand.options.length,
                  itemBuilder: (itemContext, i) {
                    final minutes = _etaBand.options[i];
                    return Semantics(
                      identifier: 'offer_composer_eta_sheet_option_$i',
                      button: true,
                      child: ListTile(
                        title: Text(l10n.etaOption(minutes)),
                        trailing: minutes == _selectedEta
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
    if (!mounted || picked == null) return;
    setState(() => _selectedEta = picked);
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

/// Max length of the optional offer note — mirrors the gateway `MaxNoteLength`
/// (`CreateOfferBody.note`, 500 chars). Enforced client-side so the Jeeber is
/// stopped before the gateway would 400 on note-too-long.
const int kOfferNoteMaxLength = 500;

/// The note input grows from [_kNoteFieldMinLines] up to [_kNoteFieldMaxLines]
/// visible lines before it scrolls internally.
const int _kNoteFieldMinLines = 2;
const int _kNoteFieldMaxLines = 4;

/// `JeebChipRole.choice`'s label size — read here only to decide when the ETA
/// row must stop being equal-width (see `_buildEtaRow`), never to style a chip.
const double _kEtaPillFontSize = 13.5;

/// The gateway `MaxNoteLength` guard, as a keystroke filter. It replaces
/// `maxLength:` because that also renders a character counter, which the board
/// does not draw. `LengthLimitingTextInputFormatter` has no const constructor,
/// so this is built once here rather than per build.
final List<TextInputFormatter> _noteFormatters = <TextInputFormatter>[
  LengthLimitingTextInputFormatter(kOfferNoteMaxLength),
];

/// `offer_composer_note_field` — the optional free-text offer description the
/// Jeeber attaches to the bid (wire field `note`).
///
/// The board draws a borderless filled block with a placeholder and **no
/// label and no character counter**, so the length cap moves from `maxLength:`
/// (which renders the counter) to an input formatter — the gateway guard is
/// unchanged — and the label becomes the field's a11y name on the wrapper. The
/// resting border is hidden by overriding one OMDS token; the focused 2px
/// primary border inside `OmdsTextField` is left alone.
class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = OfferComposerL10n.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'offer_composer_note_field',
      textField: true,
      label: l10n.noteLabel,
      child: OmdsColorTokensProvider(
        tokens: context.omdsColorTokens.copyWith(
          inputBorderColor: Colors.transparent,
        ),
        child: OmdsTextField(
          controller: controller,
          hintText: l10n.noteHint,
          fillColor: colorScheme.surfaceContainerHigh,
          borderRadius: UIConstants.borderRadiusLarge,
          minLines: _kNoteFieldMinLines,
          maxLines: _kNoteFieldMaxLines,
          inputFormatters: _noteFormatters,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          textCapitalization: TextCapitalization.sentences,
        ),
      ),
    );
  }
}

/// The ETA validation message. The `InputDecorator` that used to render it went
/// with the dropdown, so the row owns its own error line.
class _EtaError extends StatelessWidget {
  const _EtaError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: Spacing.twoXSmall),
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
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
