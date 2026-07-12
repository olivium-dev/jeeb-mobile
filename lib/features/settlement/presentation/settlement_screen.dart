import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../application/settlement_cubit.dart';
import '../domain/settlement_repository.dart';
import '../domain/settlement_statement.dart';

/// Settlement statement list screen (T-MOB-032).
///
/// Route: /jeeber/settlement
/// Lists weekly statements with status chips (paid / pending).
/// Tap a row → [SettlementDetailScreen].
/// Download CTA → GET /v1/wallet/jeeb/earnings/statements/{id}/pdf.
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

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(title: l10n.settlementTitle),
      body: Center(child: Text(l10n.settlementUnavailable)),
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
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.settlementTitle,
        showBackButton: true,
      ),
      body: _buildBody(context, state, l10n),
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
          return Center(child: Text(l10n.settlementEmptyMessage));
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
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      itemCount: statements.length,
      separatorBuilder: (context, index) => const SizedBox(height: Spacing.xSmall),
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
    // Semantic roles: paid = success, pending = warning. The old
    // secondary/tertiary container pairs were brand hues doing state duty
    // (onSecondaryContainer on navy fails AA).
    final roles = context.jeebRoles;
    final chipColor = statement.status == SettlementStatus.paid
        ? roles.successContainer
        : roles.warningContainer;
    final chipTextColor = statement.status == SettlementStatus.paid
        ? roles.onSuccessContainer
        : roles.onWarningContainer;
    final chipLabel = statement.status == SettlementStatus.paid
        ? l10n.settlementStatusPaid
        : l10n.settlementStatusPending;
    final amountStr =
        '${statement.currency} ${statement.totalPayout.toStringAsFixed(2)}';

    return Semantics(
      label: l10n.settlementRowSemantics(amountStr, chipLabel),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.medium),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statement.weekLabel,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: Spacing.xSmall),
                      Text(
                        amountStr,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.small,
                        vertical: Spacing.twoXSmall,
                      ),
                      decoration: BoxDecoration(
                        color: chipColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        chipLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: chipTextColor,
                            ),
                      ),
                    ),
                    const SizedBox(height: Spacing.xSmall),
                    isExporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: OmdsLoadingState(),
                          )
                        : IconButton(
                            icon: const Icon(Icons.download),
                            tooltip: l10n.settlementDownloadTooltip,
                            onPressed: onDownload,
                            iconSize: 20,
                          ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
