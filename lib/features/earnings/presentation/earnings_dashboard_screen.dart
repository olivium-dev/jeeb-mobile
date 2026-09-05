import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:omds/omds.dart';
import 'package:open_file/open_file.dart';

import '../../../core/accessibility/accessibility.dart';
import '../../../core/formatting/money_format.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_radii.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_shadows.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_glass_card.dart';
import '../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_pull_to_refresh.dart';
import '../../../core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import '../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../core/widgets/jeeb/jeeb_state_host.dart';
import '../application/earnings_cubit.dart';
import '../application/earnings_state.dart';
import '../domain/earnings_repository.dart';
import '../domain/earnings_summary.dart';
import 'earnings_dashboard_l10n.dart';

/// JM-052 — Earnings & Fees Dashboard (MIDNIGHT R19, `tpl 1136–1194`).
///
/// The Earnings tab body:
///   * `earnings_total_cash` — the cash the Jeeber collected directly from
///     customers; this never moves through Jeeb. Eyebrow + `statHero` amount +
///     trust line inside the glass hero.
///   * `earnings_fees_paid` — platform fees the Jeeber paid from their
///     pre-charged wallet on won offers (the glass strip under the hero).
///   * `earnings_net_per_offer` / `earnings_deliveries_count` /
///     `earnings_member_since` — the three hero stats under the hairline.
///     Member-since renders only when the wire surfaces it — never fabricated.
///   * `earnings_wallet_link` → `wallet` (wallet-hub, JM-053) — footer pill.
///   * `earnings_activity_link` → `wallet-activity` (wallet-activity-list,
///     JM-055) — re-homed onto the board-drawn period header (doc-13 Pattern D:
///     a frozen id may move onto a drawn element; the added "See all" chrome
///     the board never draws is deleted).
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
/// MOTION: `03-MOTION-NOTES.md` §R19 — **0 animated elements**. The field's
/// decor is pinned (`animateDecor: false`) and nothing on this screen moves.
///
/// D41/D44: fee-only framing throughout — "Platform fees paid", never
/// "Commission", never a gross/net payout line. The board's `Jeeb fees paid`
/// wording is a recorded refusal (02-STUDY-NOTES §5 / `19-earnings.md` §2).
class EarningsDashboardScreen extends StatelessWidget {
  const EarningsDashboardScreen({super.key});

  /// `tpl 1140` — the 24px page gutter with a lead-in above the title.
  static const EdgeInsetsGeometry _headerPadding =
      EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.medium,
        Spacing.xLarge,
        0,
      );

  /// `tpl 1141` — the period row owns its own horizontal gutter (it scrolls),
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
    if (state.exportMode == EarningsExportMode.error) {
      final cubit = context.read<EarningsCubit>();
      showJeebErrorSnack(
        context,
        failure: state.exportFailure ?? const UnknownFailure(),
        identifier: 'earnings_export_error_snack',
        retryLabel: EarningsDashboardL10n.of(context).retry,
        onRetry: cubit.exportPdf,
      );
      cubit.resetExport();
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
    final isFunded =
        state.mode == EarningsViewMode.ready &&
        summary != null &&
        !summary.isEmpty;
    // `expand`: Scaffold lays its body out LOOSE, so the field's Stack would
    // otherwise shrink-wrap a short state and leave the page bottom unpainted.
    return SizedBox.expand(
      child: JeebMidnightField(
        variant: JeebFieldVariant.content,
        // `tpl 1136` draws ONE orange glow at 85%/-6% and no rings, wash or
        // twinkles — `content` at the ratified `topEnd`, and it does not move.
        animateDecor: false,
        // Both insets are consumed: the shell already ate the top, and on the
        // pushed `/earnings` route this is what keeps the title off the bar.
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: _headerPadding,
                child: Text(
                  copy.title,
                  style: context.jeebText.h2.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              // Always mounted, in every state: switching period is how a jeeber
              // recovers from an empty or failed load.
              Padding(
                padding: _periodRowPadding,
                child: _PeriodFilterRow(
                  selectedPeriod: state.period,
                  copy: copy,
                ),
              ),
              Expanded(child: _stateBody(context, state, summary, copy)),
              if (isFunded) _EarningsFooter(state: state, copy: copy),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stateBody(
    BuildContext context,
    EarningsState state,
    EarningsSummary? summary,
    EarningsDashboardL10n copy,
  ) {
    final cubit = context.read<EarningsCubit>();
    if (state.mode == EarningsViewMode.loading) {
      return JeebStateHost(
        child: JeebEmptyState.compact(
          status: JeebEmptyStateStatus.loading,
          reason: JeebEmptyStateReason.loading,
          headline: copy.loadingHeadline,
          identifier: 'earnings_loading',
        ),
      );
    }
    // Error before empty (R6): a failed read is never reported as "no data".
    if (state.mode == EarningsViewMode.error) {
      return JeebStateHost(
        onRefresh: cubit.refresh,
        child: JeebFailureBlock.compact(
          failure: state.failure ?? const UnknownFailure(),
          identifier: 'earnings_error',
          retryIdentifier: 'earnings_retry_cta',
          exitIdentifier: 'earnings_exit_cta',
          variant: JeebEmptyStateVariant.pocket,
          onRetry: cubit.loadEarnings,
          onExit: _earningsExit(context, state.failure),
        ),
      );
    }
    // T11 / SW-01: no data for the period → honest empty state, never a wall of
    // confident zeros. Pills + pull-to-refresh stay so the jeeber can recover.
    if (summary == null || summary.isEmpty) {
      return _EmptyEarnings(copy: copy, refreshError: state.refreshError);
    }
    return _ReadyBody(summary: summary, state: state, copy: copy);
  }
}

/// R6: an unrecoverable kind gets a way out, never a headline with no act. An
/// expired session leaves to the root, where the redirect lands on sign-in.
VoidCallback _earningsExit(BuildContext context, AppFailure? failure) =>
    failure is UnauthorizedFailure
    ? () => context.go('/')
    : () => context.canPop() ? context.pop() : context.go('/');

/// Honest empty/pending body shown when the wire has no earnings for the
/// period. Deliberately money-free: no hero, no fee strip, no footer.
class _EmptyEarnings extends StatelessWidget {
  const _EmptyEarnings({required this.copy, this.refreshError});

  final EarningsDashboardL10n copy;
  final AppFailure? refreshError;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EarningsCubit>();
    final warm = refreshError;
    return JeebPullToRefresh(
      onRefresh: cubit.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.all(Spacing.xLarge),
        children: [
          if (warm != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Spacing.small),
              child: JeebRefreshFailedNote(
                failure: warm,
                identifier: 'earnings_refresh_failed_note',
                onRetry: cubit.refresh,
                onDismiss: cubit.clearRefreshError,
              ),
            ),
          JeebEmptyState.compact(
            headline: copy.emptyTitle,
            body: copy.emptyHint,
            reason: JeebEmptyStateReason.nothingYet,
            identifier: 'earnings_empty',
            // E1's mic + shopping medallions are the CLIENT's "bring me
            // anything"; a jeeber's empty ledger gets a money mark instead.
            center: const _EarningsMark(glyph: Icons.payments),
            medallions: const [],
            action: JeebCtaButton.outline(
              label: copy.emptyRefresh,
              expand: false,
              identifier: 'earnings_empty_refresh_cta',
              onTap: cubit.refresh,
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

  /// `tpl 1157` — the breakdown band's lead-in, and `tpl 1159` its 10 under the
  /// section label.
  static const double _bandLeadIn = 18;
  static const double _labelToRows = 10;

  final EarningsSummary summary;
  final EarningsState state;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final deliveries = summary.deliveries;
    final cubit = context.read<EarningsCubit>();
    final warm = state.refreshError;
    return JeebPullToRefresh(
      onRefresh: cubit.refresh,
      child: ListView(
        // R1 density: with two or three rows the list simply ends and the field
        // below it is the design. No Spacer, no centring, no shrinkWrap.
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.xLarge,
        ),
        children: [
          if (warm != null) ...[
            const SizedBox(height: Spacing.small),
            JeebRefreshFailedNote(
              failure: warm,
              identifier: 'earnings_refresh_failed_note',
              onRetry: cubit.refresh,
              onDismiss: cubit.clearRefreshError,
            ),
          ],
          const SizedBox(height: Spacing.medium),
          _CashHero(summary: summary, copy: copy),
          const SizedBox(height: Spacing.small),
          _FeeStrip(summary: summary, copy: copy),
          const SizedBox(height: _bandLeadIn),
          _BreakdownHeader(period: state.period, copy: copy),
          const SizedBox(height: _labelToRows),
          if (deliveries.isEmpty)
            JeebEmptyState.compact(
              headline: copy.breakdownEmptyTitle,
              reason: JeebEmptyStateReason.nothingYet,
              identifier: 'earnings_breakdown_empty',
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
    // Scrollable, not fixed: three 48dp targets overflow at the 200% scale the
    // a11y AC requires. The kit's form is non-lazy, so every id stays findable.
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
      selected: selected,
      // The kit capsule stays under 48dp on purpose; the tap target is this
      // wrapper, which owns the gesture.
      child: MinTapTarget(
        onTap: () => context.read<EarningsCubit>().loadEarnings(period: period),
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

/// The glass cash hero (`tpl 1145–1156`): eyebrow + `statHero` amount + trust
/// line, a hairline, then three stats — over its own orange inner glow.
///
/// This is the screen's ONE real `BackdropFilter` (§4 budget ≤2): the board
/// draws `backdrop-filter: blur(16px)` here and nowhere else on R19.
///
/// `earnings_total_cash` is scoped to the amount block rather than the whole
/// card so the three stat ids stay flat siblings.
class _CashHero extends StatelessWidget {
  const _CashHero({required this.summary, required this.copy});

  /// `tpl 1146` — Ø150 orange radial at top-END, offset −40/−40, core 40%,
  /// transparent at 70%.
  static const double _glowDiameter = 150;
  static const double _glowInset = -40;
  static const double _glowCoreAlpha = 0.4;
  static const double _glowStop = 0.7;

  /// `tpl 1150` — 6 under the eyebrow, 4 under the amount, 14 above and below
  /// the hairline, 18 between stat columns.
  static const double _eyebrowGap = 6;
  static const double _hairlineGap = 14;
  static const double _statGap = 18;
  static const double _dividerThickness = 1;

  final EarningsSummary summary;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = _semantics(context);
    final accent = context.jeebRoles.accent;
    final value = MoneyFormat.format(
      summary.totalCashEarned,
      currency: summary.currency,
    );
    final netPerOffer = MoneyFormat.format(
      summary.netPerOffer,
      currency: summary.currency,
    );
    final memberSince = summary.memberSince;
    return JeebGlassCapsule(
      radius: JeebRadii.xl,
      blurSigma: JeebGlassCapsule.heroBlur,
      shadow: JeebShadows.floatNav,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          PositionedDirectional(
            top: _glowInset,
            end: _glowInset,
            width: _glowDiameter,
            height: _glowDiameter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: _glowCoreAlpha),
                    accent.withValues(alpha: 0),
                  ],
                  stops: const [0, _glowStop],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(Spacing.large),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  identifier: 'earnings_total_cash',
                  container: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Uppercased inside the widget so AR passes through
                      // untouched — never `.toUpperCase()` at the call site.
                      JeebSectionLabel(copy.totalCashLabel),
                      const SizedBox(height: _eyebrowGap),
                      Text(
                        value,
                        style: context.jeebText.statHero.copyWith(
                          color: scheme.onSurface,
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
                const SizedBox(height: _hairlineGap),
                SizedBox(
                  width: double.infinity,
                  height: _dividerThickness,
                  child: ColoredBox(color: semantic.glassBorder),
                ),
                const SizedBox(height: _hairlineGap),
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
                    const SizedBox(width: _statGap),
                    Flexible(
                      child: Semantics(
                        identifier: 'earnings_net_per_offer',
                        container: true,
                        // The D44 explanation lost its visual slot in the
                        // compressed hero; it survives here so it is announced.
                        hint: copy.netPerOfferHint,
                        child: _HeroStat(
                          value: netPerOffer,
                          valueSemanticsLabel: netPerOffer,
                          label: copy.netPerOfferLabel,
                        ),
                      ),
                    ),
                    // TODO(midnight): omitted, not faked — the board's stat #3
                    // is `★ 4.8`, a rating the wire has no field for (Pattern A).
                    if (memberSince != null) ...[
                      const SizedBox(width: _statGap),
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

/// One of the hero's three stat columns (`tpl 1152–1154`) — value `17/w800`
/// white over an `11/w600` periwinkle label. Layout only: the board draws no
/// card here, so this is not a private copy of a kit widget.
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
    final semantic = _semantics(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: context.jeebText.titleProminent.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
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

/// `earnings_fees_paid` — the glass fee strip (`tpl 1157`).
///
/// A single-value row, NOT a `JeebMoneyBreakdown`: the board draws no label /
/// value rows, no divider, no total and no lock footnote here.
class _FeeStrip extends StatelessWidget {
  const _FeeStrip({required this.summary, required this.copy});

  /// `tpl 1158` — the Ø36 white-10% disc carrying the `%` glyph.
  static const double _discSize = 36;
  static const double _discGlyph = 18;

  final EarningsSummary summary;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = _semantics(context);
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
            SizedBox.square(
              dimension: _discSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: semantic.glassFillEmphasis,
                ),
                // Filled, single-colour (R10). A bare "%" Text has no l10n home.
                child: Icon(
                  Icons.percent,
                  size: _discGlyph,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // D41/D44: "Platform fees paid". The board's Jeeb-branded
                  // "Jeeb fees paid" is a recorded refusal, not a defect.
                  Text(
                    copy.feesPaidLabel,
                    style: context.jeebText.cardTitle.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    copy.feesPaidHint,
                    style: context.jeebText.caption.copyWith(
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
                color: scheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
              semanticsLabel: value,
            ),
          ],
        ),
      ),
    );
  }
}

/// The breakdown section header (`tpl 1158`) — the period label, uppercased.
///
/// The board draws no "See all" link. doc-13 Pattern D: the frozen
/// `earnings_activity_link` id is RE-HOMED onto this drawn label (which is
/// tappable and still reaches wallet-activity), and the added pill is deleted.
class _BreakdownHeader extends StatelessWidget {
  const _BreakdownHeader({required this.period, required this.copy});

  final EarningsPeriod period;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'earnings_activity_link',
      button: true,
      container: true,
      // The visible label is the PERIOD ("THIS WEEK"); the screen reader still
      // hears what the section is and where the tap goes.
      label: copy.breakdownTitle,
      hint: copy.activityLink,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.pushNamed('wallet-activity'),
        child: JeebSectionLabel(copy.period(period.name)),
      ),
    );
  }
}

/// One glass delivery row (`tpl 1160–1162`).
class _DeliveryRow extends StatelessWidget {
  const _DeliveryRow({required this.item, required this.copy});

  /// `tpl 1160` — the row's own gap, tighter than [JeebListRow]'s 12 default.
  static const double _rowGap = 10;

  final EarningsDeliveryItem item;
  final EarningsDashboardL10n copy;

  @override
  Widget build(BuildContext context) {
    // BLOCKED on wiring/19-earnings.md §A: `signed:` keeps the `+` inside the
    // LTR isolate; `'+' + …` renders on the wrong side in Arabic (bidi ES).
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
      // TODO(midnight): omitted, not faked — the board's `⚡ Pharmacy run` tier
      // and item name are absent from `{deliveryId, amount, syncedAt}`.
      child: JeebOutlinedCard(
        padding: EdgeInsets.zero,
        child: JeebListRow(
          title: title,
          subtitle: copy.deliveryRowFee(fee),
          showChevron: false,
          gap: _rowGap,
          trailing: Text(
            cash,
            style: context.jeebText.cardTitle.copyWith(
              color: context.jeebRoles.onSuccessContainer,
              fontWeight: FontWeight.w800,
            ),
            semanticsLabel: cash,
          ),
        ),
      ),
    );
  }
}

/// The docked footer (`tpl 1167–1170`): glass wallet pill + orange export CTA,
/// two equal halves 10 apart.
class _EarningsFooter extends StatelessWidget {
  const _EarningsFooter({required this.state, required this.copy});

  /// The board draws both pills at 52 (`tpl 1168-1169`). The kit's per-variant
  /// defaults (50 outline / 56 accent) would misalign the pair, so both are
  /// pinned here rather than either being left to its default.
  static const double _pillHeight = 52;
  static const double _pillGap = 10;

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
      spacing: _pillGap,
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
        // `accent`, not `primary`: `tpl 1169` draws the solid orange pill with
        // the `ctaOrange` lift (wave-A ruling).
        child: JeebCtaButton.accent(
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

/// The centre disc of this screen's [JeebEmptyState] illustrations — the kit's
/// 94×94 `center` slot, glass over the ring so the ledger reads as money rather
/// than as a client's shopping run.
class _EarningsMark extends StatelessWidget {
  const _EarningsMark({required this.glyph});

  static const double _disc = 94;
  static const double _glyphSize = 46;

  final IconData glyph;

  @override
  Widget build(BuildContext context) {
    final semantic = _semantics(context);
    return Center(
      child: SizedBox.square(
        dimension: _disc,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: semantic.glassFillEmphasis,
            border: Border.fromBorderSide(
              BorderSide(color: semantic.glassBorderStrong),
            ),
          ),
          child: Icon(
            glyph,
            size: _glyphSize,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Never a bare `!`: harnesses themed with `ThemeData.light()` carry no
/// extension, and the bang would crash every widget test.
JeebSemanticColors _semantics(BuildContext context) =>
    Theme.of(context).extension<JeebSemanticColors>() ??
    JeebSemanticColors.midnight();
