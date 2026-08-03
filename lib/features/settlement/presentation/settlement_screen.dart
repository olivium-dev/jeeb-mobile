import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../application/settlement_cubit.dart';
import '../domain/settlement_repository.dart';
import '../domain/settlement_statement.dart';
import 'widgets/settlement_status_pill.dart';

/// Settlement statement list screen (T-MOB-032).
///
/// Route: /jeeber/settlement
/// Lists weekly statements with status chips (paid / pending).
/// Tap a row → [SettlementDetailScreen].
/// Download CTA → GET /v1/wallet/jeeb/earnings/statements/{id}/pdf.
///
/// redesign-2026-08: re-skinned onto the Jeeb system alongside its neighbour,
/// the earnings dashboard (screen 19) — in-body [JeebTopBar] instead of an app
/// bar, [JeebOutlinedCard] rows on 24px gutters, and every amount through
/// [MoneyFormat]. The flow is untouched: same states, same row tap, same
/// per-row PDF download.
// ORPHAN (JEBV4-227, verified 2026-07-12): registered route, zero inbound nav (T-MOB-032 designed but never linked) — see docs/project-understanding/reconciliation/orphans.md
class SettlementScreen extends StatelessWidget {
  const SettlementScreen({
    super.key,
    this.repository,
    this.cubit,
    this.onOpenPdf,
    this.onTapStatement,
  });

  final SettlementRepository? repository;
  final SettlementCubit? cubit;

  /// Called after a successful PDF download with the local file path.
  final void Function(String path)? onOpenPdf;

  /// Called when the user taps a statement row (navigate to detail).
  final void Function(SettlementStatement statement)? onTapStatement;

  @override
  Widget build(BuildContext context) {
    final provided = cubit;
    if (provided != null) {
      return BlocProvider.value(
        value: provided,
        child: _Body(
          onOpenPdf: onOpenPdf,
          onTapStatement: onTapStatement,
        ),
      );
    }
    final repo = repository;
    if (repo == null) {
      return const _Unavailable();
    }
    return BlocProvider<SettlementCubit>(
      create: (_) =>
          SettlementCubit(repository: repo)..loadStatements(),
      child: _Body(
        onOpenPdf: onOpenPdf,
        onTapStatement: onTapStatement,
      ),
    );
  }
}

/// The page shell every state of this screen sits in: the in-body top bar over
/// a `flex:1` body. No `Scaffold.appBar` — the board's header is a body row.
class _SettlementScaffold extends StatelessWidget {
  const _SettlementScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            JeebTopBar.back(
              title: l10n.settlementTitle,
              identifier: 'settlement_back',
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SettlementScaffold(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.xLarge,
          Spacing.xLarge,
          Spacing.xLarge,
          0,
        ),
        child: Text(
          l10n.settlementUnavailable,
          style: context.jeebText.body.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({this.onOpenPdf, this.onTapStatement});

  final void Function(String path)? onOpenPdf;
  final void Function(SettlementStatement statement)? onTapStatement;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettlementCubit, SettlementState>(
      listener: _onStateChange,
      builder: _buildScaffold,
    );
  }

  void _onStateChange(BuildContext context, SettlementState state) {
    if (state.exportMode == SettlementExportMode.done &&
        state.exportedFilePath != null) {
      onOpenPdf?.call(state.exportedFilePath!);
      context.read<SettlementCubit>().acknowledgeExport();
    }
    if (state.exportMode == SettlementExportMode.error &&
        state.exportError != null) {
      // EXEMPT: OMDS exports no standalone toast/snackbar widget; showOmdsSnackbar
      // is the approved fleet pattern for transient error feedback.
      showOmdsSnackbar(context, message: state.exportError!);
      context.read<SettlementCubit>().acknowledgeExport();
    }
  }

  Widget _buildScaffold(BuildContext context, SettlementState state) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'settlement_root',
      container: true,
      child: _SettlementScaffold(
        child: _buildBody(context, state, l10n),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SettlementState state,
    AppLocalizations l10n,
  ) {
    switch (state.mode) {
      case SettlementListMode.loading:
        return const Center(child: OmdsLoadingState());
      case SettlementListMode.error:
        return OmdsErrorState(
          message: state.errorMessage ?? l10n.settlementLoadError,
          onRetry: () =>
              context.read<SettlementCubit>().loadStatements(),
        );
      case SettlementListMode.ready:
        if (state.statements.isEmpty) {
          // R1: the residual space stays white and top-aligned. The list is
          // what keeps it there — `OmdsEmptyState` centres itself vertically
          // when it is given a bounded height (the same shape order-history
          // uses).
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Spacing.xLarge,
                  Spacing.twoXLarge,
                  Spacing.xLarge,
                  0,
                ),
                child: OmdsEmptyState(
                  icon: Icons.receipt_long,
                  title: l10n.settlementEmptyMessage,
                ),
              ),
            ],
          );
        }
        return _StatementList(
          statements: state.statements,
          isExporting: state.isExporting,
          onDownload: (id) =>
              context.read<SettlementCubit>().downloadPdf(id),
          onTap: onTapStatement,
        );
    }
  }
}

class _StatementList extends StatelessWidget {
  const _StatementList({
    required this.statements,
    required this.isExporting,
    required this.onDownload,
    this.onTap,
  });

  final List<SettlementStatement> statements;
  final bool isExporting;
  final void Function(String statementId) onDownload;
  final void Function(SettlementStatement statement)? onTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      // 24px board gutter; the outlines are the separation, so the rows are
      // spaced rather than divided (R7/R12).
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.medium,
        Spacing.xLarge,
        Spacing.xLarge,
      ),
      itemCount: statements.length,
      separatorBuilder: (context, index) => const SizedBox(height: Spacing.small),
      itemBuilder: (context, i) => _StatementRow(
        statement: statements[i],
        isExporting: isExporting,
        onDownload: () => onDownload(statements[i].id),
        onTap: () => onTap?.call(statements[i]),
      ),
    );
  }
}

class _StatementRow extends StatelessWidget {
  const _StatementRow({
    required this.statement,
    required this.isExporting,
    required this.onDownload,
    required this.onTap,
  });

  final SettlementStatement statement;
  final bool isExporting;
  final VoidCallback onDownload;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final chipLabel = SettlementStatusPill.labelFor(l10n, statement.status);
    // One formatter for every amount in the app (JEBV4-98): `$90.00`, wrapped
    // in an LTR isolate so it cannot scramble inside an Arabic row.
    final amountStr = MoneyFormat.format(
      statement.totalPayout,
      currency: statement.currency,
    );

    return JeebOutlinedCard(
      // FROZEN identifier — Maestro and the devtool catalog find rows by it.
      identifier: 'settlement_statement_row_${statement.id}',
      semanticLabel: l10n.settlementRowSemantics(amountStr, chipLabel),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statement.weekLabel,
                  style: context.jeebText.titleProminent.copyWith(
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: Spacing.twoXSmall),
                Text(
                  amountStr,
                  style: context.jeebText.price.copyWith(color: scheme.primary),
                  semanticsLabel: amountStr,
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.small),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SettlementStatusPill(status: statement.status),
              const SizedBox(height: Spacing.twoXSmall),
              isExporting
                  ? const SizedBox.square(
                      dimension: Sizes.large,
                      child: OmdsLoadingState(),
                    )
                  : Semantics(
                      identifier:
                          'settlement_download_${statement.id}',
                      button: true,
                      container: true,
                      child: IconButton(
                        icon: const Icon(Icons.download),
                        color: scheme.primary,
                        tooltip: l10n.settlementDownloadTooltip,
                        onPressed: onDownload,
                        iconSize: Sizes.large,
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
