import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../application/settlement_cubit.dart';
import '../domain/settlement_repository.dart';
import '../domain/settlement_statement.dart';

import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/settlement_screen_fixtures.dart';

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

  final void Function(String path)? onOpenPdf;

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
      showOmdsSnackbar(context, message: state.exportError!);
      context.read<SettlementCubit>().acknowledgeExport();
    }
  }

  Widget _buildScaffold(BuildContext context, SettlementState state) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'settlement_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.settlementTitle,
          showBackButton: true,
        ),
        body: _buildBody(context, state, l10n),
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
        child: Semantics(
          identifier: 'settlement_statement_row_${statement.id}',
          button: true,
          container: true,
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
                        : Semantics(
                            identifier:
                                'settlement_download_${statement.id}',
                            button: true,
                            container: true,
                            child: IconButton(
                              icon: const Icon(Icons.download),
                              tooltip: l10n.settlementDownloadTooltip,
                              onPressed: onDownload,
                              iconSize: 20,
                            ),
                          ),
                  ],
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
// ============================= JEEB PREVIEWS =============================
/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _settlementScreenPhoneBox = Size(390, 844);

/// The narrowest viewport the app supports.
const Size _settlementScreenCompactBox = Size(320, 568);

/// Statement ids forwarded to `onTapStatement`, newest last.
final List<String> settlementScreenTappedStatementIds = <String>[];

/// Local file paths forwarded to `onOpenPdf`, newest last.
final List<String> settlementScreenOpenedPdfPaths = <String>[];

/// The list states, built the way the catalog builds them: through the
Widget _settlementScreenFromRepository(SettlementRepository repository) {
  return SettlementScreen(
    repository: repository,
    onTapStatement: (SettlementStatement statement) =>
        settlementScreenTappedStatementIds.add(statement.id),
    onOpenPdf: settlementScreenOpenedPdfPaths.add,
  );
}

/// The export states, which no repository shape alone can reach: `exporting`
class _SettlementScreenExportHost extends StatefulWidget {
  const _SettlementScreenExportHost({required this.repository});

  final SettlementRepository repository;

  @override
  State<_SettlementScreenExportHost> createState() =>
      _SettlementScreenExportHostState();
}

class _SettlementScreenExportHostState
    extends State<_SettlementScreenExportHost> {
  late final SettlementCubit _cubit =
      SettlementCubit(repository: widget.repository);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      settlementScreenDriveExport(_cubit, 'stmt-1');
    });
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettlementScreen(
      cubit: _cubit,
      onTapStatement: (SettlementStatement statement) =>
          settlementScreenTappedStatementIds.add(statement.id),
      onOpenPdf: settlementScreenOpenedPdfPaths.add,
    );
  }
}

/// The first read, still on the wire.
@JeebPreview(
  group: 'settlement',
  name: 'Loading · first read',
  size: _settlementScreenPhoneBox,
)
Widget settlementScreenLoading() => _settlementScreenFromRepository(
      const SettlementScreenPendingRepository(),
    );

/// The happy path: one paid week over one pending week.
@JeebPreview(
  group: 'settlement',
  name: 'Ready · paid + pending',
  size: _settlementScreenPhoneBox,
)
Widget settlementScreenReady() => _settlementScreenFromRepository(
      const SettlementScreenFakeRepository(
        statements: settlementScreenListedWeeks,
      ),
    );

/// A Jeeber with no statements yet — approved this week, or never driven.
@JeebPreview(
  group: 'settlement',
  name: 'Empty · no statements yet',
  size: _settlementScreenPhoneBox,
)
Widget settlementScreenEmpty() => _settlementScreenFromRepository(
      const SettlementScreenFakeRepository(),
    );

/// The offline read — and the l10n hole, made visible.
@JeebPreview(
  group: 'settlement',
  name: 'Error · offline',
  size: _settlementScreenPhoneBox,
  matrix: true,
)
Widget settlementScreenOffline() => _settlementScreenFromRepository(
      const SettlementScreenFakeRepository(
        fetchFailure: SettlementFailure.network,
      ),
    );

/// The failure the cubit does not catch.
@JeebPreview(
  group: 'settlement',
  name: 'Error · unmapped failure (stuck)',
  size: _settlementScreenPhoneBox,
)
Widget settlementScreenUnmappedFailure() => _settlementScreenFromRepository(
      const SettlementScreenFakeRepository(fetchThrowsUnmapped: true),
    );

/// A PDF export in flight, driven by a fake whose download never lands.
@JeebPreview(
  group: 'settlement',
  name: 'Exporting · PDF on the wire',
  size: _settlementScreenPhoneBox,
)
Widget settlementScreenExporting() => const _SettlementScreenExportHost(
      repository: SettlementScreenFakeRepository(
        statements: settlementScreenListedWeeks,
        downloadPending: true,
      ),
    );

/// A failed export: the only feedback this screen gives for one.
@JeebPreview(
  group: 'settlement',
  name: 'Export failed · transient snackbar',
  size: _settlementScreenPhoneBox,
)
Widget settlementScreenExportFailed() => const _SettlementScreenExportHost(
      repository: SettlementScreenFakeRepository(
        statements: settlementScreenListedWeeks,
        downloadFailure: SettlementFailure.fileWrite,
      ),
    );

/// Neither seam supplied — the `_Unavailable` fallback.
@JeebPreview(
  group: 'settlement',
  name: 'Unavailable · no seam',
  size: _settlementScreenPhoneBox,
)
Widget settlementScreenUnavailable() => const SettlementScreen();

/// The layout ceiling, on the narrowest device this app supports.
@JeebPreview(
  group: 'settlement',
  name: 'Ready · longest content',
  size: _settlementScreenCompactBox,
  matrix: true,
)
Widget settlementScreenLongestContent() => _settlementScreenFromRepository(
      SettlementScreenFakeRepository(
        statements: settlementScreenLongestStatements(),
      ),
    );
