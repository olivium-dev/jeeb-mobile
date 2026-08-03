import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../core/dev_seam/dev_seam.dart';
import '../../core/lifecycle/route_visibility.dart';
import '../../core/notifications/application/badge_count_cubit.dart';
import '../../core/role/role_availability_cubit.dart';
import '../../core/theme/jeeb_text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../customer_profile/domain/customer_profile_view_data.dart';
import '../customer_profile/presentation/customer_profile_screen.dart';
import '../home_client/domain/client_home_repository.dart';
import '../order_history/domain/order_repository.dart';
import 'tab_visibility.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/earnings_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/orders_tab.dart';
import 'widgets/jeeber_tab_empty_state.dart';
import 'widgets/shell_header_actions.dart';

/// Unified bottom-nav shell implementing the CORE UX RULE (`docs/orchestrator/
/// 05-constraints-and-ground-truth.md`): **a jeeber is also a user.**
///
/// There is NO role switch and NO role-gated tab set. EVERY user sees the same
/// five additive destinations:
///
///   Requests · Delivery · Jeeber(Dashboard) · Earnings · Profile
///
/// The first two + Profile are the regular-user surfaces; **Dashboard** (the
/// availability + request feed) and **Earnings** are the jeeber surfaces, added
/// to every user's shell. A regular (non-jeeber) user sees the SAME jeeber-tab
/// scaffolding but with EMPTY STATES ([JeeberTabEmptyState]) inviting them to
/// become a jeeber — never a mode switch. Whether the live jeeber body or the
/// empty state renders is decided purely by the signed-in user's
/// `available_roles` (gateway Auth/Capabilities surface, getMe →
/// [RoleAvailabilityCubit]); it is additive and reactive, so a user who
/// completes jeeber onboarding lights up the live bodies in place without any
/// in-app role flip.
///
/// BUG-1 (`docs/sprints/sprint-008` Lane B / known-bug #1): the shell must LAND
/// a dual-role jeeber (seed `..0002` Karim) on the **Jeeber surface**, not the
/// client surface. The landing tab is derived from the resolved capabilities
/// ([RoleAvailabilityCubit] ∋ `jeeber`), NOT a hardcoded index: a jeeber lands
/// on the Dashboard tab (so the incoming-request feed — Core Flow step 2 — is
/// the first thing they see) while a plain client lands on Requests. Once the
/// user manually taps a tab their choice sticks, so a late getMe resolution
/// never yanks the page out from under them.
///
/// The bottom bar is the redesign-2026-08 §5.1 bar: a `1px outlineVariant`
/// rule (outline over shadow), a 52×30 `surfaceContainerHigh` pill behind the
/// SELECTED glyph only, and per-tab stable Semantics ids (`shell_tab_*`) so QA
/// can target tabs without matching localized labels. The board draws a single
/// 5-tab bar for both roles; the app's own additive tab model wins (§9-Q1) —
/// the bar was restyled in place, never unified.
class ShellScreen extends StatefulWidget {
  const ShellScreen({
    super.key,
    this.homeRepository,
    this.ordersRepository,
  });

  /// DT-04 catalog seam: overrides the Requests-tab ([HomeTab]) repository.
  /// `null` (every production call site) preserves the existing behavior —
  /// [HomeTab] resolves its own default (GetIt if registered, else an empty
  /// in-memory fake). Lets the screen catalog render a populated/empty Requests
  /// tab without a live gateway.
  final ClientHomeRepository? homeRepository;

  /// DT-04 catalog seam: overrides the Delivery-tab ([OrdersTab]) repository.
  /// `null` (every production call site) preserves the existing behavior —
  /// [OrdersTab] resolves its own default (GetIt if registered, else a bare
  /// Dio, which would attempt a real request). Required for a network-free
  /// catalog preview of the shell.
  final OrderRepository? ordersRepository;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  /// The locale-independent id of the Jeeber surface tab — the landing target
  /// for a user whose capabilities include `jeeber` (BUG-1).
  static const String _jeeberLandingTabId = 'dashboard';

  /// `null` until the user manually selects a tab. While null the shell lands
  /// on the capability-derived initial tab (see [_landingIndex]); once the user
  /// taps a destination this holds their explicit choice so a later capability
  /// resolution (async getMe) never moves them.
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    // The tab SET never changes — additive, not role-gated. Only the jeeber
    // tab BODIES (live vs empty state) AND the landing tab react to the user's
    // available roles (gateway Auth/Capabilities → RoleAvailabilityCubit).
    final availability = context.watch<RoleAvailabilityCubit?>()?.state;
    final showJeeberContent = _showJeeberContent(availability);
    // G3: unseen-open-request count for the Dashboard-tab badge. Nullable
    // watch so bare harnesses without the app-level BadgeCountCubit render
    // badge-less instead of throwing (same idiom as RoleAvailabilityCubit
    // above). FeedResumeRefetcher clears it when the feed is actually
    // viewed, so it never shows while the jeeber is already looking.
    final requestBadgeCount =
        context.watch<BadgeCountCubit?>()?.state.newRequests ?? 0;
    final tabs = _tabs(
      showJeeberContent: showJeeberContent,
      requestBadgeCount: requestBadgeCount,
    );
    final landingIndex = _landingIndex(tabs, isJeeber: showJeeberContent);
    final safeIndex = (_selectedIndex ?? landingIndex).clamp(0, tabs.length - 1);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        // Reserve the persistent bottom-nav bar's height as bottom content
        // inset for every tab (VIS-P1-2) so a tab's last scrollable row — e.g.
        // Profile's Sign out / Rate the app — clears the bar instead of sitting
        // clipped under it. Injected once here, not per-screen.
        //
        // b02 READ ECONOMICS — [RouteVisibilityScope]. `TabVisibility` answers
        // "am I the selected tab", which is NOT the same as "can the user see
        // me": pushing `/delivery/:id` or `/chat/:id` on top of the shell leaves
        // every tab mounted and still selected, so their push-bus subscribers
        // kept reading underneath the pushed route. That was seven of the ten
        // wire reads one `delivery` push produced on the customer phone. ONE
        // scope, mounted on the shell's own route, so every tab can AND
        // route-visibility into its own gate.
        child: RouteVisibilityScope(
          child: _NavBarContentInset(
            // The bar's real painted height, so a taller redesigned bar cannot
            // start clipping the last row of a tab (VIS-P1-2). Read above the
            // Scaffold, where the system bottom inset is still visible.
            barHeight: _barHeight(MediaQuery.paddingOf(context).bottom),
            child: IndexedStack(
              index: safeIndex,
              // Wrap each child in a TabVisibility so a tab body can react to
              // (re)becoming the selected page even though IndexedStack keeps
              // every child mounted. Used by ClientHomeScreen to silently
              // re-pull on refocus. updateShouldNotify only fires for the tab
              // whose visibility actually flips.
              children: [
                for (var i = 0; i < tabs.length; i++)
                  TabVisibility(
                    isVisible: i == safeIndex,
                    child: tabs[i].page,
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _JeebBottomBar(
        tabs: tabs,
        selectedIndex: safeIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }

  /// BUG-1: the tab the shell lands on before the user navigates. A jeeber (by
  /// capability) lands on the additive Jeeber surface ([_jeeberLandingTabId]);
  /// everyone else lands on the first (Requests) tab. Derived from resolved
  /// capabilities, never hardcoded — and falls back to `0` if the jeeber tab is
  /// somehow absent so the shell can never strand on an out-of-range index.
  int _landingIndex(List<_Tab> tabs, {required bool isJeeber}) {
    if (!isJeeber) return 0;
    final jeeberIndex =
        tabs.indexWhere((t) => t.id == _jeeberLandingTabId);
    return jeeberIndex >= 0 ? jeeberIndex : 0;
  }

  /// True when the Jeeber + Earnings tabs should render their LIVE bodies
  /// (availability toggle / feed / earnings dashboard) rather than the
  /// [JeeberTabEmptyState] invitation — and, per BUG-1, when the shell should
  /// land on the Jeeber surface.
  ///
  /// Source of truth is the signed-in user's `available_roles` from the gateway
  /// Auth/Capabilities surface (getMe → [RoleAvailabilityCubit]) — a `jeeber`
  /// membership lights up the live bodies. Never a hardcoded id and never an
  /// in-app role flip.
  ///
  /// Debug-only: the dev seam can force the live jeeber bodies so a single
  /// capture APK renders the feed screens deterministically (the register
  /// prompt via `jeeb.home_tab=unregistered`, the feed variants via
  /// `jeeb.feed=<view>`) without a real getMe round-trip. Always the real
  /// available-roles signal in release.
  bool _showJeeberContent(RoleAvailability? availability) {
    if (kDebugMode) {
      final seam = DevSeam.current;
      if (seam.feed.isNotEmpty || seam.homeTab == 'unregistered') return true;
    }
    return availability?.roles.contains('jeeber') ?? false;
  }

  List<_Tab> _tabs({
    required bool showJeeberContent,
    required int requestBadgeCount,
  }) {
    final l10n = AppLocalizations.of(context);
    return [
      _Tab(
        id: 'requests',
        label: l10n.navRequests,
        icon: Icons.move_to_inbox,
        // Persistent header wallet chip + bell on the Requests header
        // (`orders_home_wallet_chip`/`orders_home_bell`), overlaid by the shell
        // so the per-screen HomeTab surface stays untouched.
        page: _HeaderedTab(
          idPrefix: 'orders_home',
          child: HomeTab(repository: widget.homeRepository),
        ),
      ),
      _Tab(
        id: 'delivery',
        label: l10n.navDelivery,
        icon: Icons.local_shipping,
        page: OrdersTab(repository: widget.ordersRepository),
      ),
      // ADDITIVE jeeber tab #1 — the Jeeber dashboard (availability + feed).
      // A jeeber sees the live [DashboardTab] (with the persistent header
      // actions); a regular user sees the [JeeberTabEmptyState] invitation.
      _Tab(
        id: _jeeberLandingTabId,
        label: l10n.navDashboard,
        icon: Icons.dashboard,
        // G3: unseen open requests badge the tab icon so a dismissed push
        // still leaves a visible trail to the feed.
        badgeCount: requestBadgeCount,
        page: showJeeberContent
            ? const _HeaderedTab(
                idPrefix: 'delivery_tab',
                child: DashboardTab(),
              )
            : const JeeberTabEmptyState.dashboard(),
      ),
      // ADDITIVE jeeber tab #2 — Earnings. A jeeber sees the live earnings
      // dashboard; a regular user sees the same become-a-jeeber empty state.
      _Tab(
        id: 'earnings',
        label: l10n.navEarnings,
        icon: Icons.payments,
        page: showJeeberContent
            ? const EarningsTab()
            : const JeeberTabEmptyState.earnings(),
      ),
      _Tab(
        id: 'profile',
        label: l10n.navProfile,
        icon: Icons.person,
        // The real CustomerProfileScreen surface + header actions. Shared by
        // every user (a jeeber's per-role rating/rows are the profile screen's
        // own concern). Header ids stay `customer_profile_*` (screen-scoped).
        // The seed is intentionally empty: the screen must populate from live
        // `GET /v1/users/me`; on a failed read the profile should look
        // incomplete rather than show a sample person mistaken for real data.
        page: const _HeaderedTab(
          idPrefix: 'customer_profile',
          child: _CustomerProfileTabBody(),
        ),
      ),
    ];
  }
}

/// Re-seeds the bottom system inset for every tab body with the visual height
/// of the persistent [_JeebBottomBar] ([barHeight]), so a tab's last scrollable
/// row clears the bar rather than sitting clipped beneath it (VIS-P1-2).
/// RTL-agnostic — a vertical inset only.
///
/// The outer [Scaffold] already consumes the real system bottom inset for the
/// nav bar, so inside a tab body both `padding.bottom` and `viewPadding.bottom`
/// collapse to `0` and each screen's own `SafeArea` / [BottomInsetX] reserves
/// nothing above the bar. Re-adding the bar height to BOTH insets lets that
/// same double-pad-safe machinery reserve it exactly once, whichever mechanism
/// a given tab uses (a bottom `SafeArea`, `scrollBodyBottomInset`, or neither).
class _NavBarContentInset extends StatelessWidget {
  const _NavBarContentInset({required this.barHeight, required this.child});

  /// The painted height of [_JeebBottomBar] for the current system inset.
  final double barHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        padding: mq.padding.copyWith(bottom: mq.padding.bottom + barHeight),
        viewPadding: mq.viewPadding.copyWith(
          bottom: mq.viewPadding.bottom + barHeight,
        ),
      ),
      child: child,
    );
  }
}

/// Overlays the shell-owned [ShellHeaderActions] (wallet chip + bell) on the
/// top-right of a tab body without touching the per-screen surface. A `Stack`
/// keeps the actions persistent above whatever the [child] renders (a greeting
/// header or an app bar), so the per-screen surfaces own the body while the
/// shell owns the header actions; the `idPrefix` scopes the ids per screen
/// (`orders_home` / `customer_profile` / `delivery_tab`).
class _HeaderedTab extends StatelessWidget {
  const _HeaderedTab({required this.idPrefix, required this.child});

  final String idPrefix;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        PositionedDirectional(
          top: 0,
          end: Spacing.xSmall,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: ShellHeaderActions(idPrefix: idPrefix),
            ),
          ),
        ),
      ],
    );
  }
}

/// The Profile tab body: the real [CustomerProfileScreen].
///
/// Per the CORE UX RULE there is no in-app role *switch* — the jeeber surfaces
/// are additive tabs, not a mode the user flips into from here — so the Profile
/// tab no longer hosts a role toggle.
///
/// The seed is intentionally empty. The screen must populate from live
/// `GET /v1/users/me`; if that read fails, the profile should look incomplete
/// rather than displaying a sample person and being mistaken for real data.
class _CustomerProfileTabBody extends StatelessWidget {
  const _CustomerProfileTabBody();

  @override
  Widget build(BuildContext context) {
    return const CustomerProfileScreen(data: CustomerProfileViewData());
  }
}

// ── Bottom-bar geometry (redesign-2026-08 §5.1, "Not shared") ──────────────
// Measured off `screens/04-client-home.png` @2x: top rule at y1732 (#E5E1E5),
// pill y1758–1817 × x50–153 (52×30, r14), label cap-top y1834, frame bottom
// y1912. OMDS has no bottom-nav primitive and the kit ships none, so these are
// the bar's own tokens rather than a hand-rolled copy of a kit widget.

/// `padding-top: 12` — rule → pill.
const double _kBarTopPadding = Spacing.small;

/// `padding-inline: 8`, with the five items sharing the rest equally.
const double _kBarHorizontalPadding = Spacing.xSmall;

/// `padding-bottom: 26` on the board, which draws no home indicator.
const double _kBarBottomPadding = 26;

/// Glyph box + gap + a 12px label line — the item's natural height, used only
/// to size the content inset tab bodies must reserve ([_NavBarContentInset]).
const double _kBarItemHeight = 52;

/// The selected-tab pill: 52×30, `surfaceContainerHigh`, r14.
const double _kTabPillWidth = 52;
const double _kTabPillHeight = 30;
const double _kTabPillRadius = 14;

/// Every glyph is 22px, selected or not; the pill is what changes.
const double _kTabGlyphSize = 22;

/// Glyph box → label.
const double _kTabGlyphLabelGap = Spacing.twoXSmall;

/// The bar's bottom pad. The board's 26 is the entire gap because its frame has
/// no gesture bar; on a real device the system inset takes over as soon as it
/// needs more room than 26 already gave, so the bar never sits under the home
/// indicator and never doubles the gap on a device that has none.
double _barBottomPadding(double systemInset) =>
    math.max(_kBarBottomPadding, systemInset + Spacing.xSmall);

/// Total painted height of the bar, system inset included — what a tab body
/// must reserve so its last row clears the bar (VIS-P1-2).
double _barHeight(double systemInset) =>
    _kBarTopPadding + _kBarItemHeight + _barBottomPadding(systemInset);

class _JeebBottomBar extends StatelessWidget {
  const _JeebBottomBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<_Tab> tabs;
  final int selectedIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // The device's own gesture bar / home indicator. `paddingOf` (not
    // viewPadding) keeps the pre-redesign SafeArea behavior: the inset
    // collapses while the keyboard covers it.
    final double systemInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        // Outline over shadow (§4/R): the board separates the bar with a 1px
        // rule, not a lift. The old top shadow is gone deliberately.
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          top: _kBarTopPadding,
          start: _kBarHorizontalPadding,
          end: _kBarHorizontalPadding,
          bottom: _barBottomPadding(systemInset),
        ),
        child: Row(
          // Equal columns, laid out start→end, so the bar mirrors in RTL for
          // free (the board's item centers land on the same fifths).
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: _BarItem(
                  tab: tabs[i],
                  isSelected: i == selectedIndex,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  final _Tab tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Navy when selected, periwinkle otherwise. `onSecondaryContainer` IS the
    // periwinkle the spec calls `mutedText` (§4.1); the semantic token of that
    // name is reserved for decoration, and a tab label is text — so glyph and
    // label read the SAME role and can never drift apart in dark mode.
    final Color ink = isSelected
        ? colorScheme.primary
        : colorScheme.onSecondaryContainer;
    final Widget icon = Icon(tab.icon, size: _kTabGlyphSize, color: ink);
    // The 52×30 footprint is constant, so every glyph sits on one line and only
    // the selected one gains a pill.
    final Widget glyph = Container(
      width: _kTabPillWidth,
      height: _kTabPillHeight,
      alignment: Alignment.center,
      decoration: isSelected
          ? BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.all(
                Radius.circular(_kTabPillRadius),
              ),
            )
          : null,
      // G3: M3 count badge (theme error/onError roles — OMDS ships no badge
      // primitive) over the tab glyph when the tab has unseen items; plain
      // glyph otherwise. It hugs the ICON, not the 52-wide pill, or it would
      // float detached at the pill's far edge. Carries `shell_tab_<id>_badge`
      // so QA can assert presence/absence without matching the count text.
      child: tab.badgeCount > 0
          ? Semantics(
              identifier: 'shell_tab_${tab.id}_badge',
              container: true,
              child: Badge.count(count: tab.badgeCount, child: icon),
            )
          : icon,
    );
    return Semantics(
      identifier: 'shell_tab_${tab.id}',
      button: true,
      selected: isSelected,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            glyph,
            const SizedBox(height: _kTabGlyphLabelGap),
            Text(
              tab.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // 12/w700 selected, 12/w600 unselected — `bodySmall` ships the
              // 12/w600 exactly, so only the selected weight is overridden.
              style: context.jeebText.bodySmall.copyWith(
                color: ink,
                fontWeight: isSelected ? FontWeight.w700 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab({
    required this.id,
    required this.label,
    required this.icon,
    required this.page,
    this.badgeCount = 0,
  });

  /// Stable, locale-independent id used for the tab's Semantics identifier so
  /// QA (Maestro) can target tabs without matching on localized labels.
  final String id;
  final String label;

  /// ONE glyph per tab, filled in both states. The board never swaps an
  /// outlined variant in — 04's selected Requests tray and 16's unselected one
  /// are the same solid shape; only the ink (and the pill) change. The M3
  /// outlined/filled dance was the pre-redesign convention.
  final IconData icon;
  final Widget page;

  /// Unseen-item count rendered as an M3 badge over the tab icon; `0` hides
  /// it. Currently driven by [BadgeCounts.newRequests] on the Dashboard tab
  /// (G3).
  final int badgeCount;
}
