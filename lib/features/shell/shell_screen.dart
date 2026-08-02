import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../core/dev_seam/dev_seam.dart';
import '../../core/lifecycle/route_visibility.dart';
import '../../core/notifications/application/badge_count_cubit.dart';
import '../../core/role/role_availability_cubit.dart';
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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../core/di/injection_container.dart';
import '../../core/previews/jeeb_preview.dart';
import '../../devtool/catalog/fixtures/client_home_screen_fixtures.dart';
import '../../devtool/catalog/fixtures/shell_screen_fixtures.dart';
import '../jeeber_home/domain/services/availability_gateway.dart';
import '../jeeber_request_feed/data/request_feed_repository.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({
    super.key,
    this.homeRepository,
    this.ordersRepository,
  });

  final ClientHomeRepository? homeRepository;

  final OrderRepository? ordersRepository;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  static const String _jeeberLandingTabId = 'dashboard';

  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final availability = context.watch<RoleAvailabilityCubit?>()?.state;
    final showJeeberContent = _showJeeberContent(availability);
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

        child: RouteVisibilityScope(
          child: _NavBarContentInset(
            child: IndexedStack(
              index: safeIndex,
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

  int _landingIndex(List<_Tab> tabs, {required bool isJeeber}) {
    if (!isJeeber) return 0;
    final jeeberIndex =
        tabs.indexWhere((t) => t.id == _jeeberLandingTabId);
    return jeeberIndex >= 0 ? jeeberIndex : 0;
  }

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
        icon: Icons.move_to_inbox_outlined,
        selectedIcon: Icons.move_to_inbox,
        page: _HeaderedTab(
          idPrefix: 'orders_home',
          child: HomeTab(repository: widget.homeRepository),
        ),
      ),
      _Tab(
        id: 'delivery',
        label: l10n.navDelivery,
        icon: Icons.local_shipping_outlined,
        selectedIcon: Icons.local_shipping,
        page: OrdersTab(repository: widget.ordersRepository),
      ),
      _Tab(
        id: _jeeberLandingTabId,
        label: l10n.navDashboard,
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        badgeCount: requestBadgeCount,
        page: showJeeberContent
            ? const _HeaderedTab(
                idPrefix: 'delivery_tab',
                child: DashboardTab(),
              )
            : const JeeberTabEmptyState.dashboard(),
      ),
      _Tab(
        id: 'earnings',
        label: l10n.navEarnings,
        icon: Icons.payments_outlined,
        selectedIcon: Icons.payments,
        page: showJeeberContent
            ? const EarningsTab()
            : const JeeberTabEmptyState.earnings(),
      ),
      _Tab(
        id: 'profile',
        label: l10n.navProfile,
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        page: const _HeaderedTab(
          idPrefix: 'customer_profile',
          child: _CustomerProfileTabBody(),
        ),
      ),
    ];
  }
}

class _NavBarContentInset extends StatelessWidget {
  const _NavBarContentInset({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        padding:
            mq.padding.copyWith(bottom: mq.padding.bottom + Sizes.fiveXLarge),
        viewPadding: mq.viewPadding
            .copyWith(bottom: mq.viewPadding.bottom + Sizes.fiveXLarge),
      ),
      child: child,
    );
  }
}

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

class _CustomerProfileTabBody extends StatelessWidget {
  const _CustomerProfileTabBody();

  @override
  Widget build(BuildContext context) {
    return const CustomerProfileScreen(data: CustomerProfileViewData());
  }
}

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
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: Sizes.fiveXLarge,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < tabs.length; i++)
                _BarItem(
                  tab: tabs[i],
                  isSelected: i == selectedIndex,
                  onTap: () => onTap(i),
                ),
            ],
          ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final color = isSelected ? colorScheme.primary : colorScheme.outline;
    final icon = Icon(
      isSelected ? tab.selectedIcon : tab.icon,
      size: Sizes.xLarge,
      color: color,
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
            if (tab.badgeCount > 0)
              Semantics(
                identifier: 'shell_tab_${tab.id}_badge',
                container: true,
                child: Badge.count(count: tab.badgeCount, child: icon),
              )
            else
              icon,
            const SizedBox(height: Sizes.threeXSmall),
            Text(
              tab.label,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
                color: color,
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
    required this.selectedIcon,
    required this.page,
    this.badgeCount = 0,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;

  final int badgeCount;
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/shell/shell_screen_preview_test.dart
// ===========================================================================
//
// [ShellScreen] is the bottom-nav host: the surface every signed-in user is on
// whenever they are not on a pushed route. It draws exactly two things of its
// own — the five-destination bar at the bottom, and the floating
// [ShellHeaderActions] overlay [_HeaderedTab] stacks on three of the tabs —
// and delegates the rest to whichever tab body is selected. So a preview of
// this screen is really a preview of THREE decisions the screen makes and
// nothing else can:
//
//  1. **which tab it opens on.** `_landingIndex` sends a jeeber to `dashboard`
//     and everyone else to index 0. That is BUG-1 (sprint-008, Lane B) — the
//     shell used to hardcode 0, so a dual-role jeeber opened on the client
//     Requests tab and the incoming-request feed was unreachable on cold start.
//     `test/features/shell/shell_dual_role_landing_test.dart` owns the
//     assertion; [shellScreenJeeberLanding] is what it looks like;
//  2. **whether the jeeber tabs get their live bodies or the additive empty
//     state.** UX LAW S0-E2E-08: the tab SET never changes — every user sees
//     the same five destinations, and a non-jeeber sees Dashboard/Earnings as
//     become-a-jeeber invitations rather than as missing tabs;
//  3. **the Dashboard badge.** G3: `BadgeCountCubit` was incremented on every
//     push and rendered by ZERO widgets. `_BarItem` now wraps the icon in
//     `Badge.count` when `newRequests > 0` — see [shellScreenNewRequestBadge].
//
// **Seeding.** The screen exposes exactly two constructor seams,
// `homeRepository` and `ordersRepository` (added for the DT-04 Screen Catalog),
// and reads two cubits through NULLABLE `context.watch` — so all four axes are
// reachable without a production edit. The fakes are shared with the catalog
// entry (`lib/devtool/catalog/fixtures/shell_screen_fixtures.dart` and the
// client-home fakes already in `client_home_screen_fixtures.dart`), so the
// designer-facing tool and the canvas cannot show two different `req-9001`.
//
// **Network-free by construction.** [ShellScreen] builds all five tab bodies at
// once — they live in an `IndexedStack`, so the offstage ones are constructed
// too — and every one of their DI lookups is fail-safe with no graph mounted:
// `HomeTab` falls back to `InMemoryClientHomeRepository` and a NULL greeting
// repository, `OrdersTab` takes the injected fake, `CustomerProfileScreen`
// resolves a null repository without `Dio`, and `EarningsTab` fails closed on
// "no session id" (S0-OAD-03). The one exception is the JEEBER branch, which is
// why [_shellScreenHosted] takes DI seriously — see below. Nothing here
// constructs a `Dio*Repository`; [jeebPreviewHost]'s `CatalogNetworkGuard` is
// the net, not the plan.
//
// **What the jeeber preview costs, and why it is here.** With `jeeber` in the
// role list the Dashboard tab swaps in the LIVE [DashboardTab], which resolves
// `sl<AvailabilityGateway>()` and `sl<RequestFeedRepository>()`
// UNCONDITIONALLY — no constructor seam, which is exactly why
// `batch_11_entries.dart` skipped this branch in the catalog. Rather than add a
// production seam, [_shellScreenHosted] registers the two IN-MEMORY
// implementations this repo already ships for its own tests
// ([InMemoryAvailabilityGateway], [SeededRequestFeedRepository]) — the same
// pair `test/shell_role_tabs_test.dart` registers, neither of which can open a
// socket. Every preview rebuilds those registrations from scratch so a card's
// state is fully described by its own arguments and never by whichever card
// the canvas painted before it.
//
// **This is a SCREEN**, so it owns its own `Scaffold` and [jeebPreviewHost]
// wraps it in a second one; the inner is the real surface and the outer
// contributes a background. The canvas box is therefore a real device —
// [_shellScreenPhoneBox] (390x844) — rather than the harness default of
// 390x200, in which a bottom bar and a tab body cannot be judged at all.
//
// **Do not tap the tab BODIES in the canvas.** The bottom bar itself is honest
// — `onTap` is a local `setState`, so switching destinations works and is the
// main thing to try — but every affordance inside a tab (`ShellHeaderActions`'
// wallet chip and bell, a request row, the "+" create button) calls
// `context.goNamed`, and there is no `Router` above a preview.
//
// What these previews surfaced in the screen itself, each pinned as a number in
// `test/previews/shell/shell_screen_preview_test.dart`:
//
//  * **the bottom bar cannot ellipsize.** `_JeebBottomBar` lays its five
//    `_BarItem`s out in a bare `Row` with no `Expanded`/`Flexible`, and each
//    label is a `Text` with no `maxLines` and no `overflow`. The row therefore
//    demands the labels' intrinsic width — 238.9 dp in EN, 171.1 dp in AR at
//    100%, growing linearly with text scale — and overflows rather than
//    shortening. First break: **150% on a 320 dp device** and 175% on a 390 dp
//    phone, in ENGLISH. Arabic, which is 28% narrower here, survives to 200% on
//    both;
//  * **the bar's height is a constant.** `SizedBox(height: Sizes.fiveXLarge)`
//    is 56 dp whatever the text scale, while `_BarItem`'s column is a 24 dp
//    icon plus a label that does scale — so at 200% every one of the five
//    destinations reports `RenderFlex overflowed by 2.0 pixels on the bottom`,
//    in both locales and on both devices. Five identical errors per frame;
//  * **the landing tab cannot be chosen.** `_selectedIndex` is private state
//    with no `initialIndex` seam, so every preview (and every catalog state)
//    opens on whatever `_landingIndex` returns. The Delivery, Earnings and
//    Profile bodies are BUILT — the `IndexedStack` builds all five — but only
//    reachable by tapping, which is why the fixtures below still seed the
//    orders repository even though no preview opens on it.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _shellScreenPhoneBox = Size(390, 844);

/// The smallest device Jeeb supports. The bottom bar has to fit five labelled
/// destinations across 320 dp here, which is 64 dp each including padding.
const Size _shellScreenCompactBox = Size(320, 568);

/// The real screen, with every axis it has seeded explicitly.
///
/// [roles] feeds [RoleAvailabilityCubit] the way the gateway's
/// `Auth/Capabilities` response does; an EMPTY list is not the same as no cubit
/// at all in production (it is "resolved, and you are not a jeeber") but the
/// shell reads both as `showJeeberContent == false`, so the previews pass the
/// list and let the cubit exist.
///
/// The two DI entries are rebuilt on every call — unregistered first, then
/// registered only for a jeeber — because the canvas keeps ONE isolate alive
/// across every card, and a preview whose content depended on scroll order
/// would be a preview that lies.
Widget _shellScreenHosted({
  required ClientHomeRepository homeRepository,
  required OrderRepository ordersRepository,
  List<String> roles = const <String>['client'],
  int newRequestBadge = 0,
}) {
  final bool isJeeber = roles.contains('jeeber');
  if (sl.isRegistered<AvailabilityGateway>()) {
    sl.unregister<AvailabilityGateway>();
  }
  if (sl.isRegistered<RequestFeedRepository>()) {
    sl.unregister<RequestFeedRepository>();
  }
  if (isJeeber) {
    // Both ship in `lib/` for this repo's own widget tests and answer from
    // memory: the gateway returns its seeded [AvailabilityStatus], the feed
    // repository returns a const list and an EMPTY request stream. Neither
    // holds a socket, a timer or a Dio.
    sl.registerSingleton<AvailabilityGateway>(InMemoryAvailabilityGateway());
    sl.registerSingleton<RequestFeedRepository>(
      SeededRequestFeedRepository(const []),
    );
  }
  return MultiBlocProvider(
    providers: <BlocProvider<Object?>>[
      BlocProvider<RoleAvailabilityCubit>(
        create: (_) => RoleAvailabilityCubit(RoleAvailability(roles: roles)),
      ),
      BlocProvider<BadgeCountCubit>(
        create: (_) =>
            BadgeCountCubit(initial: BadgeCounts(newRequests: newRequestBadge)),
      ),
    ],
    child: ShellScreen(
      homeRepository: homeRepository,
      ordersRepository: ordersRepository,
    ),
  );
}

/// The default landing every client sees, and the state the DT-04 catalog entry
/// shows: three requests out for bids on the Requests tab, one delivery en
/// route behind the Delivery tab, the two jeeber destinations carrying their
/// additive become-a-jeeber empty states.
///
/// Matrixed because the bottom bar is the RTL-sensitive part of this screen and
/// the only place all five destinations are visible at once. Three things to
/// read there:
///
///  * **AR RTL** reverses the destination order — and, measured through the
///    shipping faces, the Arabic labels are 28% NARROWER than the English ones
///    (171.1 dp for all five against 238.9 dp; `لوحة التحكم` is 48.3 dp where
///    `Dashboard` is 59.2). That inverts the usual habit on this app: here it
///    is ENGLISH that runs out of room first, everywhere;
///  * **EN 200%** is where the bar breaks, in both directions at once.
///    `_BarItem` puts a bare `Text` under the icon inside a
///    `Column(mainAxisSize: min)` with NO `maxLines`, no `overflow` and nothing
///    flexible above it, and `_JeebBottomBar` pins the row to a constant
///    `Sizes.fiveXLarge` (56 dp) of height. So the labels can neither ellipsize
///    nor wrap: at 200% they overrun the fixed height by 2 dp on every one of
///    the five destinations (in BOTH locales, on BOTH devices), and the row's
///    intrinsic width grows to 469.7 dp against a 390 dp phone. Every number
///    here is pinned in the render test, measured with real fonts loaded;
///  * the tab BODY at 200% carries its own, separate break —
///    `_ClientHomeTabBar` in `client_home_screen.dart` is an unwrapped `Row` of
///    two chips — so the 200% card shows two horizontal overflows, not one.
///    Only the bar's belongs to this file.
@JeebPreview(
  group: 'shell',
  name: 'Client landing · populated',
  size: _shellScreenPhoneBox,
  matrix: true,
)
Widget shellScreenClientLanding() => _shellScreenHosted(
  homeRepository: ShellScreenPreviewFixtures.populatedHome(),
  ordersRepository: ShellScreenPreviewFixtures.populatedOrders(),
);

/// A brand-new account: nothing pending, nothing replied, no orders behind the
/// Delivery tab. The catalog's second designed state.
///
/// This is the reading that matters most for the shell, because the chrome IS
/// the screen here: five destinations, three of which lead to an empty state
/// and two of which lead to an invitation to become a jeeber. If the shell ever
/// looks unfinished, it looks unfinished HERE.
@JeebPreview(
  group: 'shell',
  name: 'Client landing · empty everywhere',
  size: _shellScreenPhoneBox,
)
Widget shellScreenClientEmpty() => _shellScreenHosted(
  homeRepository: ShellScreenPreviewFixtures.emptyHome(),
  ordersRepository: const ShellScreenEmptyOrderRepository(),
);

/// Cold start: the landing tab's `GET` has not resolved, so `ClientHomeCubit`
/// is on `loading` and the body is the generic greeting over a spinner.
///
/// Worth looking at because of what is ALREADY painted around it — the five
/// destinations and the header overlay are up and interactive before any
/// content exists, which is the shell doing its job. Note that the Requests
/// chip row is NOT here: the loading layout replaces the whole body, so the
/// only thing a user can do in this frame is change destination.
///
/// The spinner never settles, so the render test drives this one with fixed
/// pumps rather than `pumpAndSettle`.
@JeebPreview(
  group: 'shell',
  name: 'Requests · cold load',
  size: _shellScreenPhoneBox,
)
Widget shellScreenRequestsColdLoad() => _shellScreenHosted(
  homeRepository: const StalledClientHomeRepository(),
  ordersRepository: const ShellScreenStalledOrderRepository(),
);

/// The landing tab's cold load FAILED — the one state where the shell's most
/// important destination has nothing to show and says so.
///
/// A cold failure is the only way to reach `ClientHomeStatus.failed`;
/// `ClientHomeCubit` deliberately swallows a failed REFRESH while rows are
/// already painted. Read the relationship between the two error affordances:
/// the tab body offers a Retry, and the bottom bar offers four other
/// destinations — three of which will load fine, because only the home
/// repository is broken here.
@JeebPreview(
  group: 'shell',
  name: 'Requests · load failed',
  size: _shellScreenPhoneBox,
)
Widget shellScreenRequestsUnreachable() => _shellScreenHosted(
  homeRepository: const FailingClientHomeRepository(),
  ordersRepository: const ShellScreenFailingOrderRepository(),
);

/// The longest content the shell can be handed on its landing tab: a request
/// with no `displayId`, whose title falls back to the customer's own unbounded
/// free-text line.
///
/// The shell's own contribution to this state is the bottom inset. The tab body
/// scrolls under a 56 dp bar that `_NavBarContentInset` reserves by inflating
/// `MediaQuery.padding.bottom`; if that inset is ever dropped, the last row of
/// a long list ends up UNDER the bar and this is the preview where you see it.
@JeebPreview(
  group: 'shell',
  name: 'Requests · longest content',
  size: _shellScreenPhoneBox,
)
Widget shellScreenLongestRequest() => _shellScreenHosted(
  homeRepository: SeededClientHomeRepository(
    ShellScreenPreviewFixtures.longestContentSnapshot(),
  ),
  ordersRepository: ShellScreenPreviewFixtures.populatedOrders(),
);

/// G3, made visible: twelve unseen open requests arrived by push while the user
/// was on another destination, and the Dashboard icon carries the count.
///
/// The badge is on the tab a NON-jeeber sees as an empty state, which is the
/// point of previewing it on this branch rather than the jeeber one: the count
/// renders from `BadgeCountCubit` alone and does not wait on a role
/// resolution. Two digits on purpose — `Badge.count` grows the pill for the
/// second glyph, and the icon it hangs off is 24 dp inside a 64 dp slot.
@JeebPreview(
  group: 'shell',
  name: 'Dashboard badge · 12 unseen',
  size: _shellScreenPhoneBox,
)
Widget shellScreenNewRequestBadge() => _shellScreenHosted(
  homeRepository: ShellScreenPreviewFixtures.populatedHome(),
  ordersRepository: ShellScreenPreviewFixtures.populatedOrders(),
  newRequestBadge: 12,
);

/// BUG-1: a dual-role user lands on the JEEBER surface, not the client one.
///
/// `available_roles: [client, jeeber]` flips two things at once — the landing
/// index moves from 0 to the `dashboard` tab, and the Dashboard/Earnings tabs
/// swap their become-a-jeeber empty states for their live bodies. Pre-fix the
/// shell hardcoded index 0, so Karim (`..0002`) opened on client Requests and
/// the incoming-request feed was unreachable on cold start.
///
/// The feed is seeded EMPTY, which is honest rather than convenient: with no
/// `JeeberKycStatusGate` registered the tab falls through to
/// `SeamJeeberKycStatusGate`, which in debug with no dev-seam reports
/// `approved` — so this is an approved jeeber with a quiet feed, the state a
/// real jeeber spends most of their day in. The Earnings destination beside it
/// shows its fail-closed "no active session" branch (S0-OAD-03) because no
/// `AuthTokenStore` is registered, which is also what a preview SHOULD show:
/// nothing here has a session to bind an earnings account to.
@JeebPreview(
  group: 'shell',
  name: 'Jeeber landing · Dashboard',
  size: _shellScreenPhoneBox,
)
Widget shellScreenJeeberLanding() => _shellScreenHosted(
  homeRepository: ShellScreenPreviewFixtures.populatedHome(),
  ordersRepository: ShellScreenPreviewFixtures.populatedOrders(),
  roles: const <String>['client', 'jeeber'],
);

/// The same five destinations on the smallest device Jeeb supports (320x568),
/// which is the width the bottom bar is really designed against.
///
/// Matrixed because this is where the bar runs out of room first, and the three
/// renderings diverge sharply. Measured with the shipping faces, the five
/// destinations demand 238.9 dp in EN and 171.1 dp in AR at 100%, scaling
/// linearly with text:
///
///   * **EN light** fits at 100% and breaks at **150%** (354.3 dp against 320),
///     which is a text size Android's "Largest" and iOS's accessibility sizes
///     both reach — this is a shipping configuration, not a ceiling;
///   * **AR RTL** is the ROOMIER locale here and survives to 200% (342.1 dp,
///     22 dp over);
///   * **EN 200%** overruns by 149.7 dp — nearly half the device.
///
/// `_BarItem`'s `Text` has no `maxLines`, no `overflow` and nothing flexible
/// above it, so there is no mechanism by which any of that could ellipsize: the
/// row can only overflow. The same frames also overrun the bar's constant 56 dp
/// height by 2 dp per destination at 200%.
///
/// The body is the replies-only snapshot, so this is also the one preview where
/// the landing tab's own "land where the content is" affordance fires: nothing
/// is pending, so `ClientHomeScreen` moves its chip from Pending to Replies on
/// the frame after the load, without anything being tapped.
@JeebPreview(
  group: 'shell',
  name: 'Bottom bar · 320 pt device',
  size: _shellScreenCompactBox,
  matrix: true,
)
Widget shellScreenCompactDevice() => _shellScreenHosted(
  homeRepository: SeededClientHomeRepository(
    ShellScreenPreviewFixtures.repliesOnlySnapshot(),
  ),
  ordersRepository: const ShellScreenEmptyOrderRepository(),
);
