import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../core/dev_seam/dev_seam.dart';
import '../../core/lifecycle/route_visibility.dart';
import '../../core/notifications/application/badge_count_cubit.dart';
import '../../core/observability/session_trace/observability.dart';
import '../../core/observability/session_trace/observability_config.dart';
import '../../core/role/role_availability_cubit.dart';
import '../../core/role/role_cubit.dart';
import '../../core/role/user_role.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/jeeb/jeeb_pill_nav.dart';
import '../../l10n/app_localizations.dart';
import '../customer_profile/domain/customer_profile_view_data.dart';
import '../customer_profile/presentation/customer_profile_screen.dart';
import '../home_client/domain/client_home_repository.dart';
import '../home_client/presentation/widgets/client_home_greeting.dart';
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
/// MIDNIGHT M2-01: the bar is the kit's [JeebPillNav] — a detached navy capsule
/// FLOATING over each tab's own `JeebMidnightField` (the shell paints no field
/// of its own). Slot order is R1's: Requests · Delivery · Dashboard · Earnings ·
/// Profile, carrying the frozen `shell_tab_*` Semantics ids.
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

  /// Window in which a second root BACK actually exits.
  static const Duration _exitConfirmWindow = Duration(seconds: 2);

  DateTime? _lastBackAt;

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
    // Close-out ruling: nav LABELS follow the role so a client never reads
    // jeeber words. Content gating is untouched — still `available_roles`.
    final activeRoleIsJeeber =
        context.watch<RoleCubit?>()?.state == UserRole.jeeber;
    final tabs = _tabs(
      showJeeberContent: showJeeberContent,
      requestBadgeCount: requestBadgeCount,
      jeeberLabels: activeRoleIsJeeber || showJeeberContent,
    );
    final landingIndex = _landingIndex(tabs, isJeeber: showJeeberContent);
    final safeIndex = (_selectedIndex ?? landingIndex).clamp(0, tabs.length - 1);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status glyphs over navy on EVERY tab, whatever a tab body does.
      value: AppTheme.systemOverlayStyle,
      child: _RootBackHandler(
        onRootBack: () => _handleRootBack(tabs, landingIndex, safeIndex),
        child: Scaffold(
          // The nav floats OVER the tab content, so the body runs full height and
          // Scaffold grows its bottom inset by the nav's painted height.
          extendBody: true,
          body: SafeArea(
            bottom: false,
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
          bottomNavigationBar: SafeArea(
            top: false,
            child: _FloatingTabNav(
              tabs: tabs,
              selectedIndex: safeIndex,
              onSelected: (i) => _handleTabSelected(tabs, safeIndex, i),
            ),
          ),
        ),
      ),
    );
  }

  /// Standard Android root back: off the landing tab it returns there; on it,
  /// the first press only warns — a single stray BACK used to destroy the task.
  void _handleTabSelected(
    List<_Tab> tabs,
    int currentIndex,
    int selectedIndex,
  ) {
    setState(() => _selectedIndex = selectedIndex);
    if (selectedIndex == currentIndex) {
      if (kObsCompiledIn) {
        Observability.instance.currentScreen = _tabRoute(tabs[selectedIndex]);
      }
      return;
    }
    _recordTabNavigation(
      tabs: tabs,
      fromIndex: currentIndex,
      toIndex: selectedIndex,
      action: 'tab',
    );
  }

  void _handleRootBack(List<_Tab> tabs, int landingIndex, int currentIndex) {
    if (currentIndex != landingIndex) {
      setState(() => _selectedIndex = landingIndex);
      _recordTabNavigation(
        tabs: tabs,
        fromIndex: currentIndex,
        toIndex: landingIndex,
        action: 'tab_back',
      );
      return;
    }
    final now = DateTime.now();
    final last = _lastBackAt;
    if (last != null && now.difference(last) <= _exitConfirmWindow) {
      SystemNavigator.pop();
      return;
    }
    _lastBackAt = now;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).shellExitConfirm),
          duration: _exitConfirmWindow,
        ),
      );
  }

  void _recordTabNavigation({
    required List<_Tab> tabs,
    required int fromIndex,
    required int toIndex,
    required String action,
  }) {
    if (!kObsCompiledIn) return;
    final route = _tabRoute(tabs[toIndex]);
    Observability.instance.currentScreen = route;
    Observability.instance.recordScreen(
      action: action,
      route: route,
      name: tabs[toIndex].id,
      previousRoute: _tabRoute(tabs[fromIndex]),
    );
  }

  String _tabRoute(_Tab tab) => '/shell/${tab.id}';

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
    required bool jeeberLabels,
  }) {
    final l10n = AppLocalizations.of(context);
    return [
      _Tab(
        id: 'requests',
        label: jeeberLabels ? l10n.navMyRequests : l10n.navRequests,
        icon: Icons.move_to_inbox,
        // Persistent header wallet chip + bell on the Requests header
        // (`orders_home_wallet_chip`/`orders_home_bell`), overlaid by the shell
        // so the per-screen HomeTab surface stays untouched.
        page: _HeaderedTab(
          idPrefix: 'orders_home',
          topOffset:
              ClientHomeGreeting.avatarCenterFromSafeTop -
              ShellHeaderActions.buttonSize / 2,
          child: HomeTab(repository: widget.homeRepository),
        ),
      ),
      _Tab(
        id: 'delivery',
        label: jeeberLabels ? l10n.navDeliveries : l10n.navDelivery,
        icon: Icons.local_shipping,
        page: OrdersTab(repository: widget.ordersRepository),
      ),
      // ADDITIVE jeeber tab #1 — the Jeeber dashboard (availability + feed).
      // A jeeber sees the live [DashboardTab] (with the persistent header
      // actions); a regular user sees the [JeeberTabEmptyState] invitation.
      _Tab(
        id: _jeeberLandingTabId,
        // A jeeber calls the incoming feed "Requests"; a client sees the
        // become-a-jeeber invitation, never the jeeber word "Dashboard".
        label: jeeberLabels ? l10n.navRequests : l10n.navDeliverInvite,
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
        label: jeeberLabels ? l10n.navEarnings : l10n.navEarnInvite,
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

/// Hardware BACK at the shell root. go_router 13 never consults the LAST
/// route's [PopScope], so the dispatcher is hooked ahead of the router.
class _RootBackHandler extends StatelessWidget {
  const _RootBackHandler({required this.onRootBack, required this.child});

  final VoidCallback onRootBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scoped = PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        onRootBack();
      },
      child: child,
    );
    if (Router.maybeOf(context) == null) return scoped;
    return BackButtonListener(
      onBackButtonPressed: () async {
        if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
        onRootBack();
        return true;
      },
      child: scoped,
    );
  }
}

/// `extendBody: true` already grew `padding.bottom` to the floating nav's
/// painted height; this mirrors that into `viewPadding.bottom` so the tabs that
/// reserve space via [BottomInsetX.scrollBodyBottomInset] clear the nav too
/// (VIS-P1-2). No arithmetic of our own — Scaffold measured the real widget.
class _NavBarContentInset extends StatelessWidget {
  const _NavBarContentInset({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.viewPadding.bottom >= mq.padding.bottom) return child;
    return MediaQuery(
      data: mq.copyWith(
        viewPadding: mq.viewPadding.copyWith(bottom: mq.padding.bottom),
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
  const _HeaderedTab({
    required this.idPrefix,
    required this.child,
    this.topOffset = 0,
  });

  final String idPrefix;
  final Widget child;

  /// Distance below the SafeArea top the actions row starts at.
  final double topOffset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        PositionedDirectional(
          top: topOffset,
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

// ── The floating pill nav (MIDNIGHT M2-01, R1 `tpl 108-130`) ───────────────
// All geometry lives in the frozen kit widget; the shell only maps product
// tabs onto its five slots and re-homes the G3 badge over the right one.

/// Maps the shell's five [_Tab]s onto [JeebPillNav], keeping the frozen
/// `shell_tab_<id>` identifiers and R1's slot order.
class _FloatingTabNav extends StatelessWidget {
  const _FloatingTabNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_Tab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final Widget nav = JeebPillNav(
      items: <JeebPillNavItem>[
        for (final _Tab tab in tabs)
          JeebPillNavItem(
            icon: tab.icon,
            label: tab.label,
            identifier: 'shell_tab_${tab.id}',
          ),
      ],
      selectedIndex: selectedIndex,
      onSelected: onSelected,
    );
    final int badged = tabs.indexWhere((_Tab t) => t.badgeCount > 0);
    if (badged < 0) return nav;
    return Stack(
      children: <Widget>[
        nav,
        Positioned.fill(
          child: IgnorePointer(
            child: _TabBadgeOverlay(
              tab: tabs[badged],
              slot: badged,
              slotCount: tabs.length,
            ),
          ),
        ),
      ],
    );
  }
}

/// G3 unseen-request count. The kit's slot takes an `IconData`, not a widget,
/// so the badge is laid over the nav on the same 5-way split the kit uses.
class _TabBadgeOverlay extends StatelessWidget {
  const _TabBadgeOverlay({
    required this.tab,
    required this.slot,
    required this.slotCount,
  });

  final _Tab tab;
  final int slot;
  final int slotCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: JeebPillNav.defaultMargin.add(
        const EdgeInsets.symmetric(
          horizontal: JeebPillNav.horizontalPadding,
        ),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < slotCount; i++)
            Expanded(
              child: i == slot
                  ? Align(
                      alignment: AlignmentDirectional.topCenter,
                      child: Padding(
                        // +1 clears the capsule's hairline border.
                        padding: const EdgeInsets.only(
                          top: JeebPillNav.slotVerticalPadding + 1,
                        ),
                        child: SizedBox(
                          height: JeebPillNav.iconRowHeight,
                          child: Center(
                            child: Semantics(
                              identifier: 'shell_tab_${tab.id}_badge',
                              container: true,
                              // Hugs the glyph box, not the 50-wide active
                              // pill, so it can never float off detached.
                              child: Badge.count(
                                count: tab.badgeCount,
                                child: const SizedBox.square(
                                  dimension: JeebPillNav.iconSize,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
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

  /// ONE glyph per tab, filled in both states — R1 draws the same solid shape
  /// selected or not; only the ink (and the orange pill) change.
  final IconData icon;
  final Widget page;

  /// Unseen-item count rendered as an M3 badge over the tab icon; `0` hides
  /// it. Currently driven by [BadgeCounts.newRequests] on the Dashboard tab
  /// (G3).
  final int badgeCount;
}
