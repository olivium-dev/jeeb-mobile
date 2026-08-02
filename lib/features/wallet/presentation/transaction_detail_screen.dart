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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/transaction_detail_screen_fixtures.dart';

class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
    this.repository,
  });

  final String transactionId;

  final WalletTransactionRepository? repository;

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
      identifier: 'txn_detail',
      container: true,
      explicitChildNodes: true,
      child: Semantics(
      identifier: 'txn_detail_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: copy.title,
          showBackButton: true,
          onBackPressed: () =>
              context.canPop() ? context.pop() : context.go('/'),
        ),
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

        Semantics(
          identifier: 'txn_detail_amount',
          container: true,
          child: _DetailRow(
            label: copy.amountLabel,
            value: copy.signedAmount(txn.sign, _fmt(txn.amount), txn.currency),
            emphasize: true,
          ),
        ),

        if (txn.timestamp.isNotEmpty)
          _DetailRow(label: copy.dateLabel, value: _fmtDate(txn.timestamp)),

        if (txn.type == WalletLedgerType.feeWon) ...[
          if (txn.feePercent != null)
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

        if (txn.hasDisputeLink)
          _DetailRow(label: copy.disputeRefLabel, value: txn.disputeId!),

        if (txn.ref != null && txn.ref!.isNotEmpty)
          Semantics(
            identifier: 'txn_detail_order_ref',
            container: true,
            child: _DetailRow(label: copy.referenceLabel, value: txn.ref!),
          ),

        const SizedBox(height: Spacing.large),

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

  String _fmtDate(String iso) {
    final dt = ServerTime.parse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a whole screen: a real phone, not the harness default.
/// The width is not decoration — see note 3 in the section header.
const Size _transactionDetailScreenPhoneBox = Size(390, 844);

/// Where an outbound edge lands in the canvas.
/// The real destinations are `order-summary-pinned` (JM-031) and
/// `dispute-open-evidence` (JM-060), both of which build their own cubits off
class _TransactionDetailScreenRouteStandIn extends StatelessWidget {
  const _TransactionDetailScreenRouteStandIn({
    required this.routeName,
    required this.id,
  });

  final String routeName;
  final String id;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('$routeName (preview stand-in)')),
      body: Center(
        child: Text(
          // Forced LTR: diagnostic, not shipped copy, and a latin identifier
          'id: $id',
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [TransactionDetailScreen] so its three
/// affordances can be exercised in the canvas.
/// Stateful, and the router is built once and disposed with the host: a
class _TransactionDetailScreenHost extends StatefulWidget {
  const _TransactionDetailScreenHost({
    required this.repository,
    required this.transactionId,
  });

  final WalletTransactionRepository repository;
  final String transactionId;

  @override
  State<_TransactionDetailScreenHost> createState() =>
      _TransactionDetailScreenHostState();
}

class _TransactionDetailScreenHostState
    extends State<_TransactionDetailScreenHost> {
  late final GoRouter _router = GoRouter(
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => TransactionDetailScreen(
          transactionId: widget.transactionId,
          repository: widget.repository,
        ),
      ),
      GoRoute(
        path: '/orders/:id/summary',
        name: 'order-summary',
        builder: (_, GoRouterState state) =>
            _TransactionDetailScreenRouteStandIn(
          routeName: 'order-summary',
          id: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/orders/:id/escalate',
        name: 'escalate',
        builder: (_, GoRouterState state) =>
            _TransactionDetailScreenRouteStandIn(
          routeName: 'escalate',
          id: state.pathParameters['id'] ?? '',
        ),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Router.withConfig(config: _router);
}

Widget _transactionDetailScreenHosted(
  WalletTransactionRepository repository, {
  required String transactionId,
}) =>
    _TransactionDetailScreenHost(
      repository: repository,
      transactionId: transactionId,
    );

/// Hosts one canned row. The `transactionId` is the row's own id, so the route
/// argument and the payload agree — the fixture repository is id-blind, but a
Widget _transactionDetailScreenRow(WalletTransaction row) =>
    _transactionDetailScreenHosted(
      TransactionDetailScreenFakeRepository(row),
      transactionId: row.id,
    );

/// The richest variant and the one the JM-056 ACs are written against: the
/// exact 10% platform fee (D37) over the pinned accepted price it was taken
@JeebPreview(
  group: 'wallet',
  name: 'Fee won · 10% + pinned price',
  size: _transactionDetailScreenPhoneBox,
  matrix: true,
)
Widget transactionDetailScreenFeeWon() =>
    _transactionDetailScreenRow(transactionDetailScreenFeeWonRow);

/// A resolved dispute credited back (D2) — and the edge-gating defect.
/// The shipped stub's refund row carries an `orderId` as well as a
@JeebPreview(
  group: 'wallet',
  name: 'Refund · dispute + order links',
  size: _transactionDetailScreenPhoneBox,
)
Widget transactionDetailScreenRefund() =>
    _transactionDetailScreenRow(transactionDetailScreenRefundRow);

/// The layout ceiling, and the state that actually breaks.
/// `ref` is printed verbatim and the gateway is .NET, so a 36-character GUID
@JeebPreview(
  group: 'wallet',
  name: 'Reserve · GUID reference',
  size: _transactionDetailScreenPhoneBox,
  matrix: true,
)
Widget transactionDetailScreenLongReference() =>
    _transactionDetailScreenRow(transactionDetailScreenGuidRefRow);

/// The floor: the leanest row W3m returns — the approval starter credit, with
/// no reference, no order, no dispute and no timestamp.
@JeebPreview(
  group: 'wallet',
  name: 'Gift · minimal row',
  size: _transactionDetailScreenPhoneBox,
)
Widget transactionDetailScreenGiftMinimal() =>
    _transactionDetailScreenRow(transactionDetailScreenMinimalRow);

/// A ledger type this build does not know, which is where every future W3m
/// `type` lands.
@JeebPreview(
  group: 'wallet',
  name: 'Unknown type · generic copy',
  size: _transactionDetailScreenPhoneBox,
)
Widget transactionDetailScreenUnknownType() =>
    _transactionDetailScreenRow(transactionDetailScreenUnknownTypeRow);

/// The typed 404: a row id that W3m does not know.
/// This is the ONE failure with its own copy — `_errorCopy` maps `notFound` to
@JeebPreview(
  group: 'wallet',
  name: 'Error · not found',
  size: _transactionDetailScreenPhoneBox,
)
Widget transactionDetailScreenErrorNotFound() => _transactionDetailScreenHosted(
      const TransactionDetailScreenFailingRepository(
        WalletTransactionFailure.notFound,
      ),
      transactionId: 'txn-missing',
    );

/// The other three failures, which all render this one message.
/// `unauthorized` is included in that fold, so a Jeeber whose session expired
@JeebPreview(
  group: 'wallet',
  name: 'Error · network',
  size: _transactionDetailScreenPhoneBox,
)
Widget transactionDetailScreenErrorNetwork() => _transactionDetailScreenHosted(
      const TransactionDetailScreenFailingRepository(
        WalletTransactionFailure.network,
      ),
      transactionId: 'led-1',
    );

/// The cold entry every one of the states above passes through.
/// Held open by a read that never lands. Note what the app bar does NOT have
@JeebPreview(
  group: 'wallet',
  name: 'Loading · spinner',
  size: _transactionDetailScreenPhoneBox,
)
Widget transactionDetailScreenLoading() => _transactionDetailScreenHosted(
      const TransactionDetailScreenStalledRepository(),
      transactionId: 'txn-loading',
    );
