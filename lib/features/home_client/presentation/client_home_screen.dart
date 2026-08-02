import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/layout/bottom_inset.dart';
import '../../../l10n/app_localizations.dart';
import '../../shell/tab_visibility.dart';
import '../application/client_home_cubit.dart';
import '../application/client_home_state.dart';
import '../domain/client_home_request.dart';
import 'tabs/in_progress_tab.dart';
import 'tabs/pending_requests_tab.dart';
import 'tabs/replies_tab.dart';
import 'widgets/client_home_greeting.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/client_home_screen_fixtures.dart';
import '../domain/client_home_repository.dart';

/// Client home screen matching the Figma design (node 56535:1525).
///
/// Layout top-to-bottom:
/// 1. Greeting header with avatar, "Hello, {name}", and "+" button
/// 2. Tab chips row: Pending Requests | Replies (`OmdsChip`)
/// 3. Request list or its application-illustration empty state.
///
/// The debug-only In Progress surface still renders its order cards
/// (`ActiveOrderCard`) with avatar, name + tier badge,
///    destination, progress bar (Ordered → Picked → In Transit), and an
///    `OmdsPrimaryButton` "Track my order" CTA when actionable.
class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({
    super.key,
    this.onOpenRequest,
    this.onCreateRequest,
    this.onTrack,
    this.initialTab = ClientHomeTab.pendingRequests,
  });

  /// Legacy "open the conversation for a request" hook. Retained for API
  /// compatibility with the shell host (`shell/tabs/home_tab.dart`) and the
  /// widget tests that still pass it. As of JM-027/JM-023 it no longer drives
  /// the Pending and Replies sub-tabs: Pending rows route to
  /// `waiting-no-coverage` (JM-026) and Replies CTAs route to `offer-review`
  /// (JM-028) / `offer-accept-confirm` (JM-029) from inside their own tabs, so
  /// `my-orders` no longer opens `/chat/:id` (the divergence 20_GAP_MAP flagged).
  final void Function(ClientHomeRequest request)? onOpenRequest;
  final VoidCallback? onCreateRequest;

  /// Opens the live-tracking screen (`/orders/:id/tracking`) for an in-progress
  /// delivery's "Track my order" CTA. Distinct from [onOpenRequest]. When null
  /// the [InProgressTab] falls back to GoRouter navigation directly.
  final void Function(ClientHomeRequest request)? onTrack;

  /// Which filter chip is selected on first render. Defaults to Pending
  /// Requests — JEBV4-298 (E24/Q-086): the Requests bottom-nav tab is the
  /// ON-HOLD surface only (Pending + Replies). The accepted-onward
  /// In-Progress live-tracking surface was relocated to the Delivery tab
  /// (`/orders/:id` → Track → `/orders/:id/tracking`), so the In-Progress
  /// chip is no longer part of this tab bar. The dev seam may still pin an
  /// explicit tab (including [ClientHomeTab.inProgress] for a debug-only
  /// capture of the isolated surface) so a single APK can land on any list
  /// without a rebuild.
  final ClientHomeTab initialTab;

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
    with WidgetsBindingObserver {
  late ClientHomeTab _selectedTab = widget.initialTab;

  /// Whether the app is in the foreground. The 10s home poll must NOT keep
  /// firing while the app is backgrounded (F3 — offers polling storm): a hidden
  /// app hammering `/requests` + `/deliveries` + `/v1/offers` is pure waste and
  /// a fast path to a 429. Starts true (a freshly-built screen is foreground).
  bool _appResumed = true;

  /// True once a sub-tab has been chosen — either by the user tapping a chip or
  /// by the one-shot "land on the first populated tab" affordance below. Guards
  /// the affordance so it never fights a manual selection on later rebuilds.
  bool _tabResolved = false;

  /// Last-observed shell-tab visibility, used to detect the off-screen →
  /// on-screen transition. `null` until the first [didChangeDependencies] so we
  /// never auto-refresh on the very first frame ([initState] owns that load).
  bool? _wasVisible;

  /// Captured in [didChangeDependencies] so the resume refetch can reach the
  /// cubit without an unsafe `context.read` from a lifecycle callback.
  ClientHomeCubit? _homeCubit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<ClientHomeCubit>();
      if (cubit.state.status == ClientHomeStatus.initial) {
        cubit.load();
      }
    });
  }

  /// N3's RESUME one-shot — the backstop that makes a DROPPED push cost
  /// freshness until the user next looks, instead of a permanently wrong
  /// screen. One silent [ClientHomeCubit.refresh] when the app comes back to
  /// the foreground, iff this tab is on screen.
  ///
  /// b02 P0 — deliberately NOT moved to [AppResumeSignals], unlike the other
  /// seven resume-refetch surfaces, and the reason SURVIVES the poll deletion:
  /// the `if (resumed == _appResumed) return;` line below makes this an EDGE
  /// trigger, and that is why this screen contributed ZERO reads to the
  /// measured 60-read storm while the three level-triggered observers
  /// contributed twenty each. It is also the control that proves the platform
  /// re-delivered `resumed` with no intervening background state — had there
  /// been one, this guard would have re-armed and `/requests` + `/deliveries`
  /// would appear in the capture. They do not. Swapping a working edge trigger
  /// for the shared bus would buy nothing and retire that control.
  ///
  /// (The second reason recorded here — "`_appResumed` gates the 10 s poll,
  /// which must stop on the RAW `paused` notification" — is now moot: there is
  /// no poll to gate.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _appResumed) return;
    _appResumed = resumed;
    if (!resumed) return;
    // Back-to-foreground: one immediate refresh iff this tab is on-screen.
    final cubit = _homeCubit;
    final isVisible = TabVisibility.maybeOf(context)?.isVisible ?? true;
    if (cubit == null || !isVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cubit.refresh();
    });
  }

  /// S13 auto-refresh: the Requests tab is an [IndexedStack] child, so
  /// re-entering it from the bottom nav (or returning from a create/accept
  /// flow that left the shell mounted) does NOT re-run [initState]. Watch the
  /// shell-provided [TabVisibility] and, whenever this tab goes off-screen →
  /// on-screen, silently re-pull so a freshly created/accepted order surfaces
  /// without a manual pull-to-refresh. [ClientHomeCubit.refresh] keeps the
  /// current data painted (no loading flash) and drops re-entrant calls.
  /// Outside the shell (bare tests / deep links) [TabVisibility.maybeOf] is
  /// null → treated as always-visible → this affordance is inert.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _homeCubit = context.read<ClientHomeCubit>();
    final isVisible = TabVisibility.maybeOf(context)?.isVisible ?? true;
    final becameVisible = _wasVisible == false && isVisible;
    _wasVisible = isVisible;
    if (!becameVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ClientHomeCubit>().refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// JM-023 AC2 (updated for JEBV4-298): when data first lands, surface the
  /// requests that actually exist. The Requests tab is now on-hold only, so the
  /// default landing chip is Pending Requests. If the caller left that default
  /// selected (i.e. the dev seam / a deep-link did NOT pin a specific tab) and
  /// Pending is empty while Replies has content, advance to Replies. This is a
  /// one-shot "land where the content is" affordance; once the user taps a chip
  /// [_tabResolved] is set and the selection is never overridden again.
  void _resolveInitialTab(ClientHomeState state) {
    if (_tabResolved) return;
    if (state.status != ClientHomeStatus.ready) return;
    _tabResolved = true;
    // Respect an explicit (non-default) starting tab — capture flows pin one.
    if (widget.initialTab != ClientHomeTab.pendingRequests) return;
    if (state.pending.isNotEmpty) return;
    if (state.replies.isEmpty) return;
    const populated = ClientHomeTab.replies;
    if (populated == _selectedTab) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _selectedTab = populated);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ClientHomeCubit, ClientHomeState>(
      builder: (context, state) {
        _resolveInitialTab(state);
        return Semantics(
          identifier: 'client_home_root',
          container: true,
          explicitChildNodes: true,
          child: OmdsPullToRefresh(
            onRefresh: () => context.read<ClientHomeCubit>().refresh(),
            child: _ClientHomeBody(
              state: state,
              selectedTab: _selectedTab,
              onTabSelected: (tab) {
                setState(() {
                  _tabResolved = true;
                  _selectedTab = tab;
                });
              },
              onCreateRequest: widget.onCreateRequest,
              onTrack: widget.onTrack,
            ),
          ),
        );
      },
    );
  }
}

class _ClientHomeBody extends StatelessWidget {
  const _ClientHomeBody({
    required this.state,
    required this.selectedTab,
    required this.onTabSelected,
    required this.onCreateRequest,
    required this.onTrack,
  });

  final ClientHomeState state;
  final ClientHomeTab selectedTab;
  final ValueChanged<ClientHomeTab> onTabSelected;
  final VoidCallback? onCreateRequest;
  final void Function(ClientHomeRequest)? onTrack;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case ClientHomeStatus.initial:
      case ClientHomeStatus.loading:
        return _LoadingLayout(onCreateRequest: onCreateRequest);
      case ClientHomeStatus.failed:
        return _FailedLayout(
          name: state.greetingName,
          onCreateRequest: onCreateRequest,
        );
      case ClientHomeStatus.ready:
        return _ReadyLayout(
          state: state,
          selectedTab: selectedTab,
          onTabSelected: onTabSelected,
          onCreateRequest: onCreateRequest,
          onTrack: onTrack,
        );
    }
  }
}

class _LoadingLayout extends StatelessWidget {
  const _LoadingLayout({required this.onCreateRequest});

  final VoidCallback? onCreateRequest;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Reserve the system nav-bar inset so the last item clears the soft
      // buttons / bottom nav bar in edge-to-edge mode. See [BottomInsetX].
      padding: EdgeInsets.only(bottom: context.scrollBodyBottomInset),
      children: [
        ClientHomeGreeting(name: null, onAddPressed: onCreateRequest),
        const SizedBox(height: Spacing.large),
        const Center(child: OmdsLoadingState()),
      ],
    );
  }
}

class _FailedLayout extends StatelessWidget {
  const _FailedLayout({required this.name, required this.onCreateRequest});

  final String? name;
  final VoidCallback? onCreateRequest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Reserve the system nav-bar inset so the retry CTA clears the soft
      // buttons / bottom nav bar in edge-to-edge mode. See [BottomInsetX].
      padding: EdgeInsets.only(bottom: context.scrollBodyBottomInset),
      children: [
        ClientHomeGreeting(name: name, onAddPressed: onCreateRequest),
        const SizedBox(height: Spacing.xLarge),
        OmdsErrorState(
          icon: Icons.cloud_off_outlined,
          title: l10n.homeLoadFailedTitle,
          message: l10n.homeLoadFailedBody,
          retryLabel: l10n.homeLoadFailedRetry,
          onRetry: () => context.read<ClientHomeCubit>().load(),
        ),
      ],
    );
  }
}

class _ReadyLayout extends StatelessWidget {
  const _ReadyLayout({
    required this.state,
    required this.selectedTab,
    required this.onTabSelected,
    required this.onCreateRequest,
    required this.onTrack,
  });

  final ClientHomeState state;
  final ClientHomeTab selectedTab;
  final ValueChanged<ClientHomeTab> onTabSelected;
  final VoidCallback? onCreateRequest;
  final void Function(ClientHomeRequest)? onTrack;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      // Keep the design's twoXLarge breathing room AND reserve the system
      // nav-bar inset so the last order card clears the soft buttons / bottom
      // nav bar in edge-to-edge mode. See [BottomInsetX.scrollBodyBottomInset].
      padding: EdgeInsets.only(
        bottom: Spacing.twoXLarge + context.scrollBodyBottomInset,
      ),
      children: _scrollChildren(),
    );
  }

  List<Widget> _scrollChildren() {
    return <Widget>[
      ClientHomeGreeting(
        name: state.greetingName,
        onAddPressed: onCreateRequest,
        avatarSemanticsIdentifier:
            selectedTab == ClientHomeTab.pendingRequests &&
                state.pending.isEmpty
            ? '_request_empty_state_avatar'
            : null,
      ),
      const SizedBox(height: Spacing.large),
      _ClientHomeTabBar(selectedTab: selectedTab, onSelected: onTabSelected),
      const SizedBox(height: Spacing.large),
      _ReadyContent(
        selectedTab: selectedTab,
        onCreateRequest: onCreateRequest,
        onTrack: onTrack,
      ),
    ];
  }
}

class _ReadyContent extends StatelessWidget {
  const _ReadyContent({
    required this.selectedTab,
    required this.onCreateRequest,
    required this.onTrack,
  });

  final ClientHomeTab selectedTab;
  final VoidCallback? onCreateRequest;
  final void Function(ClientHomeRequest)? onTrack;

  @override
  Widget build(BuildContext context) {
    switch (selectedTab) {
      case ClientHomeTab.inProgress:
        return InProgressTab(onTrack: onTrack);
      case ClientHomeTab.pendingRequests:
        // JM-023 AC2: a pending request row routes to `waiting-no-coverage`
        // (the live broadcast/wait state, JM-026) — NOT the chat thread. We
        // pass an explicit waiting handler so the pending tap target diverges
        // from the Replies/In-Progress chat/track callbacks; the rows carry
        // the indexed `orders_home_request_row_<n>` identifier inside the tab.
        return PendingRequestsTab(
          onTap: (request) => _openWaiting(context, request),
          onCreateRequest: onCreateRequest,
        );
      case ClientHomeTab.replies:
        // JM-027: the Replies sub-tab owns its own navigation — Check Offers →
        // offer-review-list (JM-028) and Accept → offer-accept-confirm sheet
        // (JM-029). It MUST NOT reuse `onOpenRequest` (which routes to
        // `/chat/:id`, the divergent edge 20_GAP_MAP flagged for `my-orders`),
        // so no callbacks are injected here — RepliesTab's defaults apply.
        return const RepliesTab();
    }
  }

  /// JM-023 AC2: route a pending request row to its waiting / no-coverage
  /// state (`waiting-no-coverage` → `/requests/:id/waiting`, JM-026), keyed by
  /// the request id. Defends an empty id (the route requires the path param).
  void _openWaiting(BuildContext context, ClientHomeRequest request) {
    if (request.id.isEmpty) return;
    GoRouter.of(
      context,
    ).pushNamed('waiting-no-coverage', pathParameters: {'id': request.id});
  }
}

class _ClientHomeTabBar extends StatelessWidget {
  const _ClientHomeTabBar({
    required this.selectedTab,
    required this.onSelected,
  });

  final ClientHomeTab selectedTab;
  final ValueChanged<ClientHomeTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // JEBV4-298 (E24/Q-086): the Requests tab is the ON-HOLD surface only —
    // Pending Requests + Replies. The accepted-onward In-Progress live-tracking
    // chip was relocated to the Delivery tab (its Active order detail exposes
    // the map/ETA/Track surface via `/orders/:id/tracking`), so it is
    // intentionally NOT listed here.
    final tabs = <_TabSpec>[
      _TabSpec(ClientHomeTab.pendingRequests, l10n.homeTabPendingRequests),
      _TabSpec(ClientHomeTab.replies, l10n.homeTabReplies),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: Spacing.xSmall),
            _ClientHomeTabChip(
              label: tabs[i].label,
              isSelected: tabs[i].tab == selectedTab,
              onTap: () => onSelected(tabs[i].tab),
              keySuffix: tabs[i].tab.name,
              // JM-023 / JM-027: the Replies sub-tab carries the coined
              // `orders_home_replies_tab` identifier so QA can target it from
              // the Requests home as the tap target onto the Replies surface.
              extraIdentifier: tabs[i].tab == ClientHomeTab.replies
                  ? 'orders_home_replies_tab'
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.tab, this.label);

  final ClientHomeTab tab;
  final String label;
}

class _ClientHomeTabChip extends StatelessWidget {
  const _ClientHomeTabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.keySuffix,
    this.extraIdentifier,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final String keySuffix;

  /// An additional QA identifier wrapped around the chip (e.g. the coined
  /// `orders_home_replies_tab`). Kept distinct from the existing
  /// `orders_filter_<tab>` id so both id contracts stay targetable.
  final String? extraIdentifier;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget chip = Semantics(
      identifier: 'orders_filter_$keySuffix',
      button: true,
      selected: isSelected,
      label: label,
      child: OmdsChip(
        key: Key('client-home-tab-$keySuffix'),
        label: label,
        isSelected: isSelected,
        onTap: onTap,
        selectedColor: colorScheme.primary,
        unselectedColor: colorScheme.surface.withValues(
          alpha: UIConstants.elevationNone,
        ),
        selectedTextColor: colorScheme.onPrimary,
        unselectedTextColor: colorScheme.onSurfaceVariant,
        borderColor: isSelected ? colorScheme.primary : colorScheme.outline,
        borderRadius: OmdsBorderRadius.xSmall,
      ),
    );
    final extraId = extraIdentifier;
    if (extraId != null) {
      chip = Semantics(
        identifier: extraId,
        container: true,
        explicitChildNodes: true,
        child: chip,
      );
    }
    return chip;
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/home_client/client_home_screen_preview_test.dart
// ===========================================================================
//
// [ClientHomeScreen] is the Requests bottom-nav surface: greeting header, the
// Pending/Replies chip row, and one of four bodies chosen by
// [ClientHomeState.status]. There is no seam to hand it a state — the screen
// reads an ambient [ClientHomeCubit] and that cubit takes a REPOSITORY, not a
// state — so every preview below mounts the real cubit over a local fake and
// lets the screen's own `initState` issue the load, exactly as production does.
//
// The fakes and their canned data are NOT declared here. They live in
// `lib/devtool/catalog/fixtures/client_home_screen_fixtures.dart`, shared
// verbatim with the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_04_entries.dart`). One source of truth: the
// designer's in-app browser and this canvas cannot drift into showing two
// different "designed states" of the same screen. None of those fakes can reach
// the network — they answer from a const list, throw, or never complete — so
// the guard in [jeebPreviewHost] is the net here, not the plan.
//
// Two things about the harness are worth knowing before editing it:
//
//  * **The screen owns no Scaffold.** It returns `Semantics → OmdsPullToRefresh
//    → ListView`, and [jeebPreviewHost] already supplies `Scaffold + SafeArea`.
//    Adding one here would nest two and silently change the insets the
//    `context.scrollBodyBottomInset` padding is computed against.
//  * **Both callbacks are wired.** `onCreateRequest` matters because the empty
//    branch falls back to `GoRouter.of(context)` when it is null and there is no
//    router here; `onTrack` matters for the In-Progress body's Track CTA.
//
// **The `size:` boxes below are real device frames (390x844, 320x568), and the
// canvas is the only place they take effect.** The render tests pump the
// harness's 800x600 surface, where every row on this screen gets roughly twice
// the width it ships with and nothing can look tight — so width is something to
// LOOK at here, not something CI will tell you about. Two rows are worth
// looking at, because both are a bare [Row] with no `Wrap`, no `Flexible` and
// no scrollable around their children, and so fit until they don't: the
// Pending/Replies chip row in [_ClientHomeTabBar] (narrowest in
// [clientHomeScreenEmptyCompact], and the labels are what grow at 200% text),
// and the trailing CTA row on each In-Progress card.
//
// Pinning those widths in the widget tree instead was tried and rejected. The
// render tests would then lay these rows out in the SDK test font — every glyph
// a full em square — which overflows both of them at 320 and at 390 pt, widths
// a device font clears comfortably. That turns a canvas reading into a red
// suite that is wrong about the app.
//
// Two states worth reading closely, because neither is visible in any existing
// widget test:
//
//  * **`In Progress (dev seam)`.** Pinning [ClientHomeTab.inProgress] renders
//    the In-Progress body under a tab bar that has no In-Progress chip
//    (JEBV4-298 relocated it), so BOTH visible chips paint unselected. The
//    surface reads as "nothing is selected" while a third, unnameable list is
//    on screen.
//  * **`Auto-advanced to Replies`.** Pending empty + Replies populated fires the
//    one-shot affordance in `_resolveInitialTab` — a post-frame `setState` that
//    moves the selection AFTER the first frame has painted the Pending tab. In
//    the canvas that is a visible jump on open, not a starting state.

/// The phone the client home is designed against (Figma 56535:1525).
const double _clientHomeScreenPhoneWidth = 390;

/// The narrowest phone the app still supports — and roughly what an Android
/// multi-window split leaves a foreground app.
const double _clientHomeScreenCompactWidth = 320;

const Size _clientHomeScreenPhoneBox = Size(_clientHomeScreenPhoneWidth, 844);
const Size _clientHomeScreenCompactBox = Size(
  _clientHomeScreenCompactWidth,
  568,
);

/// Mounts the real screen the way its shell host does: a [ClientHomeCubit] over
/// a local fake repository, with both navigation callbacks wired.
///
/// No `load()` call here — [ClientHomeScreen.initState] posts its own, which is
/// the mount path that actually ships.
Widget _clientHomeScreenHosted(
  ClientHomeRepository repository, {
  ClientHomeTab initialTab = ClientHomeTab.pendingRequests,
  String? name = ClientHomeScreenPreviewFixtures.greetingName,
}) {
  return BlocProvider<ClientHomeCubit>(
    create: (_) => ClientHomeScreenPreviewFixtures.cubit(repository, name: name),
    child: ClientHomeScreen(
      initialTab: initialTab,
      onCreateRequest: () {},
      onTrack: (_) {},
    ),
  );
}

/// The default landing surface: Pending Requests with three broadcast rows.
///
/// The reference reading, and the one the matrix is for. Everything that makes
/// this screen RTL-sensitive is stacked in its top 200 pt — a greeting line that
/// must mirror around a trailing "+" button, then a chip row built from a plain
/// [Row] with no [Wrap] or [Flexible] anywhere. At 200% text those two chips
/// carry ~2x the label width inside the same 390 pt frame.
@JeebPreview(
  group: 'home_client',
  name: 'Pending · three requests',
  size: _clientHomeScreenPhoneBox,
  matrix: true,
)
Widget clientHomeScreenPending() =>
    _clientHomeScreenHosted(ClientHomeScreenPreviewFixtures.populated());

/// The Replies sub-tab: one request with nine offers and a `+6` overflow.
///
/// Note the tab bar keeps its full height above a single card, and that the
/// Replies row carries TWO end-aligned CTA pills (`Check Offers`, `Accept`)
/// which are `IntrinsicWidth` inside a non-wrapping [Row].
@JeebPreview(
  group: 'home_client',
  name: 'Replies · nine offers',
  size: _clientHomeScreenPhoneBox,
)
Widget clientHomeScreenReplies() => _clientHomeScreenHosted(
  ClientHomeScreenPreviewFixtures.populated(),
  initialTab: ClientHomeTab.replies,
);

/// The dev-seam-only In-Progress body, pinned explicitly.
///
/// JEBV4-298 moved the In-Progress chip to the Delivery tab but left
/// [ClientHomeTab.inProgress] reachable through [ClientHomeScreen.initialTab],
/// which capture flows and the Screen Catalog still pin. The result is on
/// screen here: three active-order cards under a tab bar in which NEITHER
/// visible chip is selected, because the selected tab has no chip to render.
@JeebPreview(
  group: 'home_client',
  name: 'In Progress (dev seam)',
  size: _clientHomeScreenPhoneBox,
)
Widget clientHomeScreenInProgress() => _clientHomeScreenHosted(
  ClientHomeScreenPreviewFixtures.populated(),
  initialTab: ClientHomeTab.inProgress,
);

/// A fresh account: the load succeeded and there is nothing to show.
///
/// The illustrated empty state sits BELOW the greeting and the chip row, so it
/// gets far less of the viewport than [ClientHomeEmptyView]'s own previews give
/// it. This is the state that also swaps the greeting avatar's semantics
/// identifier to `_request_empty_state_avatar` — the only place on this screen
/// where a11y ids change with data.
@JeebPreview(
  group: 'home_client',
  name: 'Empty · first run',
  size: _clientHomeScreenPhoneBox,
)
Widget clientHomeScreenEmpty() =>
    _clientHomeScreenHosted(ClientHomeScreenPreviewFixtures.empty());

/// The same empty state with 70 pt less width and 276 pt less height.
///
/// Worth its own card because the empty view's illustration is a FIXED 200 pt
/// (`Sizes.twoHundredLarge` is an absolute token that neither shrinks on a
/// narrow phone nor grows with the text scaler), so on the 320x568 floor it
/// claims 63% of the width and over a third of the height that is left after
/// the greeting and the chip row have taken theirs. This is also the narrowest
/// box the two-chip tab row is ever asked to fit in — read it there first.
///
/// A different greeting name from [clientHomeScreenEmpty] on purpose: the two
/// states share every word of their body copy, so the name is what lets the
/// render test tell them apart.
@JeebPreview(
  group: 'home_client',
  name: 'Empty · 320 pt floor',
  size: _clientHomeScreenCompactBox,
)
Widget clientHomeScreenEmptyCompact() => _clientHomeScreenHosted(
  ClientHomeScreenPreviewFixtures.empty(),
  name: 'Yasmine',
);

/// Cold load failed: the whole body is replaced by an error block and a Retry.
///
/// Only a COLD failure reaches here — `ClientHomeCubit._fetch` keeps the
/// rendered rows when a *refresh* throws, and a 429 is not an error at all.
/// Note what survives the failure: the greeting (with the name, which comes
/// from the session rather than the failed read) and nothing else — the chip
/// row is gone, so the user cannot switch tabs to try the other list.
@JeebPreview(
  group: 'home_client',
  name: 'Failed · cold load',
  size: _clientHomeScreenPhoneBox,
)
Widget clientHomeScreenFailed() =>
    _clientHomeScreenHosted(ClientHomeScreenPreviewFixtures.failing());

/// The cold read is in flight: greeting, then a centred spinner.
///
/// The chip row is absent here too, and the spinner carries no text in either
/// locale — so for as long as the read takes, the surface tells a screen-reader
/// user nothing at all about what is loading. It is also the state that cannot
/// settle (an indeterminate `CircularProgressIndicator` schedules frames
/// forever), so its render test drives fixed pumps instead of `pumpAndSettle`.
///
/// Put this card next to `Failed · cold load` and read the FIRST LINE of both.
/// `_LoadingLayout` hard-codes `ClientHomeGreeting(name: null)` while every
/// other body passes `state.greetingName`, so this preview greets "Welcome
/// back" even though the fixture's name was already in state before the read
/// started (`load()` emits it in the same frame it sets `loading`). On a device
/// the header therefore says "Welcome back" and then swaps to "Hello, Layla"
/// the moment the snapshot lands — a re-greeting of a user we could name all
/// along.
@JeebPreview(
  group: 'home_client',
  name: 'Loading · cold',
  size: _clientHomeScreenPhoneBox,
)
Widget clientHomeScreenLoading() =>
    _clientHomeScreenHosted(ClientHomeScreenPreviewFixtures.stalled());

/// Layout ceiling: the longest content this screen can actually carry.
///
/// A long account name in the greeting (which greets the FIRST name only, then
/// ellipsizes), and a pending row with NO server order id — so its header
/// degrades to the customer's own free-text "What do you need?" line next to a
/// tier badge that is not flexible — over a two-line items summary. Read the AR
/// RTL and 200%-text renderings of this one, not the English: the English
/// rendering stays plausible long after the other two have broken.
@JeebPreview(
  group: 'home_client',
  name: 'Longest content',
  size: _clientHomeScreenPhoneBox,
  matrix: true,
)
Widget clientHomeScreenLongContent() => _clientHomeScreenHosted(
  ClientHomeScreenPreviewFixtures.longContent(),
  name: ClientHomeScreenPreviewFixtures.longGreetingName,
);

/// Pending empty, Replies populated — the one-shot "land where the content is"
/// affordance (`_resolveInitialTab`, JM-023 AC2 / JEBV4-298).
///
/// The screen must advance to Replies and never to the relocated In-Progress
/// surface. It does so from a POST-FRAME `setState`, so the first painted frame
/// is the Pending tab's empty state and the second is this — a visible jump on
/// open that no widget test can see, because `pumpAndSettle` hides it.
@JeebPreview(
  group: 'home_client',
  name: 'Auto-advanced to Replies',
  size: _clientHomeScreenPhoneBox,
)
Widget clientHomeScreenAutoAdvancedToReplies() =>
    _clientHomeScreenHosted(ClientHomeScreenPreviewFixtures.repliesOnly());
