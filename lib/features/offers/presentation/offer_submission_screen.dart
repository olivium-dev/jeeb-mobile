import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/friendly_reference.dart';
import '../../../core/jeeb_commission.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_radii.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_money_breakdown.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../core/widgets/jeeb/jeeb_surface_tone.dart';
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
/// surface (root id `offer_composer_root`), rebuilt on the MIDNIGHT board
/// (R17): in-body [JeebTopBar], money field with `±1` steppers, three inline
/// ETA pills, placeholder-only note, an untitled money breakdown, the wallet
/// strip and a docked ORANGE CTA that restates what the Jeeber keeps.
///
/// MIDNIGHT: R17 has **zero animated elements** (03-MOTION-NOTES), so the field
/// renders its rest frame (`animateDecor: false`). The orange budget is the
/// four moments the tile draws and no more: the price field's 2px stroke +
/// halo, the `You keep` figure (`onAccentContainer`, painted by
/// [JeebMoneyBreakdown]), the wallet strip's `Top up` link, and the CTA.
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
///     (D14); exactly three inline options `offer_composer_eta_option_<i>` —
///     NOT free minutes.
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
    // The board opens with the MIDDLE pill lit. A composer that opens with no
    // ETA fails its own validation on the first Send for no reason.
    final quick = _etaBand.quickOptions;
    _selectedEta = quick.isEmpty ? null : quick[quick.length ~/ 2];
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
        backgroundColor: Colors.transparent,
        body: JeebMidnightField(
          variant: JeebFieldVariant.content,
          glowPlacement: JeebFieldGlowPlacement.topStart,
          // R17 draws 0 animated elements (03-MOTION-NOTES): rest frame only.
          animateDecor: false,
          child: SafeArea(child: _buildContent(context, l10n, state)),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    OfferComposerL10n l10n,
    OfferFormState state,
  ) {
    return Column(
      children: [
        // TODO(midnight): omitted — the board's subtitle is
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
                  errorText: state.priceError == null
                      ? null
                      : l10n.priceRequiredError,
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
        // The board draws this pill ORANGE (`#D73B00`, h58) with the
        // ctaOrange glow — the tile-drawn act, so `.accent`, not primary.
        JeebCtaFooter.single(
          child: JeebCtaButton.accent(
            label: _sendLabel(l10n),
            height: JeebCtaButton.primaryHeightTall,
            isLoading: state.isSubmitting,
            onTap: () => _onSendTapped(context),
            identifier: 'offer_composer_send_cta',
          ),
        ),
      ],
    );
  }

  /// `offer_composer_eta_dropdown` — the bounded ETA row (D14).
  ///
  /// EXACTLY the three [OfferEtaBand.quickOptions], as
  /// `offer_composer_eta_option_<i>`. The `Other` pill and its full-band sheet
  /// are gone: the board draws three pills and no fourth affordance, and
  /// neither `offer_composer_eta_more_cta` nor `_eta_sheet_option_<i>` was ever
  /// frozen (both were coined by the pass-1 lane; no test or Maestro flow
  /// names either). The band still bounds the offer — `quickOptions` is derived
  /// from it, so nothing unselectable is ever offered.
  Widget _buildEtaRow(
    BuildContext context,
    OfferComposerL10n l10n,
    OfferFormState state,
  ) {
    final quick = _etaBand.quickOptions;
    final pills = <Widget>[
      for (var i = 0; i < quick.length; i++)
        JeebSelectChip(
          role: JeebChipRole.choice,
          label: l10n.etaOption(quick[i]),
          selected: quick[i] == _selectedEta,
          onTap: () => setState(() => _selectedEta = quick[i]),
          identifier: 'offer_composer_eta_option_$i',
        ),
    ];

    // Equal-width pills are the board's shape, but a `choice` chip does not
    // ellipsize inside a tight Expanded — at large text scales three of them
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
          // The frozen flows tap the row itself before tapping an option, so
          // the container stays hit-testable whatever falls under its centre.
          // Colors.transparent is the one sanctioned literal.
          child: ColoredBox(
            color: Colors.transparent,
            child: isTight
                ? JeebChipRow.scrollable(children: pills)
                : JeebChipRow.expanded(children: pills),
          ),
        ),
        if (state.etaError != null) ...[
          const SizedBox(height: Spacing.xSmall),
          _EtaError(message: l10n.etaRequiredError),
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

  /// `offer_composer_wallet_strip` — the board's glass strip, whose trailing
  /// `Top up` link is one of this screen's four orange moments (D92/D93 →
  /// wallet-charge-info). The snapshot is not re-fetched after a top-up
  /// round-trip; the 402 path stays authoritative.
  ///
  /// [JeebInfoNote]'s trailing slot takes its NATURAL width beside an
  /// `Expanded` body, so at 200% AR the Ø17 glyph + `إضافة رصيد` alone are
  /// wider than the strip and the kit's `Row` overflows. Past ~130% the copy
  /// and the link therefore move into the body slot as a `Wrap`, which lets
  /// the link fall to a second run instead of truncating either string.
  Widget _buildWalletStrip(
    BuildContext context,
    OfferComposerL10n l10n,
    WalletBalance wallet,
  ) {
    final isTight = _isTightText(context);
    final balance = l10n.walletStrip(
      l10n.money(wallet.availableBalance, wallet.currency),
    );
    void openTopUp() => context.goNamed('wallet-charge-info');

    return JeebInfoNote.accent(
      icon: Icons.account_balance_wallet,
      text: isTight ? null : balance,
      label: isTight
          ? _WalletStripWrap(
              balance: balance,
              linkLabel: l10n.walletTopUpCta,
              onTopUp: openTopUp,
            )
          : null,
      linkLabel: isTight ? null : l10n.walletTopUpCta,
      onLink: isTight ? null : openTopUp,
      padding: isTight
          ? const EdgeInsetsDirectional.all(Spacing.small)
          : null,
      gap: isTight ? Spacing.xSmall : null,
      identifier: 'offer_composer_wallet_strip',
      linkIdentifier: isTight ? null : 'offer_composer_wallet_topup_cta',
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
/// The board draws a placeholder-only block with **no label and no character
/// counter**, so the length cap rides an input formatter (the gateway guard is
/// unchanged) and the label becomes the field's a11y name on the wrapper.
///
/// MIDNIGHT: fill / border / hint ink now come from the Midnight OMDS token set
/// (`glassFill` + 1px `glassBorder` + `inkMuted`) — the R15 recipe — so the
/// screen no longer overrides `fillColor` or blanks the border token.
///
/// **R17 does not draw this block at all**, but the `note` field is real wire
/// capability (`CreateOfferBody.note`) with a frozen identifier, and study-notes
/// ground rule 6 puts frozen identifiers above tile-count fidelity (the R16
/// extra-bands ruling). It stays, restyled.
class _NoteField extends StatelessWidget {
  const _NoteField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = OfferComposerL10n.of(context);
    return Semantics(
      identifier: 'offer_composer_note_field',
      textField: true,
      label: l10n.noteLabel,
      child: OmdsTextField(
        controller: controller,
        hintText: l10n.noteHint,
        borderRadius: JeebRadii.lg,
        minLines: _kNoteFieldMinLines,
        maxLines: _kNoteFieldMaxLines,
        inputFormatters: _noteFormatters,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        textCapitalization: TextCapitalization.sentences,
      ),
    );
  }
}

/// The balance + `Top up` link folded into [JeebInfoNote]'s body slot at large
/// text scales, so the link wraps to its own run instead of overflowing the
/// kit's `Row` (see `_buildWalletStrip`). Ink and weights mirror the note's own
/// `accent` tone so the two forms read identically.
class _WalletStripWrap extends StatelessWidget {
  const _WalletStripWrap({
    required this.balance,
    required this.linkLabel,
    required this.onTopUp,
  });

  final String balance;
  final String linkLabel;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    final text = context.jeebText;
    final tone = JeebSurfaceTone.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Spacing.small,
      runSpacing: Spacing.twoXSmall,
      children: [
        Text(
          balance,
          style: text.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: tone.titleInk,
            height: JeebInfoNote.bodyLineHeight,
          ),
        ),
        Semantics(
          identifier: 'offer_composer_wallet_topup_cta',
          button: true,
          container: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTopUp,
            child: Text(
              linkLabel,
              style: text.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: context.jeebRoles.accent,
              ),
            ),
          ),
        ),
      ],
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
    final text = context.jeebText;
    final tone = JeebSurfaceTone.of(context);
    return Semantics(
      identifier: 'insufficient_balance_sheet',
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.xLarge,
          Spacing.xSmall,
          Spacing.xLarge,
          Spacing.large,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.insufficientTitle,
              style: text.h2.copyWith(color: tone.titleInk),
            ),
            const SizedBox(height: Spacing.xSmall),
            Text(
              l10n.insufficientBody,
              style: text.body.copyWith(color: tone.mutedInk),
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
            // EDGE: insufficient-balance → wallet-charge-info (D92/D93, JM-046
            // AC2). Pop first so a back from charge-info keeps the draft.
            JeebCtaButton.accent(
              label: l10n.insufficientTopUpCta,
              onTap: () {
                Navigator.of(context).pop();
                context.goNamed('wallet-charge-info');
              },
              identifier: 'insufficient_topup_cta',
            ),
            const SizedBox(height: Spacing.small),
            JeebCtaButton.outline(
              label: l10n.insufficientKeepEditingCta,
              onTap: () => Navigator.of(context).pop(),
              identifier: 'insufficient_keep_editing_cta',
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
    final tone = JeebSurfaceTone.of(context);
    return Row(
      children: [
        Icon(icon, size: Spacing.medium, color: tone.mutedInk),
        const SizedBox(width: Spacing.xSmall),
        Expanded(
          child: Text(
            text,
            style: context.jeebText.body.copyWith(
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: emphasize ? tone.titleInk : tone.mutedInk,
            ),
          ),
        ),
      ],
    );
  }
}
