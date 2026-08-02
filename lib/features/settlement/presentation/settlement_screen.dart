import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../application/settlement_cubit.dart';
import '../domain/settlement_repository.dart';
import '../domain/settlement_statement.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/settlement/settlement_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so three things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (the OMDS app bar over the statement list) and
//    [jeebPreviewHost] wraps every child in one as well, so the canvas shows
//    two nested Scaffolds. The inner one is the real surface; the outer
//    contributes only a background. The canvas box is therefore a real device
//    ([_settlementScreenPhoneBox], 390x844) rather than the harness's default
//    390x200 — an app bar over a list of cards cannot be judged in a 200 pt
//    strip.
//
// 2. Unlike most screens in this app it needs NO `Router`. Nothing inside it
//    navigates: the app bar's back arrow is `Navigator.maybePop` (guarded),
//    and both destinations — the per-statement breakdown and the OS PDF
//    viewer — are plain callbacks the ROUTE supplies (`app_router.dart`,
//    `/jeeber/settlement`: `context.push('/jeeber/settlement/:id')` and
//    `OpenFile.open`). The previews record those callbacks into
//    [settlementScreenTappedStatementIds] / [settlementScreenOpenedPdfPaths]
//    instead of stubbing a router, so a tap in the canvas is honest and the
//    render test can pin WHICH statement was forwarded.
//
// 3. State is driven through the two existing constructor seams (§5.4) with
//    the fakes shared with the Screen Catalog entry
//    (`lib/devtool/catalog/fixtures/settlement_screen_fixtures.dart`). The
//    list states go through `repository:`, which is what the catalog uses; the
//    two export states go through `cubit:` with a cubit driven the way a user
//    drives it (load, then download), because `SettlementState` is only
//    reachable via `emit`. No preview constructs the Dio-backed repository and
//    `sl<SettlementRepository>()` is never reached, so these are network-free
//    by construction rather than by the guard in [jeebPreviewHost].
//
// What these previews surfaced in the screen — the notes on each say more:
//
//  * every error string on this surface is HARDCODED ENGLISH.
//    `SettlementCubit._mapError` returns 'No internet connection' / 'Server
//    error. Please try again.' / 'Statement not found' / 'Unable to save PDF
//    file', and `_buildBody` prefers that over `l10n.settlementLoadError`. An
//    Arabic build shows English on every failure, and the localized
//    `settlementLoadError` key — which exists in both ARBs — is DEAD: the only
//    way to reach it is an error state with a null message, which the cubit
//    never emits. The `Retry` label under it is `OmdsErrorState`'s own English
//    default. See [settlementScreenOffline], whose matrix puts EN and AR side
//    by side;
//  * `loadStatements` catches `on SettlementException` only. Anything else out
//    of the data layer — a `TypeError` from `SettlementStatement.fromJson` on
//    a changed payload, a `DioException` that escaped, a `FormatException` —
//    is not caught, no `error` state is emitted, and the screen sits on its
//    spinner forever with no retry. See [settlementScreenUnmappedFailure];
//  * `isExporting` lives on the STATE, not on the statement, so downloading
//    one week's PDF replaces the download button on EVERY row at once — and
//    `SettlementCubit.downloadPdf` early-returns while `isExporting`, so those
//    other rows are dead, not merely busy. See [settlementScreenExporting];
//  * the thing that replaces them is invisible. `_StatementRow` puts an
//    `OmdsLoadingState` inside a `SizedBox(width: 20, height: 20)`, but that
//    widget is a 48 pt indicator inside `EdgeInsets.all(Spacing.large)` — 88 pt
//    of intrinsic width squeezed into 20. The indicator lays out at
//    `Size(0.0, 48.0)`: zero pixels wide, so nothing is drawn, and 48 pt tall,
//    so it is not even the height the 20 pt box budgeted. During an export the
//    trailing column of every row is blank. Pinned by the render test;
//  * the row's accessibility wrapping produces TWO nodes where it means one.
//    `l10n.settlementRowSemantics` puts 'USD 184.50 — Paid' on a Semantics
//    around the `Card`, and the inner `Semantics(container: true)` around the
//    `InkWell` then starts a node of its own carrying 'Jun 22 – Jun 28 / USD
//    184.50 / Paid' — so the amount and the status are announced twice per
//    row, and the summary label is on a node that is not the button. The
//    download button is worse: `settlement_download_<id>` is a `button: true`
//    node with NO label and NO tap action, sitting in front of the real
//    IconButton node, whose only name is the 'Download PDF' tooltip. Both
//    pinned by the render test;
//  * a statement whose `weekLabel` the gateway omitted renders a card with a
//    blank title line: `SettlementStatement.fromJson` defaults it to `''` and
//    the row prints it unguarded. See [settlementScreenLongestContent];
//  * `_Unavailable` — what the screen renders when neither seam is supplied —
//    has an app bar with NO back affordance (`showBackButton` defaults to
//    false, unlike the loaded surface, and `automaticallyImplyLeading` finds
//    nothing to pop). The route is an ORPHAN with zero inbound navigation, so
//    a deep link IS how it is reached, and this state renders zero back
//    arrows where the loaded state renders one. See
//    [settlementScreenUnavailable].
//
// One state is deliberately NOT previewed: a SUCCESSFUL export. It emits
// `done`, the listener forwards the path and immediately calls
// `acknowledgeExport()`, so the surface is byte-identical to
// [settlementScreenReady] — there is nothing to look at. The render test taps
// through it instead, which is also the only place the `onOpenPdf` contract is
// checked.
//
// One thing these previews do NOT find, worth recording because it is the
// obvious suspicion: the row does not overflow. The longest-content page below
// is clean at 200% text on a 320x568 device in both locales — the label column
// is an `Expanded` and the label wraps rather than pushing the chip off the
// edge.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _settlementScreenPhoneBox = Size(390, 844);

/// The narrowest viewport the app supports.
///
/// Used for the longest-content preview, because this row's trailing column
/// (status chip + download button) is NOT inside the `Expanded`: it claims its
/// intrinsic width first and the label column gets what is left, so 320 pt is
/// where the label has least to work with.
const Size _settlementScreenCompactBox = Size(320, 568);

/// Statement ids forwarded to `onTapStatement`, newest last.
///
/// The route pushes `/jeeber/settlement/:id` from this callback. Public
/// because `test/previews/settlement/settlement_screen_preview_test.dart`
/// asserts against it; clear it between pumps.
final List<String> settlementScreenTappedStatementIds = <String>[];

/// Local file paths forwarded to `onOpenPdf`, newest last.
///
/// The route hands these to `OpenFile.open`. Public for the same reason as
/// [settlementScreenTappedStatementIds].
final List<String> settlementScreenOpenedPdfPaths = <String>[];

/// The list states, built the way the catalog builds them: through the
/// `repository:` seam, with both route callbacks recorded rather than stubbed.
Widget _settlementScreenFromRepository(SettlementRepository repository) {
  return SettlementScreen(
    repository: repository,
    onTapStatement: (SettlementStatement statement) =>
        settlementScreenTappedStatementIds.add(statement.id),
    onOpenPdf: settlementScreenOpenedPdfPaths.add,
  );
}

/// The export states, which no repository shape alone can reach: `exporting`
/// and the export `error` are emitted by `downloadPdf()`, and only a tap calls
/// it.
///
/// Stateful, and the tap is driven from a POST-FRAME callback rather than from
/// the cubit's construction. `_Body` reacts to an export result in a
/// `BlocConsumer.listener`, and a listener only sees transitions that happen
/// after it subscribes: a cubit driven before the screen mounts arrives
/// already in `error`, the listener never fires, and the export snackbar this
/// preview exists to show never appears. Owning the cubit here also means it
/// is closed with the host instead of leaking one per canvas rebuild.
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
///
/// A centered `OmdsLoadingState` under the app bar and nothing else — no
/// skeleton rows, no title, no hint that this screen is a list. It is also the
/// surface an unmapped failure gets stuck on forever
/// ([settlementScreenUnmappedFailure]), which is why the two are worth seeing
/// next to each other: they are the same picture.
@JeebPreview(
  group: 'settlement',
  name: 'Loading · first read',
  size: _settlementScreenPhoneBox,
)
Widget settlementScreenLoading() => _settlementScreenFromRepository(
      const SettlementScreenPendingRepository(),
    );

/// The happy path: one paid week over one pending week.
///
/// Both status chips at once, on the semantic success/warning container roles
/// that replaced the brand-hue pairs (the `onSecondaryContainer`-on-navy
/// combination failed AA).
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
///
/// A bare centered sentence: no illustration, no `OmdsEmptyState`, and no CTA
/// pointing anywhere. Worth looking at because it is the first thing a newly
/// approved Jeeber sees on this route.
@JeebPreview(
  group: 'settlement',
  name: 'Empty · no statements yet',
  size: _settlementScreenPhoneBox,
)
Widget settlementScreenEmpty() => _settlementScreenFromRepository(
      const SettlementScreenFakeRepository(),
    );

/// The offline read — and the l10n hole, made visible.
///
/// `matrix: true` because the point is the AR card: the message is
/// `SettlementCubit._mapError`'s hardcoded English 'No internet connection',
/// and the retry button carries `OmdsErrorState`'s hardcoded English 'Retry'.
/// Both render identically in an Arabic build, inside an otherwise mirrored
/// layout. `l10n.settlementLoadError` — the localized string this screen was
/// written to show — is unreachable, because `state.errorMessage` is never
/// null once a typed failure has been mapped.
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
///
/// `loadStatements` is `try { … } on SettlementException catch (e)`, so a
/// `TypeError` out of `SettlementStatement.fromJson`, a `DioException` that
/// escaped the repository, or any other unmapped throw leaves the cubit in
/// `loading` and completes its future with an error nobody awaits. The screen
/// spins forever: no error state, no retry, no message. Indistinguishable
/// from [settlementScreenLoading] — which is the finding.
@JeebPreview(
  group: 'settlement',
  name: 'Error · unmapped failure (stuck)',
  size: _settlementScreenPhoneBox,
)
Widget settlementScreenUnmappedFailure() => _settlementScreenFromRepository(
      const SettlementScreenFakeRepository(fetchThrowsUnmapped: true),
    );

/// A PDF export in flight, driven by a fake whose download never lands.
///
/// Two things to look at, both list-wide rather than row-wide:
/// `SettlementState.isExporting` is not keyed to a statement, so EVERY row
/// swapped its download button — and `downloadPdf` early-returns while
/// exporting, so the other rows are inert, not just busy. What replaced the
/// buttons is a zero-sized `OmdsLoadingState`: a 48 pt indicator plus 20 pt
/// padding on each side, given a `SizedBox(width: 20, height: 20)`, resolves
/// to nothing. The trailing column of every row is simply empty for as long as
/// the export runs.
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
///
/// `_onStateChange` shows a transient snackbar and immediately calls
/// `acknowledgeExport()`, so four seconds later the surface is back to
/// [settlementScreenReady] with no record that anything failed and no retry
/// affordance. The message — 'Unable to save PDF file' — is another of
/// `_mapError`'s hardcoded English strings.
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
///
/// Not hypothetical: it is what `SettlementScreen()` renders, and it is the
/// whole screen, so a wiring mistake in the route degrades to a sentence
/// rather than to a crash. Note the app bar: `_Unavailable` does not pass
/// `showBackButton`, unlike the loaded surface, so on a deep link (nothing to
/// pop, no implied leading) this state has no way out.
@JeebPreview(
  group: 'settlement',
  name: 'Unavailable · no seam',
  size: _settlementScreenPhoneBox,
)
Widget settlementScreenUnavailable() => const SettlementScreen();

/// The layout ceiling, on the narrowest device this app supports.
///
/// `matrix: true` and [_settlementScreenCompactBox]: 320 pt is where the label
/// column is thinnest, and 200% text is where the trailing chip claims most of
/// what is left. Front-loaded with the rows that break —
///
///   * a year-boundary period with an adjustment note beside a five-figure
///     payout, which is what the row's `Expanded` has to absorb;
///   * two statements whose `weekLabel` the gateway omitted. `fromJson`
///     defaults that to `''` and `_StatementRow` prints it unguarded, so the
///     card's title line is blank and the amount is the only thing
///     identifying it. This is a real 200 response, not a contrived one.
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
