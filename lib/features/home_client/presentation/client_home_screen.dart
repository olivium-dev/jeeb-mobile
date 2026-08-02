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

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({
    super.key,
    this.onOpenRequest,
    this.onCreateRequest,
    this.onTrack,
    this.initialTab = ClientHomeTab.pendingRequests,
  });

  final void Function(ClientHomeRequest request)? onOpenRequest;
  final VoidCallback? onCreateRequest;

  final void Function(ClientHomeRequest request)? onTrack;

  final ClientHomeTab initialTab;

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen>
    with WidgetsBindingObserver {
  late ClientHomeTab _selectedTab = widget.initialTab;

  bool _appResumed = true;

  bool _tabResolved = false;

  bool? _wasVisible;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final resumed = state == AppLifecycleState.resumed;
    if (resumed == _appResumed) return;
    _appResumed = resumed;
    if (!resumed) return;
    final cubit = _homeCubit;
    final isVisible = TabVisibility.maybeOf(context)?.isVisible ?? true;
    if (cubit == null || !isVisible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cubit.refresh();
    });
  }

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

  void _resolveInitialTab(ClientHomeState state) {
    if (_tabResolved) return;
    if (state.status != ClientHomeStatus.ready) return;
    _tabResolved = true;
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
        return PendingRequestsTab(
          onTap: (request) => _openWaiting(context, request),
          onCreateRequest: onCreateRequest,
        );
      case ClientHomeTab.replies:
        return const RepliesTab();
    }
  }

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
