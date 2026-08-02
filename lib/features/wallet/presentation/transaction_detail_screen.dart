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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/wallet/transaction_detail_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so three things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (the OMDSAppBar surface) and [jeebPreviewHost]
//    wraps every child in one as well, so the canvas shows two nested
//    Scaffolds. The inner one is the real surface; the outer contributes only a
//    background. The canvas box is therefore a real device
//    ([_transactionDetailScreenPhoneBox], 390x844) rather than the harness's
//    default 390x200 — an app bar over a scrolling field list cannot be judged
//    in a 200 pt strip, and the 390 pt WIDTH is load-bearing here: it is the
//    constraint `_DetailRow` actually breaks under (see 3).
//
// 2. It builds fine without a `Router`, but it is not TAPPABLE without one.
//    All three affordances on this screen leave it — the app bar's back
//    (`context.canPop()`/`context.go('/')`) and the two outbound edges
//    (`txn_detail_order_link` → `order-summary`, `txn_detail_dispute_link` →
//    `escalate`) — and every one of them throws under the bare `MaterialApp`
//    the canvas host and the render harness provide.
//    [_TransactionDetailScreenHost] supplies a local [GoRouter] carrying the
//    two real route NAMES and paths, so a click in the canvas lands on a
//    stand-in that says which edge was taken instead of crashing the card.
//
// 3. The state is driven the only way this screen allows: through the
//    `repository:` constructor seam, with the fakes and rows shared with the
//    Screen Catalog entry
//    (`lib/devtool/catalog/fixtures/transaction_detail_screen_fixtures.dart`).
//    No preview builds a `DioWalletTransactionRepository` and none reaches
//    `_resolveRepository()`'s `sl<>()` branch, so these are network-free by
//    construction rather than by the guard in [jeebPreviewHost].
//
// One state cannot be reached from here and is worth knowing about: the
// `loaded`-with-a-null-`transaction` branch of `_TransactionDetailView`, which
// renders `loadErrorGeneric`. [TransactionDetailCubit] only emits `loaded`
// together with a row, so that branch is defensive and unreachable through the
// repository seam — there is no `cubit:` seam to seed the pair by hand.
//
// What these previews surfaced in the screen — see the notes on each:
//
//  * `_DetailRow` gives its VALUE no width constraint. Only the label is
//    `Expanded`; the value `Text` is laid out first, at unbounded width, so it
//    neither wraps nor ellipsizes — it takes what it wants and the label gets
//    the remainder. At the 390 pt canvas width a value wider than ~342 pt
//    leaves the label zero and overflows the row, and an `off-`+GUID reference
//    clears that on its own by 318 pt (`Reserve · GUID reference`). At 800 pt —
//    the default `flutter_test` surface, wider than any phone — the same row
//    fits, which is why neither the widget tests nor the shared preview suite
//    ever saw it and why the render test resizes before asserting.
//  * `WalletTransaction.title` is never read by this screen. The field's own
//    doc calls it the fallback "when no localized copy exists for an `unknown`
//    row", but `_LoadedBody` derives every string from `txn.type`, so an
//    `unknown` row shows the generic "Transaction" heading and the generic
//    `txnDetailBody` paragraph while the server's real label is dropped on the
//    floor (`Unknown type · generic copy`).
//  * both outbound edges are gated on DATA (`hasOrderLink` / `hasDisputeLink`)
//    rather than on the row's type, so the refund row the shipped stub returns
//    — which carries an `orderId` — renders BOTH links, contradicting this
//    file's own doc comment and the "refund → no order link" assertion in
//    `test/features/wallet/transaction_detail_screen_test.dart`
//    (`Refund · dispute + order links`).

/// The canvas box for a whole screen: a real phone, not the harness default.
///
/// The width is not decoration — see note 3 in the section header.
const Size _transactionDetailScreenPhoneBox = Size(390, 844);

/// Where an outbound edge lands in the canvas.
///
/// The real destinations are `order-summary-pinned` (JM-031) and
/// `dispute-open-evidence` (JM-060), both of which build their own cubits off
/// DI. Here the route only has to exist and say WHICH edge was taken, so a tap
/// on `txn_detail_order_link` or `txn_detail_dispute_link` is reviewable
/// instead of fatal.
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
          // reorders visually inside an RTL paragraph.
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
///
/// Stateful, and the router is built once and disposed with the host: a
/// [GoRouter] rebuilt on every frame would drop the navigation state
/// `canPop()` reads. `Router.withConfig` is exactly what `MaterialApp.router`
/// does internally, so this adds a Router and nothing else — the ambient theme,
/// locale and text scale still come from the preview host above it.
///
/// The two stand-in routes reuse the REAL names and paths from
/// `app_router.dart` (`order-summary` → `/orders/:id/summary`, `escalate` →
/// `/orders/:id/escalate`). A rename there makes these previews throw on tap,
/// which is the correct outcome: `pushNamed` would throw in the app too.
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
/// preview that asked for `led-1` and rendered `led-gift-001` would still read
/// as a bug the first time someone opened the canvas.
Widget _transactionDetailScreenRow(WalletTransaction row) =>
    _transactionDetailScreenHosted(
      TransactionDetailScreenFakeRepository(row),
      transactionId: row.id,
    );

/// The richest variant and the one the JM-056 ACs are written against: the
/// exact 10% platform fee (D37) over the pinned accepted price it was taken
/// from, with `txn_detail_order_link` under it.
///
/// Matrixed because every line on this screen is a label/value `Row` competing
/// for one horizontal run, which is exactly what RTL mirrors and what 200% text
/// starves. The AR rendering is also the only place the sign prefix built in
/// `TransactionDetailL10n.signedAmount` can be read against a mirrored line:
/// `-1.50 USD` is assembled with a literal `-`, not a locale-aware sign.
@JeebPreview(
  group: 'wallet',
  name: 'Fee won · 10% + pinned price',
  size: _transactionDetailScreenPhoneBox,
  matrix: true,
)
Widget transactionDetailScreenFeeWon() =>
    _transactionDetailScreenRow(transactionDetailScreenFeeWonRow);

/// A resolved dispute credited back (D2) — and the edge-gating defect.
///
/// The shipped stub's refund row carries an `orderId` as well as a
/// `disputeId`, and the screen gates each link on the DATA rather than on the
/// type, so this row renders `txn_detail_dispute_link` AND
/// `txn_detail_order_link`. Both the class doc at the top of this file and
/// `transaction_detail_screen_test.dart` say a refund has no order link; the
/// test only passes because its fixture omits the field.
@JeebPreview(
  group: 'wallet',
  name: 'Refund · dispute + order links',
  size: _transactionDetailScreenPhoneBox,
)
Widget transactionDetailScreenRefund() =>
    _transactionDetailScreenRow(transactionDetailScreenRefundRow);

/// The layout ceiling, and the state that actually breaks.
///
/// `ref` is printed verbatim and the gateway is .NET, so a 36-character GUID
/// behind a short prefix is the ordinary shape of a real reference. In
/// `_DetailRow` the value is the NON-flexible child: it is measured first at
/// unbounded width, so it neither wraps nor ellipsizes, and the `Expanded`
/// label gets whatever is left — nothing. At the declared 390 pt canvas width
/// this overflows the row by 318 pt; at the 800 pt default test surface it does
/// not, which is why the render test resizes before asserting.
///
/// Matrixed because the 200% rendering is where the SHORT values (`-2.40 USD`,
/// the date) join it, and the AR rendering is where a latin GUID sits inside a
/// mirrored line.
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
///
/// This is the closest thing this screen has to an empty state, and the only
/// preview that exercises the `if (txn.timestamp.isNotEmpty)` guard: a heading,
/// a paragraph and one amount, with 700 pt of blank surface below them.
@JeebPreview(
  group: 'wallet',
  name: 'Gift · minimal row',
  size: _transactionDetailScreenPhoneBox,
)
Widget transactionDetailScreenGiftMinimal() =>
    _transactionDetailScreenRow(transactionDetailScreenMinimalRow);

/// A ledger type this build does not know, which is where every future W3m
/// `type` lands.
///
/// The row carries a server-supplied `title` ("Manual ops adjustment") and the
/// screen drops it: `_LoadedBody` derives all copy from `txn.type`, so the user
/// gets the generic "Transaction" heading over the generic `txnDetailBody`
/// paragraph. The reference row is what tells them anything at all.
@JeebPreview(
  group: 'wallet',
  name: 'Unknown type · generic copy',
  size: _transactionDetailScreenPhoneBox,
)
Widget transactionDetailScreenUnknownType() =>
    _transactionDetailScreenRow(transactionDetailScreenUnknownTypeRow);

/// The typed 404: a row id that W3m does not know.
///
/// This is the ONE failure with its own copy — `_errorCopy` maps `notFound` to
/// a dedicated string and folds `network`, `unauthorized` and `unknown` into
/// the generic one. Worth seeing beside its sibling below, because the
/// difference between the two is the whole of this screen's error vocabulary.
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
///
/// `unauthorized` is included in that fold, so a Jeeber whose session expired
/// is told to "try again" and retries into the same 401 forever — the retry
/// CTA is the only affordance the state has.
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
///
/// Held open by a read that never lands. Note what the app bar does NOT have
/// here: the back affordance is live from the first frame, so this state is
/// escapable — which is the correct behaviour and not something the other
/// wallet surfaces all get right.
@JeebPreview(
  group: 'wallet',
  name: 'Loading · spinner',
  size: _transactionDetailScreenPhoneBox,
)
Widget transactionDetailScreenLoading() => _transactionDetailScreenHosted(
      const TransactionDetailScreenStalledRepository(),
      transactionId: 'txn-loading',
    );
