import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';
import 'package:open_file/open_file.dart';

import '../../../core/accessibility/accessibility.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_shadows.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../core/widgets/jeeb/jeeb_navy_surface_card.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../application/earnings_cubit.dart';
import '../application/earnings_state.dart';
import '../domain/earnings_repository.dart';
import '../domain/earnings_summary.dart';
import 'earnings_dashboard_l10n.dart';

/// JM-052 — Earnings & Fees Dashboard (redesign-2026-08 screen 19).
///
/// The Earnings tab body:
///   * `earnings_total_cash` — the cash the Jeeber collected directly from
///     customers; this never moves through Jeeb. Now the eyebrow + 38px
///     amount + trust line inside the navy hero.
///   * `earnings_fees_paid` — platform fees the Jeeber paid from their
///     pre-charged wallet on won offers (the outlined strip under the hero).
///   * `earnings_net_per_offer` / `earnings_deliveries_count` /
///     `earnings_member_since` — the three hero stats under the hairline.
///     Member-since renders only when the wire surfaces it — never fabricated.
///   * `earnings_wallet_link` → `wallet` (wallet-hub, JM-053) — footer pill.
///   * `earnings_activity_link` → `wallet-activity` (wallet-activity-list,
///     JM-055) — the section header's trailing link.
///
/// Both cross-feature links target routes that are REGISTERED today, so they
/// are real `pushNamed` edges — NOT guarded coming-soon. The hub's
/// `wallet_earnings_row` lands here.
///
/// The screen is mounted twice from ONE provider (`EarningsTab`): as the
/// jeeber shell tab and as the standalone `/earnings` route. It carries **no**
/// app bar (the board is a tab root with a bare title), so the pushed route
/// relies on system / predictive back rather than an auto back button.
///
/// Data: `GET /v1/jeeb/earnings?jeeberId=&period=` via `sl<EarningsRepository>()`
/// (→ `DioEarningsRepository`). The gateway rewrites `/v1/jeeb/earnings` →
/// `/wallet-service/v1/jeeb/earnings` on :4010.
///
/// D41/D44: fee-only framing throughout — "Platform fees paid", never
/// "Commission", never a gross/net payout line. The board's `Jeeb fees paid`
/// wording and its `★ 4.8 / This week` hero stat are deliberately NOT shipped
/// (see `docs/redesign-2026-08/per-screen-revised/19-earnings.md` §2).
class EarningsDashboardScreen extends StatelessWidget {
  const EarningsDashboardScreen({super.key});

  /// `html:15` — the 24px page gutter with a 16px lead-in above the title.
  static const EdgeInsetsGeometry _headerPadding =
      EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.medium,
          Spacing.xLarge, 0);

  /// `html:16` — the period row owns its own horizontal gutter (it scrolls),
  /// so only the lead-in is applied from outside.
  static const EdgeInsetsGeometry _periodRowPadding =
      EdgeInsetsDirectional.only(top: Spacing.medium);

  @override
  Widget build(BuildContext context) {
    final copy = EarningsDashboardL10n.of(context);
    return Semantics(
      identifier: 'earnings_dashboard_root',
      container: true,
      child: Scaffold(
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
      // EXEMPT: OMDS exports no standalone toast/snackbar widget; showOmdsSnackbar
      // is the approved fleet pattern for transient error feedback.
      showOmdsSnackbar(context, message: state.exportError!);
      context.read<EarningsCubit>().resetExport();
    }
  }

  Widget _buildBody(
    BuildContext context,
    EarningsState state,
    EarningsDashboardL10n copy,
  ) {
    final theme = Theme.of(context);
    final summary = state.summary;
    // The footer and the money widgets are funded-state only: an empty period
    // must stay free of every amount (T11 / SW-01), including a wallet pill.
    final isFunded = state.mode == EarningsViewMode.ready &&
        summary != null &&
        !summary.isEmpty;
    // Both insets are consumed: inside the shell the top is already gone and
    // the bottom carries the nav-bar reservation; on the pushed `/earnings`
    // route this is the only thing keeping the title off the status bar.
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: _headerPadding,
            child: Text(
              copy.title,
              style: context.jeebText.h2.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          // Always mounted, in every state: switching period is how a jeeber
          // recovers from an empty or failed load.
          Padding(
            padding: _periodRowPadding,
            child: _PeriodFilterRow(selectedPeriod: state.period, copy: copy),
          ),
          Expanded(child: _stateBody(context, state, summary, copy)),
          if (isFunded) _EarningsFooter(state: state, copy: copy),
        ],
      ),
    );
  }

  Widget _stateBody(
    BuildContext context,
    EarningsState state,
    EarningsSummary? summary,
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
    // T11 / SW-01: no data for the period → honest empty/pending state, never a
    // wall of confident zeros. Period pills + pull-to-refresh stay so the jeeber
    // can retry or switch period.
    if (summary == null || summary.isEmpty) {
      return _EmptyEarnings(copy: copy);
    }
    return _ReadyBody(summary: summary, state: state, copy: copy);
  }
}

/// Honest empty/pending body shown when the wire has no earnings for the
/// period. Deliberately money-free: no hero, no fee strip, no footer.
class _EmptyEarnings extends StatelessWidget {
  const _EmptyEarnings({required this.copy});

  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    return OmdsPullToRefresh(
      onRefresh: () => context.read<EarningsCubit>().loadEarnings(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.all(Spacing.xLarge),
        children: [
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
    final deliveries = summary.deliveries;
    return OmdsPullToRefresh(
      onRefresh: () => context.read<EarningsCubit>().loadEarnings(),
      child: ListView(
        // R1 density: with two or three rows the list simply ends and the
        // white below it is the design. No Spacer, no centring, no shrinkWrap.
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.xLarge,
        ),
        children: [
          const SizedBox(height: Spacing.medium),
          _CashHero(summary: summary, copy: copy),
          const SizedBox(height: Spacing.small),
          _FeeStrip(summary: summary, copy: copy),
          const SizedBox(height: Spacing.medium),
          _BreakdownHeader(period: state.period, copy: copy),
          const SizedBox(height: Spacing.xSmall),
          if (deliveries.isEmpty)
            Semantics(
              identifier: 'earnings_breakdown_empty',
              container: true,
              child: const OmdsEmptyState(),
            )
          else
            for (var i = 0; i < deliveries.length; i++) ...[
              if (i > 0) const SizedBox(height: Spacing.xSmall),
              _DeliveryRow(item: deliveries[i], copy: copy),
            ],
          const SizedBox(height: Spacing.medium),
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
    // Scrollable, not fixed: three 48dp targets fit comfortably at 1x but not
    // at the 200% text scale the a11y AC requires, and a fixed Row overflows
    // there. The kit's scrollable form is non-lazy, so every
    // `earnings_period_*` identifier stays findable even when it scrolls off.
    // The gutter lives here so the trailing pill scrolls clear of the edge.
    return JeebChipRow.scrollable(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.xLarge,
      ),
      children: [
        for (final period in EarningsPeriod.values)
          _PeriodPill(
            period: period,
            selected: period == selectedPeriod,
            copy: copy,
          ),
      ],
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
    return Semantics(
      identifier: 'earnings_period_${period.name}',
      button: true,
      // The kit capsule stays under 48dp on purpose; the tap target is this
      // wrapper, which owns the gesture (its IgnorePointer makes a second
      // handler on the chip dead weight).
      child: MinTapTarget(
        onTap: () =>
            context.read<EarningsCubit>().loadEarnings(period: period),
        child: JeebSelectChip(
          role: JeebChipRole.sort,
          label: _label(period),
          selected: selected,
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

/// The navy hero (`html:22-32`): eyebrow + 38px cash amount + trust line, a
/// hairline, then three stats.
///
/// `earnings_total_cash` is scoped to the amount block rather than the whole
/// card so the three stat ids stay flat siblings — `JeebNavySurfaceCard` adds
/// no Semantics node of its own here, so nothing swallows them.
class _CashHero extends StatelessWidget {
  const _CashHero({required this.summary, required this.copy});

  /// The board's on-navy divider (`html:27`) — 1px white at 12%. NOT
  /// `outlineVariant`: that is a light-surface ink and vanishes on navy.
  static const double _dividerThickness = 1;
  static const double _dividerOpacity = 0.12;

  final EarningsSummary summary;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Never a bare `!`: `wrapForTest` themes with ThemeData.light(), where the
    // extension is absent, and the bang would crash every widget test.
    final semantic = theme.extension<JeebSemanticColors>() ??
        JeebSemanticColors.light();
    final value = MoneyFormat.format(
      summary.totalCashEarned,
      currency: summary.currency,
    );
    final netPerOffer = MoneyFormat.format(
      summary.netPerOffer,
      currency: summary.currency,
    );
    final memberSince = summary.memberSince;
    return JeebNavySurfaceCard(
      radius: Spacing.large,
      padding: const EdgeInsetsDirectional.all(Spacing.large),
      shadow: JeebShadows.heroNavy,
      rings: const [JeebNavyRing.statTopEnd],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            identifier: 'earnings_total_cash',
            container: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Uppercased inside the widget so AR passes through untouched —
                // never `.toUpperCase()` at the call site.
                JeebSectionLabel(copy.totalCashLabel),
                const SizedBox(height: Spacing.xSmall),
                Text(
                  value,
                  style: context.jeebText.statHero.copyWith(
                    color: scheme.onPrimary,
                  ),
                  semanticsLabel: value,
                ),
                const SizedBox(height: Spacing.twoXSmall),
                Text(
                  copy.totalCashHint,
                  style: context.jeebText.bodySmall.copyWith(
                    color: semantic.mutedText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.small),
          SizedBox(
            width: double.infinity,
            height: _dividerThickness,
            child: ColoredBox(
              color: scheme.onPrimary.withValues(alpha: _dividerOpacity),
            ),
          ),
          const SizedBox(height: Spacing.small),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Semantics(
                  identifier: 'earnings_deliveries_count',
                  container: true,
                  child: _HeroStat(
                    value: '${summary.deliveryCount}',
                    label: copy.deliveriesLabel,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.large),
              Flexible(
                child: Semantics(
                  identifier: 'earnings_net_per_offer',
                  container: true,
                  // The D44 explanation lost its visual slot in the compressed
                  // hero; it survives here so it is still announced.
                  hint: copy.netPerOfferHint,
                  child: _HeroStat(
                    value: netPerOffer,
                    valueSemanticsLabel: netPerOffer,
                    label: copy.netPerOfferLabel,
                  ),
                ),
              ),
              // Same condition as before the rebuild: the join date is rendered
              // only when the wire surfaces it, never fabricated.
              if (memberSince != null) ...[
                const SizedBox(width: Spacing.large),
                Flexible(
                  child: Semantics(
                    identifier: 'earnings_member_since',
                    container: true,
                    child: _HeroStat(
                      value: _formatMonth(memberSince),
                      label: copy.memberSinceLabel,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _formatMonth(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat.yMMM().format(parsed);
  }
}

/// One of the hero's three stat columns (`html:28-30`). Layout only — the
/// board draws no card here, so this is not a private copy of a kit widget.
class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.value,
    required this.label,
    this.valueSemanticsLabel,
  });

  final String value;
  final String label;
  final String? valueSemanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<JeebSemanticColors>() ??
        JeebSemanticColors.light();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: context.jeebText.titleProminent.copyWith(
            color: theme.colorScheme.onPrimary,
          ),
          semanticsLabel: valueSemanticsLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: Spacing.twoXSmall),
        Text(
          label,
          style: context.jeebText.caption.copyWith(color: semantic.mutedText),
          // Two lines so `ar` at 200% wraps instead of clipping.
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// `earnings_fees_paid` — the outlined fee strip (`html:34-41`).
///
/// A single-value row, NOT a `JeebMoneyBreakdown`: the board draws no label /
/// value rows, no divider, no total and no lock footnote here.
class _FeeStrip extends StatelessWidget {
  const _FeeStrip({required this.summary, required this.copy});

  final EarningsSummary summary;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = theme.extension<JeebSemanticColors>() ??
        JeebSemanticColors.light();
    final value = MoneyFormat.format(
      summary.feesPaid,
      currency: summary.currency,
    );
    return Semantics(
      identifier: 'earnings_fees_paid',
      container: true,
      child: JeebOutlinedCard(
        child: Row(
          children: [
            Container(
              width: Sizes.threeXLarge,
              height: Sizes.threeXLarge,
              alignment: AlignmentDirectional.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHigh,
              ),
              // Filled, single-colour (R10). A bare "%" Text has no l10n home.
              child: Icon(
                Icons.percent,
                size: Sizes.medium,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // D41/D44: "Platform fees paid". The board's Jeeb-branded
                  // "Jeeb fees paid" is refused — the fee is the platform's.
                  Text(
                    copy.feesPaidLabel,
                    style: context.jeebText.cardTitle.copyWith(
                      color: scheme.primary,
                    ),
                  ),
                  Text(
                    copy.feesPaidHint,
                    style: context.jeebText.bodySmall.copyWith(
                      color: semantic.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Spacing.small),
            Text(
              value,
              style: context.jeebText.titleProminent.copyWith(
                color: scheme.primary,
              ),
              semanticsLabel: value,
            ),
          ],
        ),
      ),
    );
  }
}

/// The breakdown section header (`html:44`) plus the `earnings_activity_link`.
///
/// The board has no activity link here — this placement exists because the
/// identifier is frozen and Maestro AC3 taps it, and the header is the only
/// honest home for a "see everything" affordance.
class _BreakdownHeader extends StatelessWidget {
  const _BreakdownHeader({required this.period, required this.copy});

  final EarningsPeriod period;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          // The visible label is the PERIOD ("THIS WEEK"); the screen reader
          // still hears what the section is.
          child: Semantics(
            label: copy.breakdownTitle,
            child: JeebSectionLabel(copy.period(period.name)),
          ),
        ),
        Semantics(
          identifier: 'earnings_activity_link',
          button: true,
          container: true,
          child: JeebCtaButton.text(
            label: copy.activityLink,
            onTap: () => context.pushNamed('wallet-activity'),
          ),
        ),
      ],
    );
  }
}

/// One grey delivery row (`html:46-50`).
class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.item, required this.copy});

  final EarningsDeliveryItem item;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // BLOCKED on wiring/19-earnings.md §A: `signed:` puts the `+` INSIDE the
    // LTR isolate. `'+' + …` is not an option — U+002B is bidi-class ES and
    // renders on the wrong side of the amount in Arabic. If §A is refused,
    // delete this one argument; the `+` is decorative.
    final cash = MoneyFormat.format(
      item.cashCollected,
      currency: item.currency,
      signed: true,
    );
    final fee = MoneyFormat.format(item.feePaid, currency: item.currency);
    final date = DateTime.tryParse(item.date);
    final title = date == null
        ? copy.deliveryRowTitle(item.deliveryId)
        : copy.deliveryRowTitleDated(
            item.deliveryId,
            DateFormat.E().format(date),
          );
    return Semantics(
      identifier: 'earnings_delivery_row_${item.deliveryId}',
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: OmdsBorderRadius.medium,
        ),
        // TODO(redesign-24): the board leads each row with a tier emoji and
        // names the item ("Pharmacy run"). The wire entry is
        // `{deliveryId, amount, syncedAt}` — no tier, no item name — so both
        // are omitted rather than faked.
        child: JeebListRow(
          title: title,
          subtitle: copy.deliveryRowFee(fee),
          showChevron: false,
          trailing: Text(
            cash,
            style: context.jeebText.cardTitle.copyWith(color: scheme.primary),
            semanticsLabel: cash,
          ),
        ),
      ),
    );
  }
}

/// The docked footer (`html:64-67`): wallet pill + export CTA, two equal
/// halves.
class _EarningsFooter extends StatelessWidget {
  const _EarningsFooter({required this.state, required this.copy});

  /// The board draws both pills at 52 (`html:65-66`). The kit's per-variant
  /// defaults (50 outline / 56 primary) would misalign the pair, so both are
  /// pinned here rather than either being left to its default.
  static const double _pillHeight = 52;

  final EarningsState state;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final balance = state.walletBalance;
    // Never a placeholder: the balance suffix appears only once a real wallet
    // read has landed, so `$0.00` can only ever be a genuine fetched zero.
    final walletLabel = balance == null
        ? copy.walletLink
        : '${copy.walletLink} · '
            '${MoneyFormat.format(balance.availableBalance, currency: balance.currency)}';
    return JeebCtaFooter.split(
      expandLeading: true,
      leading: Semantics(
        identifier: 'earnings_wallet_link',
        button: true,
        container: true,
        child: JeebCtaButton.outline(
          label: walletLabel,
          height: _pillHeight,
          onTap: () => context.pushNamed('wallet'),
        ),
      ),
      trailing: Semantics(
        identifier: 'earnings_export_cta',
        button: true,
        container: true,
        child: JeebCtaButton.primary(
          label: copy.exportButton,
          height: _pillHeight,
          // `isInteractive` already suppresses the tap while loading, so no
          // manual re-entrancy guard is needed at the call site.
          isLoading: state.exportMode == EarningsExportMode.exporting,
          onTap: () => context.read<EarningsCubit>().exportPdf(),
        ),
      ),
    );
  }
}
