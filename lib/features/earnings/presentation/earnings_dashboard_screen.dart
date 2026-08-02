import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';
import 'package:open_file/open_file.dart';

import '../../../core/formatting/money_format.dart';
import '../application/earnings_cubit.dart';
import '../application/earnings_state.dart';
import '../domain/earnings_repository.dart';
import '../domain/earnings_summary.dart';
import 'earnings_dashboard_l10n.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../devtool/catalog/fixtures/earnings_dashboard_screen_fixtures.dart';
import '../../../core/previews/jeeb_preview.dart';

class EarningsDashboardScreen extends StatelessWidget {
  const EarningsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final copy = EarningsDashboardL10n.of(context);
    return Semantics(
      identifier: 'earnings_dashboard_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(title: copy.title),
        body: BlocConsumer<EarningsCubit, EarningsState>(
          listener: _onStateChange,
          builder: (context, state) => _buildBody(context, state, copy),
        ),
      ),
    );
  }

  void _onStateChange(BuildContext context, EarningsState state) {
    if (state.exportMode == EarningsExportMode.done &&
        state.exportedFilePath != null) {
      OpenFile.open(state.exportedFilePath!);
      context.read<EarningsCubit>().resetExport();
    }
    if (state.exportMode == EarningsExportMode.error &&
        state.exportError != null) {
      showOmdsSnackbar(context, message: state.exportError!);
      context.read<EarningsCubit>().resetExport();
    }
  }

  Widget _buildBody(
    BuildContext context,
    EarningsState state,
    EarningsDashboardL10n copy,
  ) {
    if (state.mode == EarningsViewMode.loading) {
      return const Center(child: OmdsLoadingState());
    }
    if (state.mode == EarningsViewMode.error) {
      return OmdsErrorState(
        message: copy.loadError,
        retryLabel: copy.retry,
        onRetry: () => context.read<EarningsCubit>().loadEarnings(),
      );
    }
    final summary = state.summary;
    if (summary == null || summary.isEmpty) {
      return _EmptyEarnings(period: state.period, copy: copy);
    }
    return _ReadyBody(summary: summary, state: state, copy: copy);
  }
}

class _EmptyEarnings extends StatelessWidget {
  const _EmptyEarnings({required this.period, required this.copy});
  final EarningsPeriod period;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    return OmdsPullToRefresh(
      onRefresh: () => context.read<EarningsCubit>().loadEarnings(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Spacing.medium),
        children: [
          _PeriodFilterRow(selectedPeriod: period, copy: copy),
          const SizedBox(height: Spacing.xLarge),
          Semantics(
            identifier: 'earnings_empty',
            container: true,
            child: OmdsEmptyState(
              icon: Icons.payments_outlined,
              title: copy.emptyTitle,
              subtitle: copy.emptyHint,
              buttonText: copy.emptyRefresh,
              onButtonTap: () =>
                  context.read<EarningsCubit>().loadEarnings(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({
    required this.summary,
    required this.state,
    required this.copy,
  });

  final EarningsSummary summary;
  final EarningsState state;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    return OmdsPullToRefresh(
      onRefresh: () => context.read<EarningsCubit>().loadEarnings(),
      child: ListView(
        padding: const EdgeInsets.all(Spacing.medium),
        children: [
          _PeriodFilterRow(selectedPeriod: state.period, copy: copy),
          const SizedBox(height: Spacing.medium),
          _TotalCashCard(summary: summary, copy: copy),
          const SizedBox(height: Spacing.medium),
          _FeesPaidCard(summary: summary, copy: copy),
          const SizedBox(height: Spacing.medium),
          _StatsRow(summary: summary, copy: copy),
          if (summary.memberSince != null) ...[
            const SizedBox(height: Spacing.medium),
            _MemberSinceRow(memberSince: summary.memberSince!, copy: copy),
          ],
          const SizedBox(height: Spacing.large),
          _DeliveryBreakdownList(summary: summary, copy: copy),
          const SizedBox(height: Spacing.large),
          _WalletLink(copy: copy),
          _ActivityLink(copy: copy),
          const SizedBox(height: Spacing.xLarge),
          _ExportButton(exportMode: state.exportMode, copy: copy),
        ],
      ),
    );
  }
}

class _PeriodFilterRow extends StatelessWidget {
  const _PeriodFilterRow({required this.selectedPeriod, required this.copy});
  final EarningsPeriod selectedPeriod;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: EarningsPeriod.values
          .map(
            (p) => _PeriodPill(
              period: p,
              selected: p == selectedPeriod,
              copy: copy,
            ),
          )
          .toList(),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({
    required this.period,
    required this.selected,
    required this.copy,
  });
  final EarningsPeriod period;
  final bool selected;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: Spacing.xSmall),
      child: Semantics(
        identifier: 'earnings_period_${period.name}',
        button: true,
        child: OmdsChip(
          label: _label(period),
          isSelected: selected,
          onTap: () =>
              context.read<EarningsCubit>().loadEarnings(period: period),
        ),
      ),
    );
  }

  String _label(EarningsPeriod p) {
    switch (p) {
      case EarningsPeriod.today:
        return copy.periodToday;
      case EarningsPeriod.week:
        return copy.periodWeek;
      case EarningsPeriod.month:
        return copy.periodMonth;
    }
  }
}

class _TotalCashCard extends StatelessWidget {
  const _TotalCashCard({required this.summary, required this.copy});
  final EarningsSummary summary;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = MoneyFormat.format(
      summary.totalCashEarned,
      currency: summary.currency,
    );
    return Semantics(
      identifier: 'earnings_total_cash',
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(copy.totalCashLabel, style: theme.textTheme.labelLarge),
              const SizedBox(height: Spacing.xSmall),
              Text(
                value,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                semanticsLabel: value,
              ),
              const SizedBox(height: Spacing.twoXSmall),
              Text(
                copy.totalCashHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeesPaidCard extends StatelessWidget {
  const _FeesPaidCard({required this.summary, required this.copy});
  final EarningsSummary summary;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = MoneyFormat.format(
      summary.feesPaid,
      currency: summary.currency,
    );
    return Semantics(
      identifier: 'earnings_fees_paid',
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Row(
            children: [
              Icon(
                Icons.percent_outlined,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.small),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(copy.feesPaidLabel, style: theme.textTheme.titleSmall),
                    const SizedBox(height: Spacing.twoXSmall),
                    Text(
                      copy.feesPaidHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Spacing.small),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                semanticsLabel: value,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.summary, required this.copy});
  final EarningsSummary summary;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            identifier: 'earnings_net_per_offer',
            title: MoneyFormat.format(
              summary.netPerOffer,
              currency: summary.currency,
            ),
            subtitle: copy.netPerOfferLabel,
            hint: copy.netPerOfferHint,
          ),
        ),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: _StatCard(
            identifier: 'earnings_deliveries_count',
            title: '${summary.deliveryCount}',
            subtitle: copy.deliveriesLabel,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.identifier,
    required this.title,
    required this.subtitle,
    this.hint,
  });
  final String identifier;
  final String title;
  final String subtitle;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: identifier,
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.medium),
          child: Column(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.twoXSmall),
              Text(
                subtitle,
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
              if (hint != null) ...[
                const SizedBox(height: Spacing.twoXSmall),
                Text(
                  hint!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberSinceRow extends StatelessWidget {
  const _MemberSinceRow({required this.memberSince, required this.copy});
  final String memberSince;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = _formatDate(memberSince);
    return Semantics(
      identifier: 'earnings_member_since',
      container: true,
      child: Row(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.xSmall),
          Text(copy.memberSinceLabel, style: theme.textTheme.bodyMedium),
          const SizedBox(width: Spacing.xSmall),
          Text(
            formatted,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat.yMMM().format(parsed);
  }
}

class _DeliveryBreakdownList extends StatelessWidget {
  const _DeliveryBreakdownList({required this.summary, required this.copy});
  final EarningsSummary summary;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (summary.deliveries.isEmpty) {
      return Semantics(
        identifier: 'earnings_breakdown_empty',
        container: true,
        child: const OmdsEmptyState(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(copy.breakdownTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: Spacing.xSmall),
        ...summary.deliveries.map((d) => _DeliveryRow(item: d, copy: copy)),
      ],
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.item, required this.copy});
  final EarningsDeliveryItem item;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final cash = MoneyFormat.format(item.cashCollected, currency: item.currency);
    final fee = MoneyFormat.format(item.feePaid, currency: item.currency);
    return Semantics(
      identifier: 'earnings_delivery_row_${item.deliveryId}',
      container: true,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(copy.deliveryRowTitle(item.deliveryId)),
        subtitle: Text(copy.deliveryRowFee(fee)),
        trailing: Text(cash, semanticsLabel: cash),
      ),
    );
  }
}

class _WalletLink extends StatelessWidget {
  const _WalletLink({required this.copy});
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'earnings_wallet_link',
      button: true,
      container: true,
      child: OmdsSettingsRow(
        title: copy.walletLink,
        subtitle: copy.walletLinkSubtitle,
        leadingIcon: Icons.account_balance_wallet_outlined,
        onTap: () => context.pushNamed('wallet'),
      ),
    );
  }
}

class _ActivityLink extends StatelessWidget {
  const _ActivityLink({required this.copy});
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'earnings_activity_link',
      button: true,
      container: true,
      child: OmdsSettingsRow(
        title: copy.activityLink,
        subtitle: copy.activityLinkSubtitle,
        leadingIcon: Icons.receipt_long_outlined,
        onTap: () => context.pushNamed('wallet-activity'),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.exportMode, required this.copy});
  final EarningsExportMode exportMode;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final isLoading = exportMode == EarningsExportMode.exporting;
    return Semantics(
      identifier: 'earnings_export_cta',
      button: true,
      container: true,
      child: OmdsLoadingButton(
        text: copy.exportButton,
        isLoading: isLoading,
        onTap: () {
          if (!isLoading) context.read<EarningsCubit>().exportPdf();
        },
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
// Render tests: test/previews/earnings/earnings_dashboard_screen_preview_test.dart
// ===========================================================================
//
// [EarningsDashboardScreen] is the jeeber's money surface: cash collected
// off-wallet, fees captured from the wallet, and the per-delivery breakdown
// behind them. It has NO seam of its own — no repository parameter, no cubit
// factory — it reads [EarningsCubit] off a `BlocProvider` ancestor. So every
// preview below provides that ancestor itself, over a local fixture repository,
// which is exactly how the route (`EarningsTab`) and the Screen Catalog build
// it. The real cold-load path runs in all three.
//
// The repositories and the summaries they answer with are NOT declared here.
// They live in
// `lib/devtool/catalog/fixtures/earnings_dashboard_screen_fixtures.dart`,
// shared with the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_03_entries.dart`), so the designer's in-app
// browser and this canvas cannot drift into showing two different "designed
// states". None of those repositories can reach the network — they answer from
// a `const` summary, throw, or never complete — and every one of them FAILS
// `exportEarningsPdf`, because a successful export is handed straight to
// `OpenFile.open` by [_onStateChange] and a preview must not call a platform
// channel. The `CatalogNetworkGuard` in [jeebPreviewHost] is the net, not the
// plan.
//
// Two things about this harness are worth knowing before editing it:
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and this
//    screen's own `Scaffold + OMDSAppBar` paints inside it. That is the same
//    nesting the Screen Catalog produces.
//  * **The frame is pinned in the TREE, not just in `size:`.**
//    [_earningsDashboardScreenFramed] pins the same width the annotation asks
//    for, so the render tests measure a phone instead of the 800 pt test
//    surface — and width is the whole point here, since every layout problem
//    below disappears at 800 dp. Height is pinned too, but the render surface
//    is 800x600, so a `SizedBox` asking for 844 is enforced down to what the
//    host has; the COMPACT box (320x568) fits and is therefore exact.
//
// The states are the two the Screen Catalog names plus four it does not, all
// four of which are states that break:
//
//   * **Loading.** The cold read in flight — a bare centred spinner with no
//     copy and nothing to tap. Its render test cannot use `pumpAndSettle`.
//   * **Load failed.** The retry body. Note what it does NOT show: the cubit
//     classifies the failure into three distinct messages
//     (`EarningsCubit._mapError`) and [_buildBody] renders the generic
//     localized `earningsLoadFailed` instead, so network / server / parse are
//     indistinguishable to the jeeber.
//   * **Totals without breakdown rows.** A rollup-only payload — a count with
//     no `items` — which sends [_DeliveryBreakdownList] down its
//     `deliveries.isEmpty` branch. That branch is a bare `OmdsEmptyState()`
//     with no icon, title, subtitle or button: an empty box under a heading
//     that never renders. `earningsBreakdownEmpty` is already translated in
//     both ARBs and is not wired to it.
//   * **Longest content at 320 pt.** The layout ceiling on the narrowest phone
//     the app supports, in the launch market's own currency.
//
// And one PAIR worth reading together: [earningsDashboardScreenEmptyPeriod]
// (nothing recorded — the honest T11 / SW-01 block) beside
// [earningsDashboardScreenTotalsOnly] (something recorded, nothing itemized).
// Both are "there is no list here", and only the first is allowed to say so.

/// The phone this screen is designed against.
const Size _earningsDashboardScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const Size _earningsDashboardScreenCompactBox = Size(320, 568);

/// Pins [screen] to a device-sized frame inside whatever box the host gives it.
Widget _earningsDashboardScreenFramed(
  Widget screen, {
  Size box = _earningsDashboardScreenPhoneBox,
}) {
  return Align(
    alignment: Alignment.topCenter,
    child: SizedBox(width: box.width, height: box.height, child: screen),
  );
}

/// Builds the screen the way its route builds it: an [EarningsCubit] over
/// [repository], provided above the screen, loading from its own constructor.
Widget _earningsDashboardScreenHosted(
  EarningsRepository repository, {
  Size box = _earningsDashboardScreenPhoneBox,
}) {
  return _earningsDashboardScreenFramed(
    BlocProvider<EarningsCubit>(
      create: (_) => EarningsCubit(repository: repository),
      child: const EarningsDashboardScreen(),
    ),
    box: box,
  );
}

/// The reference reading: a week with cash collected, fees captured, a join
/// date and a two-row breakdown.
///
/// Both money framings are on screen at once (D41/D44) — the cash the jeeber
/// keeps off-wallet, and the platform fee paid from the wallet — which is the
/// whole reason this screen was reframed fee-only.
///
/// This is the one the matrix is for, and it is the only place three separate
/// problems show up side by side. In AR the `member since` row keeps a
/// Latin-script month ("Nov 2025"), because [_MemberSinceRow] calls a bare
/// `DateFormat.yMMM()` that resolves through `Intl.getCurrentLocale()` rather
/// than the ambient locale. At 200% text the period pills — an unwrapped,
/// unscrollable `Row` — run 70 dp past the trailing edge, and because nothing
/// scrolls there is no gesture that brings the hidden pill back. And the
/// fees-paid amount is the one child of its `Row` with no flex, so the wider
/// the money token, the narrower the label column beside it.
@JeebPreview(
  group: 'earnings',
  name: 'Populated · cash, fees and breakdown',
  size: _earningsDashboardScreenPhoneBox,
  matrix: true,
)
Widget earningsDashboardScreenPopulated() => _earningsDashboardScreenHosted(
  EarningsDashboardScreenPreviewFixtures.populated(),
);

/// T11 / SW-01 regression guard, made visible.
///
/// A period with nothing recorded must render the honest "nothing yet" block —
/// never "0.00 USD earned · 0 Deliveries · 0.00 fees", which reads as a betrayal
/// ten minutes after a completed cash delivery. If this preview ever shows a
/// headline card, `EarningsSummary.isEmpty` has broken.
///
/// The period pills stay above the block, deliberately: switching period is the
/// one useful thing to do from here. They are also the only control this state
/// offers besides pull-to-refresh, which is why the 200% clip described on
/// [earningsDashboardScreenPopulated] is worse here than anywhere else.
@JeebPreview(
  group: 'earnings',
  name: 'Empty · nothing recorded this period',
  size: _earningsDashboardScreenPhoneBox,
)
Widget earningsDashboardScreenEmptyPeriod() => _earningsDashboardScreenHosted(
  EarningsDashboardScreenPreviewFixtures.empty(),
);

/// The cold read in flight: a centred `OmdsLoadingState` and nothing else.
///
/// Note what is NOT on screen — no period pills, no copy, no way to leave
/// except the app bar. `EarningsState.mode` defaults to `loading`, so this is
/// also the very first frame of every other state below.
///
/// It is the one state whose render test cannot use `pumpAndSettle`: a
/// `CircularProgressIndicator` is an indefinite animation, so the harness's
/// settle would time out. See the dedicated pump-once group in
/// `test/previews/earnings/earnings_dashboard_screen_preview_test.dart`.
@JeebPreview(
  group: 'earnings',
  name: 'Loading · cold read',
  size: _earningsDashboardScreenPhoneBox,
)
Widget earningsDashboardScreenLoading() => _earningsDashboardScreenHosted(
  EarningsDashboardScreenPreviewFixtures.stalledLoad(),
);

/// The cold read failed (a dropped transport, a 500, an unparseable body): the
/// `OmdsErrorState` body with a Retry that re-enters the load.
///
/// The body replaces everything — including the period pills, so a jeeber who
/// failed to load "This month" cannot drop back to "Today" without a successful
/// read first. And the copy is the SAME whatever went wrong: the cubit builds
/// three different (hardcoded, English) messages in `_mapError` and stores them
/// on `state.errorMessage`, which [_buildBody] never reads.
@JeebPreview(
  group: 'earnings',
  name: 'Load failed · retry',
  size: _earningsDashboardScreenPhoneBox,
)
Widget earningsDashboardScreenLoadFailed() => _earningsDashboardScreenHosted(
  EarningsDashboardScreenPreviewFixtures.failingLoad(),
);

/// Totals arrived, the itemization did not: nine deliveries counted, none
/// listed, and no join date on the wire.
///
/// `EarningsSummary.fromJson` reads `deliveryCount` from its own wire field
/// independently of the `items` array, so this is a shape the live gateway can
/// serve, not a stress fixture. It is the only way to see two branches that are
/// otherwise invisible:
///
///  * [_DeliveryBreakdownList] renders `const OmdsEmptyState()` — no icon, no
///    title, no subtitle, no button. It occupies 48 dp of padding and says
///    nothing, under a "Recent deliveries" heading that this branch does not
///    render either. `earningsBreakdownEmpty` ("Completed deliveries for this
///    period will appear here.") is already translated in both ARBs.
///  * [_MemberSinceRow] is skipped entirely, which is the correct behaviour —
///    the join date is never fabricated — but it means the ready body has two
///    quite different heights and only this preview shows the shorter one.
@JeebPreview(
  group: 'earnings',
  name: 'Totals only · no breakdown rows',
  size: _earningsDashboardScreenPhoneBox,
)
Widget earningsDashboardScreenTotalsOnly() => _earningsDashboardScreenHosted(
  EarningsDashboardScreenPreviewFixtures.totalsWithoutRows(),
);

/// The layout ceiling, on the narrowest phone the app supports.
///
/// Everything that can be long is long at once, in the launch market's own
/// currency: `MoneyFormat` renders non-USD as `LBP 128,450,000.00`, which is
/// the widest token this screen can emit — it lands in [_TotalCashCard]'s
/// `displaySmall` headline, in [_FeesPaidCard]'s unflexed trailing `Text`, and
/// in the `ListTile.trailing` of each breakdown row beside a 42-character
/// gateway delivery id.
///
/// `memberSince` here is epoch SECONDS delivered as a string rather than
/// ISO-8601, and that is the second reason this preview exists.
/// [_MemberSinceRow] guards with `DateTime.tryParse(iso) ?? iso`, which reads as
/// "unparseable input is echoed rather than formatted" — but `tryParse` does not
/// return null here. It matches the basic-ISO `yyyyyy-mm-dd` shape
/// (`173059-20-00`), normalizes the out-of-range month, and yields
/// `173060-07-31`, so the row renders a confident **"Member since Jul 173060"**.
/// The guard never fires; the screen states a date it has no basis for.
///
/// Read the AR RTL and 200% renderings rather than the English one: the English
/// stays plausible long after the other two have stopped fitting.
@JeebPreview(
  group: 'earnings',
  name: 'Longest content · compact 320',
  size: _earningsDashboardScreenCompactBox,
  matrix: true,
)
Widget earningsDashboardScreenLongestContent() =>
    _earningsDashboardScreenHosted(
      EarningsDashboardScreenPreviewFixtures.longest(),
      box: _earningsDashboardScreenCompactBox,
    );
