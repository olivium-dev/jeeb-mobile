import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/server_time.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_radii.dart';
import '../../../core/theme/jeeb_shadows.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../application/transaction_detail_cubit.dart';
import '../application/transaction_detail_state.dart';
import '../data/stub_wallet_transaction_repository.dart';
import '../domain/wallet_ledger_repository.dart';
import '../domain/wallet_transaction_repository.dart';
import 'transaction_detail_l10n.dart';
import 'widgets/wallet_state_mark.dart';

/// Shares the ledger list's empty-family composition — see `_kStateArt` there:
/// R19's `e1` frame with the client mic and shopping medallions replaced by a
/// glass money mark, so a read-only money surface spends no orange.
const JeebEmptyStateVariant _kStateArt = JeebEmptyStateVariant.e1;
const List<JeebEmptyMedallion> _kNoMedallions = <JeebEmptyMedallion>[];

/// transaction-detail (JM-056). Per-type detail of a single ledger row reached
/// from wallet-activity-list (JM-055, `wallet_activity_row_<id>` tap):
///   * Fee-won shows the EXACT 10% rate + the pinned accepted price (D37).
///   * Refund / Penalty carry a dispute reference + a dispute link (D2).
///   * Reserve / Released / Top up / Gift each render their own copy (D1/D41).
///
/// Data: reads the row via `sl<WalletTransactionRepository>()` over W3m
/// `GET /v1/jeeb/wallet/ledger/:id` (LIVE on :4010; the DI default is the
/// INTEGRATOR-STUB until repointed to `DioWalletTransactionRepository`, CTO-D2 —
/// REQUESTED in 50_ROUTE_REQUESTS.md). The screen renders whatever row the repo
/// returns; the per-type Maestro states surface once DI is on the live endpoint.
///
/// Outbound edges (21_NAV_PLAN §C, JM-056):
///   `txn_detail_order_link`   → order-summary-pinned (`/orders/:id/summary`,
///                               the optional CTO-D3 deep-link route) — shown for
///                               reserve / fee_won / released rows with an order.
///   `txn_detail_dispute_link` → dispute-open-evidence (`/orders/:id/escalate`,
///                               JM-060) — shown for refund / penalty rows (D2).
///
/// Semantics ids placed (30_BACKLOG JM-056):
///   `txn_detail_root`         — screen host container
///   `txn_detail_back`         — the top bar's leading circle
///   `txn_detail_order_link`   — → order-summary-pinned
///   `txn_detail_dispute_link` — → dispute-open-evidence
///
/// MIDNIGHT (M3-12): a re-skin, not a rewrite — same route, same 4-state
/// machine, same fields in the same order, every frozen identifier unmoved. The
/// board never drew this screen; it is DERIVED from R4 (`04-r4-wallet.png`), the
/// hub two steps up, whose treatment `wallet_hub_screen.dart` already ships:
/// the same two radials on the same anchors (ORANGE glow top-start, PERIWINKLE
/// wash end-side at mid-height), and R4's own frosted bank-card — hero glass at
/// `xl`, a real blur, the board's `floatNav` lift — carried onto the one number
/// this screen exists to state.
///
/// R4's caption rations the orange to the single money ACT ("Top up"), so this
/// read-only leaf spends none: the hub's corner glow is not carried, and the
/// value ink that used to be `colorScheme.primary` (which under Midnight IS
/// `#D73B00`) is back on `onSurface`.
class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
    this.repository,
  });

  /// The ledger row id from the `/wallet/transactions/:id` path param.
  final String transactionId;

  /// Constructor test seam (40_GUARDRAILS_ARCH §5.4) — defaults to DI.
  final WalletTransactionRepository? repository;

  /// Resolves the repo: an explicit override (tests) → the registered LIVE
  /// `DioWalletTransactionRepository`/INTEGRATOR-STUB → the const stub when GetIt
  /// is not configured (router-resolution widget tests). Mirrors
  /// `WalletActivityListScreen._resolveRepository()`.
  WalletTransactionRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<WalletTransactionRepository>()) {
      return sl<WalletTransactionRepository>();
    }
    return const StubWalletTransactionRepository();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TransactionDetailCubit>(
      create: (_) => TransactionDetailCubit(
        repository: _resolveRepository(),
        transactionId: transactionId,
      )..load(),
      child: const _TransactionDetailView(),
    );
  }
}

class _TransactionDetailView extends StatelessWidget {
  const _TransactionDetailView();

  @override
  Widget build(BuildContext context) {
    final copy = TransactionDetailL10n.of(context);
    return Semantics(
      // JM-055 AC3 / JM-056 assert `txn_detail`; the unit test asserts the
      // legacy `txn_detail_root`. Nest both so neither regresses.
      identifier: 'txn_detail',
      container: true,
      explicitChildNodes: true,
      child: Semantics(
        identifier: 'txn_detail_root',
        container: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // R4's two radials, carried from the hub — separate layers, separate
          // anchors, neither animated (03-MOTION-NOTES §R4).
          body: JeebMidnightField(
            variant: JeebFieldVariant.content,
            glowPlacement: JeebFieldGlowPlacement.topStart,
            washPlacement: JeebFieldWashPlacement.endMid,
            animateDecor: false,
            // The header is an in-body row, not a Material app bar, so it
            // renders in EVERY state (loading / failed / loaded) and carries the
            // board's 24px gutter instead of a centred M3 title.
            child: SafeArea(
              child: Column(
                children: [
                  JeebTopBar(
                    identifier: 'txn_detail_back',
                    title: copy.title,
                    leadingTooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    // Normally pushed from wallet-activity-list's
                    // `wallet_activity_row_<id>` tap, but also reachable via deep
                    // link with an empty Navigator stack. Pop when we can (pushed
                    // entry), else return to the shell — never pop the last page
                    // (which would leave an empty Navigator → black surface).
                    onLeadingPressed: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                  ),
                  Expanded(
                    child:
                        BlocBuilder<
                          TransactionDetailCubit,
                          TransactionDetailState
                        >(
                          builder: (context, state) {
                            switch (state.status) {
                              case TransactionDetailStatus.initial:
                              case TransactionDetailStatus.loading:
                                return _StateBlock(
                                  status: JeebEmptyStateStatus.loading,
                                  headline: copy.loadingHeadline,
                                );
                              case TransactionDetailStatus.failed:
                                return _errorBlock(
                                  context,
                                  copy,
                                  _errorCopy(copy, state.error),
                                );
                              case TransactionDetailStatus.loaded:
                                final txn = state.transaction;
                                if (txn == null) {
                                  return _errorBlock(
                                    context,
                                    copy,
                                    copy.loadErrorGeneric,
                                  );
                                }
                                return _LoadedBody(txn: txn, copy: copy);
                            }
                          },
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The failure twin of the loading block, with the retry as its CTA.
  /// The mapped failure sentence is the body under the short `h1` title.
  Widget _errorBlock(
    BuildContext context,
    TransactionDetailL10n copy,
    String body,
  ) {
    return _StateBlock(
      status: JeebEmptyStateStatus.error,
      glyph: Icons.cloud_off,
      headline: copy.errorTitle,
      body: body,
      action: JeebCtaButton.primary(
        label: copy.retry,
        expand: false,
        onTap: () => context.read<TransactionDetailCubit>().retry(),
      ),
    );
  }

  String _errorCopy(
    TransactionDetailL10n copy,
    WalletTransactionFailure? failure,
  ) {
    switch (failure) {
      case WalletTransactionFailure.notFound:
        return copy.loadErrorNotFound;
      case WalletTransactionFailure.network:
      case WalletTransactionFailure.unauthorized:
      case WalletTransactionFailure.unknown:
      case null:
        return copy.loadErrorGeneric;
    }
  }
}

/// The non-loaded states on the one Midnight pattern family (study-notes ruling
/// 1) — the shape `wallet_hub_screen.dart` already ships for the same journey.
/// Replaces `OmdsLoadingState` / `OmdsErrorState`, both light-theme widgets.
class _StateBlock extends StatelessWidget {
  const _StateBlock({
    required this.status,
    required this.headline,
    this.glyph,
    this.body,
    this.action,
  });

  final JeebEmptyStateStatus status;
  final String headline;

  /// Null on loading: the kit paints its skeleton over the whole frame and
  /// never reaches the `center` slot.
  final IconData? glyph;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final IconData? mark = glyph;
    return Center(
      child: SingleChildScrollView(
        child: JeebEmptyState(
          status: status,
          variant: _kStateArt,
          center: mark == null ? null : WalletStateMark(glyph: mark),
          medallions: _kNoMedallions,
          headline: headline,
          body: body,
          action: action,
        ),
      ),
    );
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.txn, required this.copy});

  final WalletTransaction txn;
  final TransactionDetailL10n copy;

  @override
  Widget build(BuildContext context) {
    final List<Widget> fields = _fields();
    final List<Widget> edges = _edges(context);

    return ListView(
      // Board gutter 24, 16 above the hero, 32 below the last card.
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.medium,
        Spacing.xLarge,
        Spacing.twoXLarge,
      ),
      children: [
        // ── Amount (sign-prefixed, D41) — the one number this screen exists to
        //    state, so it takes R4's frosted bank-card. Same string, same id,
        //    same position.
        _AmountHero(
          label: copy.amountLabel,
          amount: copy.signedAmount(txn.sign, _fmt(txn.amount), txn.currency),
          isCredit: txn.sign >= 0,
        ),

        const SizedBox(height: Spacing.medium),

        // ── Per-type heading + body (D37 fee_won / D2 refund-penalty / D1). ──
        // JM-056 asserts `txn_detail_type_label`; the legacy id is
        // `txn_detail_type_summary` — nest both.
        Semantics(
          identifier: 'txn_detail_type_label',
          container: true,
          explicitChildNodes: true,
          child: JeebInfoNote.muted(
            identifier: 'txn_detail_type_summary',
            icon: _typeIcon(txn.type),
            title: copy.typeHeading(txn.type),
            text: copy.typeBody(txn.type),
          ),
        ),

        // ── The typed fields, in the order they have always been in. Grouped
        //    inside one outlined card: the kit draws the 1px inset dividers, so
        //    the rows stop being loose lines on a bare body.
        if (fields.isNotEmpty) ...[
          const SizedBox(height: Spacing.medium),
          JeebOutlinedCard.grouped(children: fields),
        ],

        // ── The outbound edges, in R4's own grouped-exits card. ──────────────
        if (edges.isNotEmpty) ...[
          const SizedBox(height: Spacing.medium),
          JeebOutlinedCard.grouped(children: edges),
        ],
      ],
    );
  }

  /// Date · fee rate · pinned price · dispute ref · reference — unchanged in
  /// content and order; only their shell moved into a grouped card.
  List<Widget> _fields() {
    return <Widget>[
      // ── Date. ──────────────────────────────────────────────────────────────
      if (txn.timestamp.isNotEmpty)
        _DetailRow(label: copy.dateLabel, value: _fmtDate(txn.timestamp)),

      // ── Fee-won breakdown: EXACT 10% + the pinned accepted price (D37). ────
      if (txn.type == WalletLedgerType.feeWon) ...[
        if (txn.feePercent != null)
          // JM-056 AC4 asserts `txn_detail_fee_percentage_label`; the legacy
          // id is `txn_detail_fee_rate` — nest both.
          Semantics(
            identifier: 'txn_detail_fee_percentage_label',
            container: true,
            explicitChildNodes: true,
            child: Semantics(
              identifier: 'txn_detail_fee_rate',
              container: true,
              child: _DetailRow(
                label: copy.feeRateLabel,
                value: copy.feePercentText(txn.feePercent!),
              ),
            ),
          ),
        if (txn.pinnedPrice != null)
          Semantics(
            identifier: 'txn_detail_pinned_price',
            container: true,
            child: _DetailRow(
              label: copy.pinnedPriceLabel,
              value: '${_fmt(txn.pinnedPrice!)} ${txn.currency}'.trim(),
            ),
          ),
      ],

      // ── Dispute reference (refund / penalty, D2). ──────────────────────────
      if (txn.hasDisputeLink)
        _DetailRow(label: copy.disputeRefLabel, value: txn.disputeId!),

      // ── Reference (the originating offer / row ref). JM-056 AC1 asserts
      //    `txn_detail_order_ref` (the order/row reference). ──────────────────
      if (txn.ref != null && txn.ref!.isNotEmpty)
        Semantics(
          identifier: 'txn_detail_order_ref',
          container: true,
          child: _DetailRow(label: copy.referenceLabel, value: txn.ref!),
        ),
    ];
  }

  List<Widget> _edges(BuildContext context) {
    return <Widget>[
      // ── EDGE → order-summary-pinned (`/orders/:id/summary`, CTO-D3). Shown
      //    only when the row carries a resolved orderId (reserve / fee_won /
      //    released). Routes by NAME with the real order id (21_NAV_PLAN §C). ─
      if (txn.hasOrderLink)
        JeebListRow(
          // FROZEN id re-homed onto the kit row, which emits the same
          // `Semantics(identifier:, button:, container:)` node the hand-rolled
          // wrapper did around `OmdsSettingsRow`.
          identifier: 'txn_detail_order_link',
          title: copy.orderLink,
          icon: Icons.receipt_long,
          onTap: () => context.pushNamed(
            'order-summary',
            pathParameters: {'id': txn.orderId!},
          ),
        ),

      // ── EDGE → dispute-open-evidence (`/orders/:id/escalate`, JM-060).
      //    Shown only for refund / penalty rows with a disputeId (D2). The
      //    escalate route is keyed on a delivery/order id; W3m gives only the
      //    disputeId, so it is passed as the route handle (param-shape gap
      //    noted in 50_ROUTE_REQUESTS.md). ────────────────────────────────────
      if (txn.hasDisputeLink)
        JeebListRow(
          identifier: 'txn_detail_dispute_link',
          title: copy.disputeLink,
          icon: Icons.gavel,
          onTap: () => context.pushNamed(
            'escalate',
            pathParameters: {'id': txn.disputeId!},
          ),
        ),
    ];
  }

  /// Filled glyphs (R10) — the hub's own set, so a fee row carries the same
  /// mark here as it does in the ledger list.
  IconData _typeIcon(WalletLedgerType type) {
    switch (type) {
      case WalletLedgerType.reserve:
        return Icons.lock_clock;
      case WalletLedgerType.feeWon:
        return Icons.percent;
      case WalletLedgerType.released:
        return Icons.lock_open;
      case WalletLedgerType.refund:
        return Icons.south_west;
      case WalletLedgerType.penalty:
        return Icons.gavel;
      case WalletLedgerType.topup:
        return Icons.add_card;
      case WalletLedgerType.gift:
        return Icons.card_giftcard;
      case WalletLedgerType.unknown:
        return Icons.receipt_long;
    }
  }

  String _fmt(double v) => v.toStringAsFixed(2);

  /// Render the ISO timestamp as a plain `YYYY-MM-DD HH:MM` (locale-neutral; the
  /// asserted contract is the Semantics id, not the visible text — D-N §8). Falls
  /// back to the raw string when it is not parseable.
  String _fmtDate(String iso) {
    // Normalize the server instant (zone-less → UTC) so `toLocal()` is a real
    // conversion, not a no-op that prints the UTC wall clock (T11 / SW-03).
    final dt = ServerTime.parse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

/// R4's frosted bank-card, carried from `wallet_hub_screen.dart`: hero glass at
/// `JeebRadii.xl`, a real blur, the board's `floatNav` lift, the section label
/// over the signed amount. Hosts the asserted `txn_detail_amount` node, which
/// merges label + value into one announcement exactly as before.
///
/// The hub's Ø150 corner glow is NOT carried: R4's caption rations the solid
/// orange to the one money act, and a read-only transaction is not one.
class _AmountHero extends StatelessWidget {
  const _AmountHero({
    required this.label,
    required this.amount,
    required this.isCredit,
  });

  /// Board `padding: 22px` on the hub's bank-card (`tpl 268`).
  static const double _cardPadding = 22;

  final String label;
  final String amount;
  final bool isCredit;

  @override
  Widget build(BuildContext context) {
    final JeebRoles roles = context.jeebRoles;

    return JeebGlassCapsule(
      radius: JeebRadii.xl,
      blurSigma: JeebGlassCapsule.heroBlur,
      shadow: JeebShadows.floatNav,
      padding: const EdgeInsetsDirectional.all(_cardPadding),
      child: Semantics(
        identifier: 'txn_detail_amount',
        container: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Natural casing in, uppercase out — the kit owns the transform.
            JeebSectionLabel(label),
            const SizedBox(height: Spacing.twoXSmall),
            // A signed amount plus an ISO code is the one string a 200% text
            // scale can push off the card, so it scales down rather than wraps.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                amount,
                // The `+`/`-` is the load-bearing half of this token and the
                // copy layer builds the string by hand (no `MoneyFormat`
                // isolate), so an Arabic paragraph would reorder it to
                // `USD 1.50-`. Resolve the run LTR instead.
                textDirection: TextDirection.ltr,
                style: context.jeebText.statHero.copyWith(
                  // The same credit/debit pair the ledger row uses, so the ink
                  // the Jeeber tapped is the ink that opens.
                  color: isCredit
                      ? roles.onSuccessContainer
                      : roles.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A label / value row used for the transaction fields, sized to sit inside a
/// [JeebOutlinedCard.grouped] (14/16 — [JeebListRow]'s own padding, so a field
/// row and an edge row keep the same rhythm). The label is §1's muted ink role,
/// the value the `onSurface` fact.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: JeebListRow.defaultPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: context.jeebText.bodySmall.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: Spacing.small),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.jeebText.body.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
