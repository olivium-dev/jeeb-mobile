import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/server_time.dart';
import '../application/transaction_detail_cubit.dart';
import '../application/transaction_detail_state.dart';
import '../data/stub_wallet_transaction_repository.dart';
import '../domain/wallet_ledger_repository.dart';
import '../domain/wallet_transaction_repository.dart';
import 'transaction_detail_l10n.dart';

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
///   `txn_detail_order_link`   — → order-summary-pinned
///   `txn_detail_dispute_link` — → dispute-open-evidence
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
        appBar: OMDSAppBar(title: copy.title, showBackButton: true),
        body: BlocBuilder<TransactionDetailCubit, TransactionDetailState>(
          builder: (context, state) {
            switch (state.status) {
              case TransactionDetailStatus.initial:
              case TransactionDetailStatus.loading:
                return const OmdsLoadingState();
              case TransactionDetailStatus.failed:
                return OmdsErrorState(
                  message: _errorCopy(copy, state.error),
                  retryLabel: copy.retry,
                  onRetry: () =>
                      context.read<TransactionDetailCubit>().retry(),
                );
              case TransactionDetailStatus.loaded:
                final txn = state.transaction;
                if (txn == null) {
                  return OmdsErrorState(
                    message: copy.loadErrorGeneric,
                    retryLabel: copy.retry,
                    onRetry: () =>
                        context.read<TransactionDetailCubit>().retry(),
                  );
                }
                return _LoadedBody(txn: txn, copy: copy);
            }
          },
        ),
      ),
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

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.txn, required this.copy});

  final WalletTransaction txn;
  final TransactionDetailL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.large,
        Spacing.medium,
        Spacing.xLarge,
      ),
      children: [
        // ── Per-type heading + body (D37 fee_won / D2 refund-penalty / D1). ──
        // JM-056 asserts `txn_detail_type_label`; the legacy id is
        // `txn_detail_type_summary` — nest both.
        Semantics(
          identifier: 'txn_detail_type_label',
          container: true,
          explicitChildNodes: true,
          child: Semantics(
          identifier: 'txn_detail_type_summary',
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_typeIcon(txn.type),
                      color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: Spacing.small),
                  Expanded(
                    child: Text(
                      copy.typeHeading(txn.type),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.xSmall),
              Text(copy.typeBody(txn.type),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
        ),
        ),

        const SizedBox(height: Spacing.large),

        // ── Amount (sign-prefixed, D41). ─────────────────────────────────────
        Semantics(
          identifier: 'txn_detail_amount',
          container: true,
          child: _DetailRow(
            label: copy.amountLabel,
            value: copy.signedAmount(txn.sign, _fmt(txn.amount), txn.currency),
            emphasize: true,
          ),
        ),

        // ── Date. ────────────────────────────────────────────────────────────
        if (txn.timestamp.isNotEmpty)
          _DetailRow(label: copy.dateLabel, value: _fmtDate(txn.timestamp)),

        // ── Fee-won breakdown: EXACT 10% + the pinned accepted price (D37). ──
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

        // ── Dispute reference (refund / penalty, D2). ────────────────────────
        if (txn.hasDisputeLink)
          _DetailRow(label: copy.disputeRefLabel, value: txn.disputeId!),

        // ── Reference (the originating offer / row ref). JM-056 AC1 asserts
        //    `txn_detail_order_ref` (the order/row reference). ────────────────
        if (txn.ref != null && txn.ref!.isNotEmpty)
          Semantics(
            identifier: 'txn_detail_order_ref',
            container: true,
            child: _DetailRow(label: copy.referenceLabel, value: txn.ref!),
          ),

        const SizedBox(height: Spacing.large),

        // ── EDGE → order-summary-pinned (`/orders/:id/summary`, CTO-D3). Shown
        //    only when the row carries a resolved orderId (reserve / fee_won /
        //    released). Routes by NAME with the real order id (21_NAV_PLAN §C). ─
        if (txn.hasOrderLink)
          Semantics(
            identifier: 'txn_detail_order_link',
            button: true,
            container: true,
            child: OmdsSettingsRow(
              title: copy.orderLink,
              leadingIcon: Icons.receipt_long_outlined,
              onTap: () => context.pushNamed(
                'order-summary',
                pathParameters: {'id': txn.orderId!},
              ),
            ),
          ),

        // ── EDGE → dispute-open-evidence (`/orders/:id/escalate`, JM-060).
        //    Shown only for refund / penalty rows with a disputeId (D2). The
        //    escalate route is keyed on a delivery/order id; W3m gives only the
        //    disputeId, so it is passed as the route handle (param-shape gap
        //    noted in 50_ROUTE_REQUESTS.md). ──────────────────────────────────
        if (txn.hasDisputeLink)
          Semantics(
            identifier: 'txn_detail_dispute_link',
            button: true,
            container: true,
            child: OmdsSettingsRow(
              title: copy.disputeLink,
              leadingIcon: Icons.gavel_outlined,
              onTap: () => context.pushNamed(
                'escalate',
                pathParameters: {'id': txn.disputeId!},
              ),
            ),
          ),
      ],
    );
  }

  IconData _typeIcon(WalletLedgerType type) {
    switch (type) {
      case WalletLedgerType.reserve:
        return Icons.lock_clock_outlined;
      case WalletLedgerType.feeWon:
        return Icons.percent_outlined;
      case WalletLedgerType.released:
        return Icons.lock_open_outlined;
      case WalletLedgerType.refund:
        return Icons.south_west_outlined;
      case WalletLedgerType.penalty:
        return Icons.gavel_outlined;
      case WalletLedgerType.topup:
        return Icons.add_card_outlined;
      case WalletLedgerType.gift:
        return Icons.card_giftcard_outlined;
      case WalletLedgerType.unknown:
        return Icons.receipt_long_outlined;
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

/// A label / value row used for the transaction fields. `emphasize` bolds the
/// value (used for the amount).
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.small),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: Spacing.medium),
          Text(
            value,
            textAlign: TextAlign.end,
            style: emphasize
                ? theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)
                : theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
